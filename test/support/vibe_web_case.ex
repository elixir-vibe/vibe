defmodule Vibe.WebCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint Vibe.Web.Endpoint

      defp authenticated_conn do
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{"vibe_web_auth" => true})
      end
    end
  end

  setup_all do
    Application.put_env(
      :vibe,
      Vibe.Web.Endpoint,
      Keyword.merge(Application.get_env(:vibe, Vibe.Web.Endpoint, []), server: false)
    )

    ensure_endpoint_started()
    :ok
  end

  defp ensure_endpoint_started do
    case Process.whereis(Vibe.Web.Endpoint) do
      nil -> start_supervised!(Vibe.Web.Endpoint)
      _pid -> :ok
    end
  end
end
