defmodule Vibe.Web.SearchLiveTest do
  use Vibe.WebCase, async: false

  test "redirects to storage" do
    {:error, {:live_redirect, %{to: to}}} = live(build_conn(), "/search")

    assert to == "/storage"
  end
end
