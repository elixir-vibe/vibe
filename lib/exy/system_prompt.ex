defmodule Exy.SystemPrompt do
  @moduledoc false

  @prompt_path Path.expand("../../priv/prompts/system.md", __DIR__)
  @external_resource @prompt_path
  @default File.read!(@prompt_path)

  @spec default() :: String.t()
  def default, do: Application.get_env(:exy, :system_prompt, @default)
end
