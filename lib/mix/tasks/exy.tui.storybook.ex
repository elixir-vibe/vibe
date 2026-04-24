defmodule Mix.Tasks.Exy.Tui.Storybook do
  @shortdoc "Render Exy TUI storybook stories"

  @moduledoc """
  Renders Exy's TUI storybook.

      mix exy.tui.storybook
      mix exy.tui.storybook --story tool_eval_ok --width 100
      mix exy.tui.storybook --plain
      mix exy.tui.storybook --theme light

  """

  use Mix.Task

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [story: :string, width: :integer, plain: :boolean, theme: :string],
        aliases: [s: :story, w: :width]
      )

    width = opts[:width] || terminal_width()
    theme = Exy.TUI.Theme.named(opts[:theme])

    stories =
      if opts[:story],
        do: [story!(opts[:story])],
        else: Exy.TUI.Storybook.stories()

    Enum.each(stories, fn story ->
      IO.puts("\n#{story}\n" <> String.duplicate("=", String.length(to_string(story))))

      lines =
        if opts[:plain] do
          Exy.TUI.Storybook.render_plain(story, width: width, theme: theme)
        else
          Exy.TUI.Storybook.render(story, width: width, theme: theme)
        end

      Enum.each(lines, &IO.puts(IO.iodata_to_binary(&1)))
    end)
  end

  defp story!(name) do
    Enum.find(Exy.TUI.Storybook.stories(), &(to_string(&1) == name)) ||
      Mix.raise("unknown story #{inspect(name)}")
  end

  defp terminal_width do
    case :io.columns() do
      {:ok, columns} -> columns
      _ -> 100
    end
  end
end
