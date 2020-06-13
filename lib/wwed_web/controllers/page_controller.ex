defmodule WwedWeb.PageController do
  use WwedWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
  
  def join_room(conn,  %{"room_name" => room}=params) do
    render(conn, "room.html", name: room, pwd: inspect params)
  end
end
