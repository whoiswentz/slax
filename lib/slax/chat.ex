defmodule Slax.Chat do
  alias Slax.Chat.Room
  alias Slax.Repo

  def get_first_room! do
    Room |> Repo.all() |> List.first()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_rooms do
    Room |> Repo.all()
  end
end
