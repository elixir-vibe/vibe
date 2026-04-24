defmodule Exy.SystemPrompt do
  @moduledoc false

  @prompt_path Exy.Prompts.path("system.md")
  @external_resource @prompt_path
  @default Exy.Prompts.read!("system.md")

  @spec default() :: String.t()
  def default, do: Application.get_env(:exy, :system_prompt, @default)
end
