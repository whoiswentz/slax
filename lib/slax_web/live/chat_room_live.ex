defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>Welcome to the chat!</div>
    <Layouts.app flash={@flash}>
      <h1>Chat Room</h1>
    </Layouts.app>
    """
  end
end
