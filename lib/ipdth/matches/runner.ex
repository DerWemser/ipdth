defmodule Ipdth.Matches.Runner do

  import Ecto.Query, warn: false

  alias Ipdth.Repo
  alias Ipdth.Matches.{Match, Round}
  alias Ipdth.Tournaments
  alias Ipdth.Agents.ConnectionManager
  alias Ipdth.Agents.Connection.{MatchInfo, PastResult, Request}

  require Logger

  use Task, restart: :transient

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end


  def run(%Match{} = match, tournament_runner_pid), do: run(match.id, tournament_runner_pid)

  def run(match_id, tournament_runner_pid) do
    # Our Runner might have crashed and been restarted.
    # We re-fetch the task from DB to avoid working on stale data
    match =
      Repo.get!(Match, match_id)
      |> Repo.preload([:agent_a, :agent_b, :tournament, :rounds])

    case match.status do
      :open ->
        Match.start(match) |> Repo.update()
        run(match, match.rounds_to_play, 0, tournament_runner_pid)
      :started ->
        round_no = count_match_rounds(match_id)
        run(match, match.rounds_to_play, round_no, tournament_runner_pid)
      :finished ->
        report_completed_match(match, tournament_runner_pid)
      :invalidated ->
        report_completed_match(match, tournament_runner_pid)
      :aborted ->
        report_completed_match(match, tournament_runner_pid)
    end
  end

  def run(match, rounds_to_play, round_no, tournament_runner_pid) when round_no < rounds_to_play do
    start_date = DateTime.utc_now()

    match_info = %MatchInfo{
      type: "Tournament Match",
      tournament_id: match.tournament_id,
      match_id: match.id
    }

    result_a = agent_a_decision_request(match, round_no, match_info)
    result_b = agent_b_decision_request(match, round_no, match_info)

    case {result_a, result_b} do
      {{:ok, decision_a}, {:ok, decision_b}} ->
        {:ok, _round} = tally_round(match.id, decision_a, decision_b, start_date)
        run(match, rounds_to_play, round_no + 1, tournament_runner_pid)
      {{:error, _}, {:ok, _}} ->
        abort_match(match, tournament_runner_pid)
      {{:ok, _}, {:error, _}} ->
        abort_match(match, tournament_runner_pid)
      _ ->
        abort_match(match, tournament_runner_pid)
    end
  end

  def run(match, _, _, tournament_runner_pid) do
    {:ok, finished_match} = Match.finish(match) |> Repo.update()
    report_completed_match(finished_match, tournament_runner_pid)
  end

  defp agent_a_decision_request(match, round_no, match_info) do
    past_results_a =
      Enum.map(match.rounds, fn round ->
        %PastResult{action: round.action_a, points: round.score_a}
      end)

    request_a = %Request{
      round_number: round_no,
      past_results: past_results_a,
      match_info: match_info
    }

    ConnectionManager.decide(match.agent_a, request_a)
  end

  defp agent_b_decision_request(match, round_no, match_info) do
    past_results_b =
      Enum.map(match.rounds, fn round ->
        %PastResult{action: round.action_b, points: round.score_b}
      end)

    request_b = %Request{
      round_number: round_no,
      past_results: past_results_b,
      match_info: match_info
    }

    ConnectionManager.decide(match.agent_b, request_b)
  end

  defp tally_round(match_id, action_a, action_b, start_date) do
    {score_a, score_b} =
      case {action_a, action_b} do
        {:cooperate, :cooperate} -> {3, 3}
        {:cooperate, :defect} -> {0, 5}
        {:defect, :cooperate} -> {5, 0}
        {:defect, :defect} -> {1, 1}
      end

    Round.new(match_id, action_a, action_b, score_a, score_b, start_date)
    |> Repo.insert()
  end

  defp count_match_rounds(match_id) do
    query =
      from r in Round,
      where: r.match_id == ^match_id

    Repo.aggregate(query, :count, :id)
  end

  defp abort_match(match, tournament_runner_pid) do
    {:ok, aborted_match} = Match.abort(match) |> Repo.update()
    report_completed_match(aborted_match, tournament_runner_pid)
  end

  defp report_completed_match(match, tournament_runner_pid) do
    Tournaments.Runner.report_finished_match(tournament_runner_pid, match)
  end

end
