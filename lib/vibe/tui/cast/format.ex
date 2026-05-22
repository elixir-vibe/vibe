defmodule Vibe.TUI.Cast.Format do
  @moduledoc false

  @magic "VIBE_TUI_CAST\0"
  @version 1

  def magic, do: @magic
  def version, do: @version

  def encode_block(term, :none), do: :erlang.term_to_binary(term)
  def encode_block(term, :gzip), do: term |> :erlang.term_to_binary() |> :zlib.gzip()

  def decode_block(binary, :none), do: :erlang.binary_to_term(binary, [:safe])
  def decode_block(binary, :gzip), do: binary |> :zlib.gunzip() |> :erlang.binary_to_term([:safe])
end
