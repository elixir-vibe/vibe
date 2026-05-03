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
    live("/sessions", SessionsLive, :index)
    live("/sessions/:id", SessionLive, :show)
    get("/sessions/:session_id/artifacts/*path", ArtifactController, :show)
    live("/jobs", JobsLive, :index)
    live("/memory", MemoryLive, :index)
    live("/docs", DocsLive, :show)
    live("/docs/:topic", DocsLive, :show)
    live("/storage", StorageLive, :index)
    live("/settings", SettingsLive, :index)
    live("/plugins", PluginsLive, :index)
    live("/plugins/:module", PluginsLive, :show)
    live("/skills", SkillsLive, :index)
    live("/skills/:name", SkillsLive, :show)
    live("/search", SearchLive, :index)
    live("/runtime", RuntimeLive, :index)
  end
end
