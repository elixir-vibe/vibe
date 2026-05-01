defmodule Exy.TUI.Syntax do
  @moduledoc "Internal implementation module."
  @dim_elixir_theme %Lumis.Theme{
    name: "exy_dim_elixir",
    appearance: :dark,
    revision: "local",
    highlights: %{
      "attribute" => %Lumis.Theme.Style{fg: "#8f8f8f"},
      "boolean" => %Lumis.Theme.Style{fg: "#8a8a8a"},
      "comment" => %Lumis.Theme.Style{fg: "#666666", italic: true},
      "constant" => %Lumis.Theme.Style{fg: "#969696"},
      "constructor" => %Lumis.Theme.Style{fg: "#a8a8a8"},
      "function" => %Lumis.Theme.Style{fg: "#b0b0b0"},
      "function.call" => %Lumis.Theme.Style{fg: "#b0b0b0"},
      "keyword" => %Lumis.Theme.Style{fg: "#9c9c9c"},
      "module" => %Lumis.Theme.Style{fg: "#a8a8a8"},
      "number" => %Lumis.Theme.Style{fg: "#8a8a8a"},
      "operator" => %Lumis.Theme.Style{fg: "#707070"},
      "punctuation" => %Lumis.Theme.Style{fg: "#707070"},
      "string" => %Lumis.Theme.Style{fg: "#9a9a9a"},
      "variable" => %Lumis.Theme.Style{fg: "#9a9a9a"}
    }
  }

  @spec highlight_inline_elixir(String.t()) :: IO.chardata()
  def highlight_inline_elixir(code) when is_binary(code) do
    code
    |> String.replace("\n", " ")
    |> highlight_elixir(@dim_elixir_theme)
  end

  @spec highlight_elixir(String.t()) :: IO.chardata()
  def highlight_elixir(code) when is_binary(code), do: highlight_elixir(code, "onedark")

  defp highlight_elixir(code, theme) do
    {:ok, highlighted} =
      Lumis.highlight(code,
        formatter: {:terminal, language: "elixir", theme: theme, background: nil}
      )

    highlighted
  rescue
    _error -> code
  end
end
