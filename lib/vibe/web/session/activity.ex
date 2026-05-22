defmodule Vibe.Web.Session.Activity do
  @moduledoc "Session activity helpers for web surfaces."

  @spec working?(map()) :: boolean()
  def working?(state) do
    Map.get(state, :status) in [:working, :running] or
      not is_nil(Map.get(state, :streaming_message)) or
      running_tool?(Map.get(state, :pending_tools))
  end

  @spec visible_stream?(map()) :: boolean()
  def visible_stream?(state) do
    streaming_message = Map.get(state, :streaming_message)

    not is_nil(streaming_message) and
      String.trim(Map.get(streaming_message, :text, "")) != ""
  end

  @spec activity_label(map()) :: String.t() | nil
  def activity_label(state) do
    cond do
      running_tool?(Map.get(state, :pending_tools)) ->
        pending_tool_label(Map.get(state, :pending_tools))

      visible_stream?(state) ->
        "Writing…"

      working?(state) ->
        "Thinking…"

      true ->
        nil
    end
  end

  defp running_tool?(pending_tools) do
    Enum.any?(pending_tools || %{}, fn {_id, tool} -> running_tool_status?(tool) end)
  end

  defp pending_tool_label(pending_tools) do
    pending_tools
    |> Enum.find_value(fn {_id, tool} -> if running_tool_status?(tool), do: tool end)
    |> case do
      nil -> "Running tool…"
      tool -> "Running #{tool_label(tool)}…"
    end
  end

  defp running_tool_status?(tool), do: Map.get(tool, :status) in [:running, "running", nil]

  defp tool_label(tool) do
    tool
    |> Map.get(:name, "tool")
    |> to_string()
    |> String.replace("_", " ")
  end
end
