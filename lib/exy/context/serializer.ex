defmodule Exy.Context.Serializer do
  @moduledoc "Internal implementation module."
  alias Exy.Trajectory

  @tool_result_max_chars 2_000

  @spec serialize([Trajectory.t()]) :: String.t()
  def serialize(events) do
    events
    |> Enum.map(&serialize_event/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @spec estimate_tokens([Trajectory.t()]) :: non_neg_integer()
  def estimate_tokens(events), do: div(String.length(serialize(events)), 4)

  @spec file_operations([Trajectory.t()]) :: %{
          read: MapSet.t(String.t()),
          modified: MapSet.t(String.t())
        }
  def file_operations(events) do
    %{read: MapSet.new(read_files(events)), modified: MapSet.new(modified_files(events))}
  end

  @spec read_files([Trajectory.t()]) :: [String.t()]
  def read_files(events), do: file_paths(events, [:read, :read_file]) -- modified_files(events)

  @spec modified_files([Trajectory.t()]) :: [String.t()]
  def modified_files(events), do: file_paths(events, [:edit, :write, :replace])

  @spec format_file_operations(%{read: MapSet.t(String.t()), modified: MapSet.t(String.t())}) ::
          String.t()
  def format_file_operations(%{read: read, modified: modified}) do
    sections = []

    sections =
      if MapSet.size(read) > 0,
        do: ["<read-files>\n#{Enum.join(read, "\n")}\n</read-files>" | sections],
        else: sections

    sections =
      if MapSet.size(modified) > 0,
        do: ["<modified-files>\n#{Enum.join(modified, "\n")}\n</modified-files>" | sections],
        else: sections

    case Enum.reverse(sections) do
      [] -> ""
      sections -> "\n\n" <> Enum.join(sections, "\n\n")
    end
  end

  defp serialize_event(%Trajectory{type: :user_message, data: %{prompt: prompt}}),
    do: "[User]: #{prompt}"

  defp serialize_event(%Trajectory{type: :assistant_message, data: %{result: result}}) do
    "[Assistant]: #{truncate(inspect(result, pretty: true, limit: 50), @tool_result_max_chars)}"
  end

  defp serialize_event(%Trajectory{type: :tool_call, data: data}) do
    name = Map.get(data, :name) || Map.get(data, :action)
    args = Map.get(data, :args) || Map.drop(data, [:name, :result])

    "[Assistant tool call]: #{name}(#{inspect(args, limit: 20)})"
  end

  defp serialize_event(%Trajectory{type: :tool_result, data: %{result: result}}) do
    "[Tool result]: #{truncate(inspect(result, pretty: true, limit: 50), @tool_result_max_chars)}"
  end

  defp serialize_event(%Trajectory{type: :compaction, data: %{summary: summary}}) do
    "[Prior compaction summary]: #{summary}"
  end

  defp serialize_event(%Trajectory{type: type, data: data}) do
    "[#{type}]: #{truncate(inspect(data, pretty: true, limit: 50), @tool_result_max_chars)}"
  end

  defp file_paths(events, actions) do
    events
    |> Enum.flat_map(fn event ->
      action = get_in(event.data, [:action])
      path = get_in(event.data, [:path])

      if action in actions and is_binary(path), do: [path], else: []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp truncate(text, max_chars) when byte_size(text) <= max_chars, do: text

  defp truncate(text, max_chars) do
    truncated = byte_size(text) - max_chars
    binary_part(text, 0, max_chars) <> "\n\n[... #{truncated} more characters truncated]"
  end
end
