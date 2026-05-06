defmodule Vibe.Web.Endpoint do
  @moduledoc "Phoenix endpoint configuration for the web console."
  use Phoenix.Endpoint, otp_app: :vibe

  @session_options [
    store: :cookie,
    key: "_vibe_web_key",
    signing_salt: "vibe-web",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :vibe,
    gzip: false,
    only: Vibe.Web.static_paths()
  )

  plug(Volt.DevServer, root: "assets")

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(Vibe.Web.Router)
end
