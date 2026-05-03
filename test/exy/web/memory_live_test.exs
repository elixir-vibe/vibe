defmodule Exy.Web.MemoryLiveTest do
  use Exy.WebCase, async: false

  setup do
    Exy.Memory.clear(:user)
    Exy.Memory.clear(:global)
    :ok
  end

  test "renders and manages user memory" do
    {:ok, view, html} = live(build_conn(), "/memory")

    assert html =~ "Memory"
    assert html =~ "Save memory"

    html =
      view
      |> form("form[phx-submit='add']", %{
        memory: %{scope: "user", text: "Prefer semantic web renderers."}
      })
      |> render_submit()

    assert html =~ "Prefer semantic web renderers."

    [entry] = Exy.Memory.list(:user)

    html =
      view
      |> element("button[phx-value-id='#{entry.id}']", "Delete")
      |> render_click()

    refute html =~ "Prefer semantic web renderers."
  end
end
