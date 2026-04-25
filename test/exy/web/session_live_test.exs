defmodule Exy.Web.SessionLiveTest do
  use ExUnit.Case, async: false

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-web-session-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    :ok
  end

  test "mounts a session, submits prompts, and applies session events" do
    socket = %{assigns: %{}}

    assert {:ok, socket} = Exy.Web.SessionLive.mount(%{}, %{}, socket)
    assert socket.assigns.session_id
    assert socket.assigns.view_model.footer.session_id == socket.assigns.session_id

    assert {:noreply, socket} =
             Exy.Web.SessionLive.handle_info(
               {Exy.Session, :event,
                Exy.UI.Event.new(:notification_added, socket.assigns.session_id, %{text: "hello"})},
               socket
             )

    assert [%{text: "hello"}] = socket.assigns.ui_state.notifications
  end
end
