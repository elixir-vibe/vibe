defmodule Exy.Web.Router do
  @moduledoc "Internal implementation module."
  use Exy.Web, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Exy.Web.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", Exy.Web do
    pipe_through(:browser)

    live("/", SessionsLive, :index)
    live("/sessions/:id", SessionLive, :show)
  end
end
