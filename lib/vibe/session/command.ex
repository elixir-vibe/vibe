defmodule Vibe.Session.Command do
  @moduledoc "Slash command dispatch and autocomplete."
  alias Vibe.UI.Autocomplete
  alias Vibe.UI.Autocomplete.Item
  alias Vibe.Event
  alias Vibe.Session.Command.Registry

  @command_autocomplete_cache_key {__MODULE__, :command_autocomplete_items}
  @command_autocomplete_cache_ttl_ms 5_000
  @skill_autocomplete_cache_key {__MODULE__, :skill_autocomplete_items}
  @skill_autocomplete_cache_ttl_ms 30_000

  @spec autocomplete(String.t()) :: Autocomplete.t() | nil
  def autocomplete("/" <> text) do
    query = text |> String.split(~r/\s+/, parts: 2) |> hd()

    items = cached_command_autocomplete_items() ++ skill_autocomplete_items_for_query(query)

    Autocomplete.filter(items, query, title: "Commands", limit: 7)
  end

  def autocomplete(_text), do: nil

  @spec handle(String.t(), String.t(), map()) :: Vibe.Session.Command.Command.result()
  def handle("skill:" <> skill, args, session_state),
    do: Vibe.Session.Command.Skill.run(Enum.join([skill, args], " "), session_state)

  def handle(command, args, session_state) do
    case Registry.find(command) do
      nil -> unknown_command(command, session_state)
      module -> module.run(args, session_state)
    end
  end

  @spec selector_action(map(), map()) ::
          Vibe.Session.Command.Command.result() | {:command, String.t()}
  def selector_action(%{selector: selector, item: item}, session_state) do
    case Registry.find_selector(selector) do
      nil -> :ignore
      module -> run_selector_action(module, item, session_state)
    end
  end

  def selector_action(_data, _session_state), do: :ignore

  defp run_selector_action(module, item, session_state) when is_atom(module),
    do: module.selector_action(item, session_state)

  defp cached_command_autocomplete_items do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get(@command_autocomplete_cache_key, nil) do
      {expires_at, items} when expires_at > now ->
        items

      _stale ->
        items = Registry.specs() |> Enum.map(&autocomplete_item/1)

        :persistent_term.put(
          @command_autocomplete_cache_key,
          {now + @command_autocomplete_cache_ttl_ms, items}
        )

        items
    end
  end

  defp autocomplete_item(spec) do
    %Item{
      value: "/" <> spec.name,
      label: "/" <> spec.name,
      detail: Map.get(spec, :description),
      group: :slash_command
    }
  end

  defp skill_autocomplete_items_for_query("skill" <> _suffix),
    do: cached_skill_autocomplete_items()

  defp skill_autocomplete_items_for_query(_query), do: []

  defp cached_skill_autocomplete_items do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get(@skill_autocomplete_cache_key, nil) do
      {expires_at, items} when expires_at > now ->
        items

      _stale ->
        items = skill_autocomplete_items()

        :persistent_term.put(
          @skill_autocomplete_cache_key,
          {now + @skill_autocomplete_cache_ttl_ms, items}
        )

        items
    end
  end

  defp skill_autocomplete_items do
    Vibe.Skill.list()
    |> Enum.map(fn skill ->
      %Item{
        value: "/skill:" <> skill.name,
        label: "/skill:" <> skill.name,
        detail: Map.get(skill, :title),
        group: :skill
      }
    end)
  end

  defp unknown_command(command, session_state) do
    {:events,
     [
       Event.new(
         :notification_added,
         session_state.session_id,
         Vibe.Event.Notification.added(level: :warning, text: "unknown command: /#{command}")
       )
     ]}
  end
end
