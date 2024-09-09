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

  def handle_event("validate-room", %{"room" => room_params}, socket) do
    changeset =
      socket.assigns.room
      |> Chat.change_room(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save-room", %{"room" => room_params}, socket) do
    case Chat.update_room(socket.assigns.room, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room update successfully")
         |> push_navigate(to: ~p"/rooms/#{room}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, changeset)}
    end
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
      <.simple_form for={@form} id="room-form" phx-change="validate-room" phx-submit="save-room">
        <.input field={@form[:name]} type="text" label="Name" phx-debounce />
        <.input field={@form[:topic]} type="text" label="Topic" phx-debounce />
        <:actions>
          <.button class="w-full" phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
