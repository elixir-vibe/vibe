defmodule Exy.Prompts do
  @moduledoc "Compile-time prompt embedding from `priv/prompts/*.md`."
  @prompt_files %{
    system: "system.md",
    summarization_system: "summarization_system.md",
    context_summary: "context_summary.md",
    context_update: "context_update.md",
    turn_prefix_summary: "turn_prefix_summary.md"
  }

  for {_name, file} <- @prompt_files do
    @external_resource Application.app_dir(:exy, Path.join("priv/prompts", file))
  end

  @prompts Map.new(@prompt_files, fn {name, file} ->
             {name, File.read!(Application.app_dir(:exy, Path.join("priv/prompts", file)))}
           end)

  @spec fetch!(atom()) :: String.t()
  def fetch!(name), do: Map.fetch!(@prompts, name)

  @spec system() :: String.t()
  def system, do: Application.get_env(:exy, :system_prompt, fetch!(:system))

  @spec summarization_system() :: String.t()
  def summarization_system, do: fetch!(:summarization_system)

  @spec context_summary() :: String.t()
  def context_summary, do: fetch!(:context_summary)

  @spec context_update() :: String.t()
  def context_update, do: fetch!(:context_update)

  @spec turn_prefix_summary() :: String.t()
  def turn_prefix_summary, do: fetch!(:turn_prefix_summary)
end
