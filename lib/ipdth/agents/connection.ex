defmodule Ipdth.Agents.Connection do
  @moduledoc """
  Module modeling the connection to an Agent and handling the communication
  with an Agent.
  """

  defmodule Request do
    @moduledoc """
    Struct representing the Request sent to an Agent.
    """

    @derive Jason.Encoder
    defstruct round_number: -1, past_results: [], match_info: %{}
  end

  defmodule PastResult do
    @moduledoc """
    Struct representing a past result from a round.
    """

    @derive Jason.Encoder
    defstruct action: "", points: 0
  end

  defmodule MatchInfo do
    @moduledoc """
    Struct representing information around a match.
    """

    @derive Jason.Encoder
    defstruct type: "Test Match", tournament_id: "", match_id: ""
  end

  def decide(agent, decision_request) do
    auth = {:bearer, agent.bearer_token}
    req = Req.new(json: decision_request, auth: auth, url: agent.url)

    with {:ok, response} <- Req.post(req) do
      case response.status do
        200 -> interpret_decision(response)
        # TODO: 2024-05-26 - Read config values for backoff and retried
        # TODO: 2024-05-26 - Put backoff-control and retries here
        # TODO: 2024-05-26 - Use Sleep and tail-recursion
        401 -> {:error, fill_error_details(:auth_error, response)}
        500 -> {:error, fill_error_details(:server_error, response)}
        _ -> {:error, fill_error_details(:undefined_error, response)}
      end
    end
  end

  def test(agent) do
    pid =
      Task.Supervisor.async_nolink(Ipdth.ConnectionTestSupervisor, fn ->
        auth = {:bearer, agent.bearer_token}
        test_request = create_test_request()

        req = Req.new(json: test_request, auth: auth, url: agent.url)

        with {:ok, response} <- Req.post(req) do
          case response.status do
            200 -> validate_body(response)
            401 -> {:error, fill_error_details(:auth_error, response)}
            500 -> {:error, fill_error_details(:server_error, response)}
            _ -> {:error, fill_error_details(:undefined_error, response)}
          end
        end
      end)

    case Task.yield(pid) do
      {:ok, result} ->
        Task.shutdown(pid)
        result

      {:exit, {exception, _stacktrace}} when is_exception(exception) ->
        Task.shutdown(pid)
        {:error, {:runtime_exception, Exception.message(exception)}}

      {:exit, {reason, details}} ->
        Task.shutdown(pid)
        {:error, {reason, details}}
    end
  end

  def interpret_decision(response) do
    json = response.body

    case json["action"] do
      "Cooperate" -> {:ok, :cooperate}
      "cooperate" -> {:ok, :cooperate}
      _ -> {:ok, :compete}
    end
  end

  def validate_body(response) do
    json = response.body

    if json["action"] != nil do
      :ok
    else
      {:error, {:no_action_given, json}}
    end
  end

  def fill_error_details(error, _response) do
    # TODO: 2024-03-17 - Do proper inspection of response body.
    {error, "TODO: fill in more details!"}
  end

  def create_test_request() do
    past_results =
      Enum.map(1..100, fn num ->
        modnum = Integer.mod(num, 2)

        if modnum == 0 do
          %PastResult{
            action: "Cooperate",
            points: modnum
          }
        else
          %PastResult{
            action: "Compete",
            points: modnum + 1
          }
        end
      end)

    %Request{
      round_number: 1,
      match_info: %MatchInfo{},
      past_results: past_results
    }
  end
end
