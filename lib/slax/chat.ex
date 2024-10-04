defmodule Slax.Chat do
  import Ecto.Query

  alias Slax.Accounts.User
  alias Slax.Chat.{Room, Message, RoomMembership}
  alias Slax.Repo

  @pubsub Slax.PubSub

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def get_first_room! do
    from(r in Room)
    |> limit(1)
    |> order_by(asc: :name)
    |> Repo.one!()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_rooms do
    from(r in Room)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def list_joined_rooms(%User{} = user) do
    user
    |> Repo.preload(:rooms)
    |> Map.fetch!(:rooms)
    |> Enum.sort_by(& &1.name)
  end

  def list_rooms_with_joined(%User{} = user) do
    from(r in Room)
    |> join(:left, [r], rm in RoomMembership, on: r.id == rm.room_id and rm.user_id == ^user.id)
    |> select([r, rm], {r, not is_nil(rm.id)})
    |> order_by([r, _], asc: r.name)
    |> Repo.all()
  end

  def toggle_room_membership(%Room{} = room, %User{} = user) do
    case get_room_membership(room, user) do
      %RoomMembership{} = room_membership ->
        Repo.delete(room_membership)
        {room, false}

      nil ->
        join_room!(room, user)
        {room, true}
    end
  end

  def get_room_membership(%Room{id: room_id}, %User{id: user_id}) do
    Repo.get_by(RoomMembership, room_id: room_id, user_id: user_id)
  end

  def joined?(%Room{} = room, %User{} = user) do
    from(rm in RoomMembership)
    |> where([rm], rm.room_id == ^room.id)
    |> where([rm], rm.user_id == ^user.id)
    |> Repo.exists?()
  end

  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def list_messages_in_room(%Room{id: room_id}) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], asc: :inserted_at, asc: :id)
    |> preload(:user)
    |> Repo.all()
  end

  def create_message(room, attrs, user) do
    created_message =
      %Message{room: room, user: user}
      |> Message.changeset(attrs)
      |> Repo.insert()

    with {:ok, message} <- created_message do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
    end

    created_message
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)

    Repo.delete(message)

    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end
end
