defmodule Exy.CLI.FileArgsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Exy.CLI.Commands.Default
  alias Exy.Model.Content

  test "default command passes @file args as direct multimodal prompt" do
    parent = self()

    ask_fun = fn prompt, _opts ->
      send(parent, {:prompt, prompt})
      {:ok, "ok"}
    end

    output =
      capture_io(fn ->
        assert :ok =
                 Default.run(["@test/fixtures/images/vision-smoke.png", "describe"],
                   direct: true,
                   no_stream: true,
                   direct_ask_fun: ask_fun
                 )
      end)

    assert output =~ "ok"
    assert_receive {:prompt, [%Content.Text{text: text}, %Content.Image{} = image]}
    assert text =~ ~s(<file name=)
    assert text =~ "describe"
    assert image.mime_type == "image/png"
    assert image.width == 320
    assert image.height == 200
  end
end
