defmodule Vibe.Plugin.Manager.Collections do
  @moduledoc "Collects commands, APIs, presentation documents, and prompt blocks from plugins."

  alias Vibe.Presentation.Document

  @type plugin_entry :: {module(), %{state: term()}}

  @spec commands([plugin_entry()]) :: [module()]
  def commands(plugins) do
    plugins
    |> Enum.flat_map(fn {module, entry} -> plugin_commands(module, entry.state) end)
    |> Enum.uniq()
  end

  @spec apis([plugin_entry()]) :: [Vibe.Plugin.API.t()]
  def apis(plugins) do
    plugins
    |> Enum.flat_map(fn {module, entry} -> plugin_apis(module, entry.state) end)
    |> Enum.uniq_by(&{&1.alias, &1.module})
  end

  @spec presentation_document(map(), module()) :: Document.t()
  def presentation_document(plugins, module) do
    case Map.fetch(plugins, module) do
      {:ok, entry} -> plugin_presentation_document(module, entry.state)
      :error -> Document.empty()
    end
  end

  @spec system_prompt_blocks([plugin_entry()], map(), term(), function()) ::
          {[String.t()], term()}
  def system_prompt_blocks(plugins, context, state, put_plugin_state)
      when is_function(put_plugin_state, 3) do
    Enum.reduce(plugins, {[], state}, fn {module, entry}, {blocks, state} ->
      safe_system_prompt(module, entry, context, blocks, state, put_plugin_state)
    end)
    |> then(fn {blocks, state} -> {Enum.reverse(blocks), state} end)
  end

  defp plugin_commands(module, plugin_state) do
    with true <- function_exported?(module, :commands, 1),
         {:ok, commands} <- Vibe.Plugin.Manager.Callback.call(module, :commands, [plugin_state]) do
      commands
    else
      false -> []
      {:error, reason} -> Vibe.Plugin.Manager.Callback.log_failure(module, :commands, reason, [])
    end
  end

  defp plugin_apis(module, plugin_state) do
    with true <- function_exported?(module, :apis, 1),
         {:ok, apis} <- Vibe.Plugin.Manager.Callback.call(module, :apis, [plugin_state]) do
      Enum.map(apis, &Vibe.Plugin.API.new/1)
    else
      false -> []
      {:error, reason} -> Vibe.Plugin.Manager.Callback.log_failure(module, :apis, reason, [])
    end
  end

  defp plugin_presentation_document(module, plugin_state) do
    with true <- function_exported?(module, :presentation_document, 1),
         {:ok, document} <-
           Vibe.Plugin.Manager.Callback.call(module, :presentation_document, [plugin_state]) do
      Document.new(document)
    else
      false ->
        Document.empty()

      {:error, reason} ->
        Vibe.Plugin.Manager.Callback.log_failure(
          module,
          :presentation_document,
          reason,
          Document.empty()
        )
    end
  end

  defp safe_system_prompt(module, entry, context, blocks, state, put_plugin_state) do
    with true <- function_exported?(module, :system_prompt, 2),
         {:ok, result} <-
           Vibe.Plugin.Manager.Callback.call(module, :system_prompt, [context, entry.state]) do
      case result do
        {text, new_state} when is_binary(text) and text != "" ->
          {[text | blocks], put_plugin_state.(state, module, new_state)}

        {_nil_or_empty, new_state} ->
          {blocks, put_plugin_state.(state, module, new_state)}
      end
    else
      false ->
        {blocks, state}

      {:error, reason} ->
        Vibe.Plugin.Manager.Callback.log_failure(module, :system_prompt, reason)
        {blocks, state}
    end
  end
end
