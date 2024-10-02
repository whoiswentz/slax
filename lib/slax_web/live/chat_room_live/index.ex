defmodule SlaxWeb.ChatRoomLive.Index do
  use SlaxWeb, :live_view

  alias Slax.Chat

  def mount(_params, _session, socket) do
    rooms = Chat.list_rooms()

    socket =
      socket
      |> assign(page_title: "All rooms")
      |> stream_insert(:rooms, rooms)

    {:ok, socket}
  end

  def render(assigns) do
  end
end
