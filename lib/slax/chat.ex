defmodule Slax.Chat do
  alias Slax.Chat.Room
  alias Slax.Repo

  import Ecto.Query

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
end
