defmodule Vibe.CLI.FileArgsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Vibe.CLI.Commands.Default
  alias Vibe.Model.Content

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

  test "errors explicitly when @file is missing" do
    parent = self()

    ask_fun = fn _prompt, _opts ->
      send(parent, :should_not_reach)
      {:ok, "nope"}
    end

    output =
      capture_io(:stderr, fn ->
        result =
          Default.run(["@nonexistent.png", "describe"],
            direct: true,
            no_stream: true,
            direct_ask_fun: ask_fun
          )

        assert {:error, _reason} = result
      end)

    assert output =~ "File not found"
    refute_received :should_not_reach
  end
end
