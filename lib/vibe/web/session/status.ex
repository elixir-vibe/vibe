defmodule Vibe.Web.Session.Status do
  @moduledoc "Status and activity helpers for the session workbench."

  @spec working?(map()) :: boolean()
  def working?(state) do
    state.status in [:working, :running] or not is_nil(state.streaming_message) or
      Enum.any?(state.pending_tools || %{}, fn {_id, tool} ->
        Map.get(tool, :status) in [:running, "running", nil]
      end)
  end

  @spec visible_stream?(map()) :: boolean()
  def visible_stream?(state) do
    not is_nil(state.streaming_message) and
      String.trim(Map.get(state.streaming_message, :text, "")) != ""
  end

  @spec activity_label(map()) :: String.t() | nil
  def activity_label(state) do
    cond do
      Enum.any?(state.pending_tools || %{}) -> pending_tool_label(state.pending_tools)
      visible_stream?(state) -> "Writing…"
      working?(state) -> "Thinking…"
      true -> nil
    end
  end

  defp pending_tool_label(pending_tools) do
    pending_tools
    |> Enum.find_value(fn {_id, tool} ->
      if Map.get(tool, :status) in [:running, "running", nil], do: tool
    end)
    |> case do
      nil -> "Running tool…"
      tool -> "Running #{tool_label(tool)}…"
    end
  end

  defp tool_label(tool) do
    tool
    |> Map.get(:name, "tool")
    |> to_string()
    |> String.replace("_", " ")
  end
end
