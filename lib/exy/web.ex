defmodule Exy.Web do
  @moduledoc "Internal implementation module."
  @static_paths ~w(assets fonts images favicon.ico robots.txt)

  @spec static_paths() :: [String.t()]
  def static_paths, do: @static_paths

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    port = Keyword.get(opts, :port, 4321)
    Application.put_env(:exy, Exy.Web.Endpoint, endpoint_config(port))
    Exy.Web.Assets.ensure_built!()
    Exy.Web.Endpoint.start_link()
  end

  @spec url(keyword()) :: String.t()
  def url(opts \\ []), do: "http://localhost:#{Keyword.get(opts, :port, 4321)}"

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Phoenix.Controller
      import Phoenix.LiveView.Router
      import Plug.Conn
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller, only: [get_csrf_token: 0]
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      alias Exy.Web.Layouts
      import Exy.Web.Components
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Exy.Web.Endpoint,
        router: Exy.Web.Router,
        statics: Exy.Web.static_paths()
    end
  end

  defp endpoint_config(port) do
    :exy
    |> Application.get_env(Exy.Web.Endpoint, [])
    |> Keyword.put(:http, ip: {127, 0, 0, 1}, port: port)
    |> Keyword.put(:server, true)
    |> Keyword.put(:secret_key_base, secret_key_base())
  end

  defp secret_key_base do
    path = Path.join(Exy.Paths.home(), "web-secret-key-base")
    File.mkdir_p!(Path.dirname(path))

    unless File.exists?(path) do
      secret = 64 |> :crypto.strong_rand_bytes() |> Base.encode64(padding: false)
      File.write!(path, secret, [:write])
      File.chmod!(path, 0o600)
    end

    path
    |> File.read!()
    |> String.trim()
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
