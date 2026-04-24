defmodule Exy.TUI.KeyDecoder do
  @moduledoc """
  Terminal byte-sequence decoder for editor-level keys.
  """

  @type key :: Exy.UI.Editor.key()

  @spec decode(binary()) :: [key()]
  def decode("\eb"), do: [:word_left]
  def decode("\ef"), do: [:word_right]
  def decode("\e[D"), do: [:left]
  def decode("\e[C"), do: [:right]
  def decode("\e[A"), do: [:up]
  def decode("\e[B"), do: [:down]
  def decode("\e[H"), do: [:home]
  def decode("\e[F"), do: [:end]
  def decode("\e[3~"), do: [:delete]
  def decode("\u007F"), do: [:backspace]
  def decode("\b"), do: [:backspace]
  def decode("\r"), do: [:submit]
  def decode("\n"), do: [:enter]
  def decode("\t"), do: [:tab]
  def decode("\e"), do: [:cancel]
  def decode(<<3>>), do: [:cancel]

  def decode(data) when is_binary(data) do
    cond do
      printable?(data) and String.length(data) == 1 -> [{:insert, data}]
      printable?(data) -> [{:paste, data}]
      true -> []
    end
  end

  defp printable?(data), do: String.printable?(data) and not String.match?(data, ~r/[\p{C}]/u)
end
