defmodule Vibe.UI.SlashCommands.Skill do
  @moduledoc "Slash command: /skill — invoke executable skills."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.Event
  alias Vibe.UI.Selector
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "skill", description: "Invoke a skill", selectors: [:skill_selector]}

  def skill_selector, do: :skill_selector

  @impl true
  def run("", session_state) do
    selector = %Selector{
      kind: :skill_selector,
      title: "Skill",
      items: skill_items(),
      selected: 0,
      limit: 8
    }

    {:events, [Event.new(:selector_opened, session_state.session_id, selector)]}
  end

  def run(args, session_state) do
    {name, prompt} = parse_args(args)
    invoke(name, prompt, session_state)
  end

  @impl true
  def selector_action(%{value: skill}, session_state) when is_binary(skill),
    do: invoke(skill, "", session_state)

  def selector_action(skill, session_state) when is_binary(skill),
    do: invoke(skill, "", session_state)

  def selector_action(_item, _session_state), do: :ignore

  defp invoke(skill, args, session_state) do
    case Vibe.Skill.invocation(skill, args) do
      {:ok, text} ->
        {:command, {:submit_prompt, %{text: text}}}

      {:error, reason} ->
        {:events,
         [
           Event.new(:notification_added, session_state.session_id, %{
             level: :warning,
             text: reason
           })
         ]}
    end
  end

  defp skill_items do
    Vibe.Skill.list()
    |> Enum.map(fn skill ->
      %{value: skill.name, label: skill.name, detail: Map.get(skill, :title)}
    end)
  end

  defp parse_args(args) do
    case String.split(String.trim(args), ~r/\s+/, parts: 2, trim: true) do
      [name, prompt] -> {name, prompt}
      [name] -> {name, ""}
      [] -> {"", ""}
    end
  end
end
