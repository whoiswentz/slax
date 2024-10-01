defmodule SlaxWeb.OnlineUsers do
  alias SlaxWeb.Presence

  @topic "online_users"

  def list do
    @topic
    |> Presence.list()
    |> Enum.into(%{}, fn {id, %{metas: metas}} ->
      {String.to_integer(id), length(metas)}
    end)
  end

  def track(pid, user) do
    {:ok, _} =
      Presence.track(pid, @topic, user.id, %{})

    :ok
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Slax.PubSub, @topic)
  end

  def update(online_users, %{joins: joins, leaves: leaves}) do
    online_users
    |> process_update(joins, &Kernel.+/2)
    |> process_update(leaves, &Kernel.-/2)
  end

  def process_update(online_users, updates, operation) do
    Enum.reduce(updates, online_users, fn {id, %{metas: metas}}, acc ->
      Map.update(acc, String.to_integer(id), length(metas), &operation.(&1, length(metas)))
    end)
  end

  def online?(online_users, user_id) do
    Map.get(online_users, user_id, 0) > 0
  end
end
