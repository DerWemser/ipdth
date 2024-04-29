defmodule IpdthWeb.TournamentLive.Index do
  use IpdthWeb, :live_view

  alias Ipdth.Tournaments
  alias Ipdth.Tournaments.Tournament

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:active_page, "tournaments")
     |> stream(:tournaments, Tournaments.list_tournaments(current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_user

    socket
    |> assign(:page_title, "Edit Tournament")
    |> assign(:tournament, Tournaments.get_tournament!(id, current_user.id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Tournament")
    |> assign(:tournament, %Tournament{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Tournaments")
    |> assign(:tournament, nil)
  end

  @impl true
  def handle_info({IpdthWeb.TournamentLive.FormComponent, {:saved, tournament}}, socket) do
    {:noreply, stream_insert(socket, :tournaments, tournament)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    tournament = Tournaments.get_tournament!(id, current_user.id)

    if current_user do
      {:ok, _} = Tournaments.delete_tournament(tournament, current_user.id)
      {:noreply, stream_delete(socket, :tournaments, tournament)}
    else
      # TODO 2024-04-28 -- Show error flash about missing permission
      {:noreply, socket}
    end
  end
end
