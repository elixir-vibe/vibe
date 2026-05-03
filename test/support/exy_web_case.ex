defmodule Exy.WebCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint Exy.Web.Endpoint
    end
  end

  setup_all do
    Application.put_env(
      :exy,
      Exy.Web.Endpoint,
      Keyword.merge(Application.get_env(:exy, Exy.Web.Endpoint, []), server: false)
    )

    ensure_endpoint_started()
    :ok
  end

  defp ensure_endpoint_started do
    case Process.whereis(Exy.Web.Endpoint) do
      nil -> start_supervised!(Exy.Web.Endpoint)
      _pid -> :ok
    end
  end
end
