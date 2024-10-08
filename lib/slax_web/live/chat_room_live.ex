defmodule SlaxWeb.ChatRoomLive do
  alias SlaxWeb.TypingUsers
  alias SlaxWeb.OnlineUsers
  alias Slax.Accounts
  use SlaxWeb, :live_view

  alias Slax.Chat
  alias Slax.Chat.Room
  alias Slax.Accounts.User
  alias Slax.Chat.Message

  def mount(_params, _session, socket) do
    rooms = Chat.list_joined_rooms(socket.assigns.current_user)
    users = Accounts.list_users()
    timezone = get_connect_params(socket)["timezone"]

    if connected?(socket) do
      OnlineUsers.track(self(), socket.assigns.current_user)
    end

    OnlineUsers.subscribe()
    TypingUsers.subscribe()

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(timezone: timezone)
     |> assign(users: users)
     |> assign(typing: false)
     |> assign(online_users: OnlineUsers.list())
     |> assign(hide_topic?: false)}
  end

  def handle_params(params, _session, socket) do
    if socket.assigns[:room], do: Chat.unsubscribe_from_room(socket.assigns.room)

    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Chat.get_room!(id)

        :error ->
          Chat.get_first_room!()
      end

    joined = Chat.joined?(room, socket.assigns.current_user)
    last_read_id = Chat.get_last_read_id(room, socket.assigns.current_user)

    Chat.subscribe_to_room(room)

    messages =
      room
      |> Chat.list_messages_in_room()
      |> maybe_insert_unread_marker(last_read_id)

    {:noreply,
     socket
     |> assign(:room, room)
     |> assign(new_message_form: to_form(Chat.change_message(%Message{})))
     |> assign(page_title: "#" <> room.name)
     |> assign(hide_topic?: false)
     |> assign(joined?: joined)
     |> stream(:messages, messages, reset: true)
     |> push_event("scroll_messages_to_bottom", %{})}
  end

  def handle_event("toggle-topic", _params, socket) do
    {:noreply, update(socket, :hide_topic?, &(!&1))}
  end

  def handle_event("validate-message", %{"message" => message_params}, socket) do
    changeset = Chat.change_message(%Message{}, message_params)

    {:noreply, assign(socket, new_message_form: to_form(changeset))}
  end

  def handle_event("delete-message", %{"id" => id}, socket) do
    Chat.delete_message_by_id(id, socket.assigns.current_user)
    {:noreply, socket}
  end

  def handle_event("submit-message", %{"message" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    socket =
      if Chat.joined?(room, current_user) do
        case Chat.create_message(room, message_params, current_user) do
          {:ok, _message} ->
            assign(socket, new_message_form: to_form(Chat.change_message(%Message{})))

          {:error, changeset} ->
            assign(socket, new_message_form: to_form(changeset))
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("user_typing", _params, socket) do
    user_id = socket.assigns.current_user.id

    if not TypingUsers.is_tracked(user_id) do
      TypingUsers.track(self(), socket.assigns.current_user)
    end

    {:noreply, socket}
  end

  def handle_event("user_stop_typing", _params, socket) do
    TypingUsers.untrack(self(), socket.assigns.current_user)
    {:noreply, socket}
  end

  def handle_event("join-room", _params, socket) do
    current_user = socket.assigns.current_user
    room = socket.assigns.room

    Chat.join_room!(room, current_user)
    Chat.subscribe_to_room(room)

    rooms = Chat.list_joined_rooms(current_user)

    {:noreply,
     socket
     |> assign(joined?: true)
     |> assign(rooms: rooms)}
  end

  def handle_info({:new_message, message}, socket) do
    socket =
      socket
      |> stream_insert(:messages, message)
      |> push_event("scroll_messages_to_bottom", %{})

    {:noreply, socket}
  end

  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  def handle_info(%{event: "presence_diff", topic: "online_users", payload: diff}, socket) do
    online_users = OnlineUsers.update(socket.assigns.online_users, diff)
    {:noreply, assign(socket, online_users: online_users)}
  end

  def handle_info(%{event: "presence_diff", topic: "typing_users", payload: diff}, socket) do
    typing = TypingUsers.someone_is_typing?(diff)
    {:noreply, assign(socket, typing: typing)}
  end

  defp username(user) do
    user.email
    |> String.split("@")
    |> List.first()
    |> String.capitalize()
  end

  defp maybe_insert_unread_marker(messages, nil), do: messages

  defp maybe_insert_unread_marker(messages, last_read_id) do
    {read, unread} = Enum.split(messages, &(&1.id <= last_read_id))

    if unread == [] do
      read
    else
      read ++ [:unread_marker | unread]
    end
  end

  attr :active, :boolean, required: true
  attr :room, Room, required: true

  defp room_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center h-8 text-sm pl-8 pr-3",
        (@active && "bg-slate-300") || "hover:bg-slate-300"
      ]}
      patch={~p"/rooms/#{@room}"}
    >
      <.icon name="hero-hashtag" class="h-4 w-4" />
      <span class={[
        "ml-2 leading-none",
        @active && "font-bold"
      ]}>
        <%= @room.name %>
      </span>
    </.link>
    """
  end

  attr :message, Message, required: true
  attr :dom_id, :string, required: true
  attr :timezone, :string, required: true
  attr :current_user, User, required: true

  defp message(assigns) do
    ~H"""
    <div id={@dom_id} class="group relative flex px-4 py-3">
      <button
        :if={@current_user.id == @message.user_id}
        data-confirm="Are you sure?"
        phx-click="delete-message"
        phx-value-id={@message.id}
        class="absolute top-4 right-4 text-red-500 hover:text-red-800 cursor-pointer hidden group-hover:block"
      >
        <.icon name="hero-trash" class="h-4 w-4" />
      </button>
      <div class="h-10 w-10 rounded flex-shrink-0 bg-slate-300"></div>
      <div class="ml-2">
        <.link class="text-sm font-semibold hover:underline">
          <span><%= username(@message.user) %></span>
        </.link>
        <span :if={@timezone} class="ml-1 text-xs text-gray-500">
          <%= message_timestamp(@message, @timezone) %>
        </span>
        <p class="text-sm"><%= @message.body %></p>
      </div>
    </div>
    """
  end

  attr :user, User, required: true
  attr :online, :boolean, default: false

  defp user(assigns) do
    ~H"""
    <.link class="flex items-center h-8 hover:bg-gray-300 text-sm pl-8 pr-3" href="#">
      <div class="flex justify-center w-4">
        <%= if @online do %>
          <span class="w-2 h-2 rounded-full bg-blue-500"></span>
        <% else %>
          <span class="w-2 h-2 rounded-full border-2 border-gray-500"></span>
        <% end %>
      </div>
      <span class="ml-2 leading-none"><%= username(@user) %></span>
    </.link>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col flex-shrink-0 w-64 bg-slate-100">
      <div class="flex justify-between items-center flex-shrink-0 h-16 border-b border-slate-300 px-4">
        <div class="flex flex-col gap-1.5">
          <h1 class="text-lg font-bold text-gray-800">
            Slax
          </h1>
        </div>
      </div>
      <div class="mt-4 auto">
        <div class="flex items-center h-8 px-3 group">
          <span class="ml-2 leading-none font-medium text-sm">Rooms</span>
        </div>
        <div id="rooms-list">
          <.room_link :for={room <- @rooms} room={room} active={room.id == @room.id} />
          <button class="group relative flex items-center h-8 text-sm pl-8 pr-3 hover:bg-slate-300 cursor-pointer w-full">
            <.icon name="hero-plus" class="h-4 w-4 relative top-px" />
            <span class="ml-2 leading-none">Add Room</span>
            <div class="hidden group-focus:block cursour-default absolute top-8 right-2 bg-white border-slate-200 border py-3 rounded-lg">
              <div class="w-full text-left">
                <div class="hover:bg-sky-600">
                  <div
                    phx-click={JS.navigate(~p"/rooms")}
                    class="cursor-pointer whitespace-nowrap text-gray-800 hover:text-white px-6 py-1"
                  >
                    Browse rooms
                  </div>
                </div>
              </div>
            </div>
          </button>
        </div>
        <div class="mt-4">
          <div class="flex items-center h-8 px-3 group">
            <div class="flex items-center flex-grow focus:outline-none">
              <span class="ml-2 leading-none font-medium text-sm">Users</span>
            </div>
          </div>
          <div id="users-list">
            <.user
              :for={user <- @users}
              user={user}
              online={OnlineUsers.online?(@online_users, user.id)}
            />
          </div>
        </div>
      </div>
    </div>
    <div class="flex flex-col flex-grow shadow-lg">
      <div class="flex justify-between items-center flex-shrink-0 h-16 bg-white border-b border-slate-300 px-4">
        <div class="flex flex-col gap-1.5">
          <h1 class="text-sm font-bold leading-none">
            #<%= @room.name %>
            <.link
              :if={@joined?}
              class="font-normal text-xs text-blue-600 hover:text-blue-700"
              navigate={~p"/rooms/#{@room}/edit"}
            >
              Edit
            </.link>
          </h1>
          <div class="text-xs leading-none h-3.5" phx-click="toggle-topic">
            <%= if @hide_topic? do %>
              <span class="text-slate-500">
                [Topic hidden]
              </span>
            <% else %>
              <%= @room.topic %>
            <% end %>
          </div>
        </div>
        <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
          <%= if @current_user do %>
            <li class="text-[0.8125rem] leading-6 text-zinc-900">
              <%= username(@current_user) %>
            </li>
            <li>
              <.link
                href={~p"/users/settings"}
                class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
              >
                Settings
              </.link>
            </li>
            <li>
              <.link
                href={~p"/users/log_out"}
                method="delete"
                class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
              >
                Log out
              </.link>
            </li>
          <% else %>
            <li>
              <.link
                href={~p"/users/register"}
                class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
              >
                Register
              </.link>
            </li>
            <li>
              <.link
                href={~p"/users/log_in"}
                class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
              >
                Log in
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
      <div
        id="room-messages"
        class="flex flex-col flex-grow overflow-auto"
        phx-hook="RoomMessages"
        phx-update="stream"
      >
        <.message
          :for={{dom_id, message} <- @streams.messages}
          dom_id={dom_id}
          current_user={@current_user}
          message={message}
          timezone={@timezone}
        />
      </div>
      <div :if={@joined?} class="h-24 bg-white px-4 pb-4">
        <div
          :if={@typing}
          class="flex-grow overflow-auto text-sm px-3 border-l border-slate-300 mx-1 resize-none"
        >
          <span>Someone is typing...</span>
        </div>
        <.form
          class="flex items-center border-2 border-slate-300 rounded-sm p-1"
          id="new-message-form"
          for={@new_message_form}
          phx-change="validate-message"
          phx-submit="submit-message"
        >
          <textarea
            class="flex-grow text-sm px-3 border-l border-slate-300 mx-1 resize-none"
            cols=""
            id="chat-message-textarea"
            name={@new_message_form[:body].name}
            placeholder={"Message ##{@room.name}"}
            phx-debounce
            phx-hook="ChatMessageTextArea"
            rows="1"
          >
          <%= Phoenix.HTML.Form.normalize_value("textarea", @new_message_form[:body].value) %>
          </textarea>
          <button class="flex-shrink flex items-center justify-center h-6 w-6 rounded hover:bg-slate-200">
            <.icon name="hero-paper-airplane" class="h-4 w-4" />
          </button>
        </.form>
      </div>
      <div
        :if={!@joined?}
        class="flex justify-around mx-5 mb-5 p-6 bg-slate-100 border-slate-300 border-rounded-lg"
      >
        <div class="max-w-3-xl text-center">
          <div class="mb-4">
            <h1 class="text-xl font-semibold"><%= @room.name %></h1>
            <p :if={@room.topic} class="text-sm mt-1 text-gray-500"><%= @room.topic %></p>
          </div>
          <div class="flex items-center justify-around">
            <button
              phx-click="join-room"
              class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-600 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              Join Room
            </button>
          </div>
          <div class="mt-4">
            <.link
              navigate={~p"/rooms"}
              href="#"
              class="text-sm text-slate-500 underline hover:text-slate-600"
            >
              Back to All Rooms
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end
end
