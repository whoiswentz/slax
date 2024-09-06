defmodule SlaxWeb.ChatRoomLive.Edit do
  alias Slax.Chat
  use SlaxWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    room = Chat.get_room!(id)
    changeset = Chat.change_room(room)

    {:ok,
     socket
     |> assign(room: room)
     |> assign(page_title: "Edit chat room")
     |> assign(form: to_form(changeset))}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-96 mt-12">
      <.header>
        <%= @page_title %>
        <:actions>
          <.link
            class="font-normal text-xs text-blue-600 hover:text-blue-700"
            navigate={~p"/rooms/#{@room}"}
          >
            Back
          </.link>
        </:actions>
      </.header>
      <.simple_form for={@form} id="room-form">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:topic]} type="text" label="Topic" />
        <:actions>
          <.button class="w-full" phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
