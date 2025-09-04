defmodule GoprintRegistryWeb.PageController do
  use GoprintRegistryWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
