defmodule Exy.Web.SearchLiveTest do
  use Exy.WebCase, async: false

  test "redirects to storage" do
    {:error, {:live_redirect, %{to: to}}} = live(build_conn(), "/search")

    assert to == "/storage"
  end
end
