defmodule Ipdth.Tournaments do
  @moduledoc """
  The Tournaments context.
  """

  import Ecto.Query, warn: false
  alias Ipdth.Repo

  alias Ipdth.Tournaments.Tournament
  alias Ipdth.Accounts

  @doc """
  Returns the list of tournaments.

  ## Examples

      iex> list_tournaments()
      [%Tournament{}, ...]

  """
  def list_tournaments() do
    Repo.all(from t in Tournament, where: t.status != ^:created)
  end

  def list_tournaments(actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin)do
      Repo.all(Tournament)
    else
      list_tournaments()
    end
  end

  @doc """
  Gets a single tournament.

  Raises `Ecto.NoResultsError` if the Tournament does not exist.

  ## Examples

      iex> get_tournament!(123)
      %Tournament{}

      iex> get_tournament!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tournament!(id) do
    Repo.one(from t in Tournament, where: t.id == ^id and t.status != ^:created)
  end

  def get_tournament!(id, actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin) do
      Repo.get!(Tournament, id)
    else
      get_tournament!(id)
    end
  end

  @doc """
  Creates a tournament.

  ## Examples

      iex> create_tournament(%{field: value})
      {:ok, %Tournament{}}

      iex> create_tournament(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tournament(attrs \\ %{}, actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin) do
      %Tournament{}
      |> Tournament.new(attrs)
      |> Repo.insert()
    else
      {:error, :not_authorized}
    end
  end

  @doc """
  Updates a tournament.

  ## Examples

      iex> update_tournament(tournament, %{field: new_value})
      {:ok, %Tournament{}}

      iex> update_tournament(tournament, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tournament(%Tournament{} = tournament, attrs, actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin) do
      if Enum.member?([:created, :published], tournament.status) do
        tournament
        |> Tournament.changeset(attrs)
        |> Repo.update()
      else
        {:error, :tournament_editing_locked}
      end
    else
      {:error, :not_authorized}
    end
  end

  @doc """
  Publish a tournament (:created -> :published)

  Once published only it's name and description may be changed.
  TODO: 2024-04-30 - Write Test for publish_tournament!
  """
  def publish_tournament(%Tournament{status: :created} = tournament, actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin) do
      tournament
      |> Tournament.publish()
      |> Repo.update()
    else
      {:error, :not_authorized}
    end
  end

  def publish_tournament(%Tournament{}, _) do
    {:error, :already_published}
  end


  @doc """
  Deletes a tournament.

  ## Examples

      iex> delete_tournament(tournament)
      {:ok, %Tournament{}}

      iex> delete_tournament(tournament)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tournament(%Tournament{} = tournament, actor_id) do
    if Accounts.has_role?(actor_id, :tournament_admin) do
      Repo.delete(tournament)
    else
      {:error, :not_authorized}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tournament changes.

  ## Examples

      iex> change_tournament(tournament)
      %Ecto.Changeset{data: %Tournament{}}

  """
  def change_tournament(%Tournament{} = tournament, attrs \\ %{}) do
    Tournament.changeset(tournament, attrs)
  end

  alias Ipdth.Tournaments.Participation

  @doc """
  Returns the list of participations.

  ## Examples

      iex> list_participations()
      [%Participation{}, ...]

  """
  def list_participations do
    Repo.all(Participation)
  end

  @doc """
  Gets a single participation.

  Raises `Ecto.NoResultsError` if the Participation does not exist.

  ## Examples

      iex> get_participation!(123)
      %Participation{}

      iex> get_participation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_participation!(id), do: Repo.get!(Participation, id)

  @doc """
  Creates a participation.

  ## Examples

      iex> create_participation(%{field: value})
      {:ok, %Participation{}}

      iex> create_participation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_participation(attrs \\ %{}) do
    %Participation{}
    |> Participation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a participation.

  ## Examples

      iex> update_participation(participation, %{field: new_value})
      {:ok, %Participation{}}

      iex> update_participation(participation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_participation(%Participation{} = participation, attrs) do
    participation
    |> Participation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a participation.

  ## Examples

      iex> delete_participation(participation)
      {:ok, %Participation{}}

      iex> delete_participation(participation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_participation(%Participation{} = participation) do
    Repo.delete(participation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking participation changes.

  ## Examples

      iex> change_participation(participation)
      %Ecto.Changeset{data: %Participation{}}

  """
  def change_participation(%Participation{} = participation, attrs \\ %{}) do
    Participation.changeset(participation, attrs)
  end
end
