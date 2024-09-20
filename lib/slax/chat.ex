defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Chat.{Room, Message}
  alias Slax.Repo

  import Ecto.Query

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
end
