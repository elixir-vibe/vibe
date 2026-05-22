defmodule Vibe.Model.Default do
  @moduledoc false

  @model "openai_codex:gpt-5.5"

  @spec model() :: String.t()
  def model, do: @model
end
