defmodule GoprintRegistryWeb.PageController do
  use GoprintRegistryWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: {GoprintRegistryWeb.Layouts, :landing})
  end

  def pricing(conn, _params) do
    render(conn, :pricing, layout: {GoprintRegistryWeb.Layouts, :landing})
  end

  def download(conn, _params) do
    render(conn, :download, layout: {GoprintRegistryWeb.Layouts, :landing})
  end

  def docs(conn, _params) do
    render(conn, :docs, layout: {GoprintRegistryWeb.Layouts, :landing})
  end
end
