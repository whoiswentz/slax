defmodule SlaxWeb.TypingUsers do
  alias SlaxWeb.Presence

  @topic "typing_users"

  def list do
    @topic
    |> Presence.list()
    |> Enum.into(%{}, fn {id, %{metas: metas}} ->
      {String.to_integer(id), length(metas)}
    end)
  end

  def is_tracked(user) do
    case Map.get(list(), user, false) do
      false -> false
      _ -> true
    end
  end

  def track(pid, user, metadata \\ %{}) do
    {:ok, _} =
      Presence.track(pid, @topic, user.id, metadata)

    :ok
  end

  def untrack(pid, user) do
    Presence.untrack(pid, @topic, user.id)
  end

  def someone_is_typing?(%{joins: joins}) do
    length(Map.keys(joins)) != 0
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Slax.PubSub, @topic)
  end
end
