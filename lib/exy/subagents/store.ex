defmodule Exy.Subagents.Store do
  @moduledoc false

  alias Exy.Subagents.Schedule

  @spec append_created(Schedule.t()) :: :ok | {:error, term()}
  def append_created(%Schedule{} = schedule), do: append("schedule_created", encode(schedule))

  @spec append_cancelled(String.t()) :: :ok | {:error, term()}
  def append_cancelled(id), do: append("schedule_cancelled", %{"id" => id})

  @spec schedules() :: [Schedule.t()]
  def schedules do
    path()
    |> read_events()
    |> Enum.reduce(%{}, fn
      {"schedule_created", data}, acc ->
        case decode_schedule(data) do
          {:ok, schedule} -> Map.put(acc, schedule.id, schedule)
          :error -> acc
        end

      {"schedule_cancelled", %{"id" => id}}, acc ->
        Map.delete(acc, id)

      _event, acc ->
        acc
    end)
    |> Map.values()
  end

  defp append(type, data) do
    entry =
      Map.merge(data, %{"entry_type" => type, "at" => DateTime.to_iso8601(DateTime.utc_now())})

    with :ok <- File.mkdir_p(Path.dirname(path())) do
      File.write(path(), Jason.encode!(entry) <> "\n", [:append])
    end
  end

  defp read_events(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&decode_line/1)

      {:error, :enoent} ->
        []
    end
  end

  defp decode_line(line) do
    case Jason.decode(line) do
      {:ok, %{"entry_type" => type} = data} -> [{type, data}]
      _ -> []
    end
  end

  defp encode(schedule) do
    %{
      "id" => schedule.id,
      "task" => schedule.task,
      "role" => atom_string(schedule.role),
      "parent_session_id" => schedule.parent_session_id,
      "run_at" => datetime(schedule.at),
      "every_ms" => schedule.every_ms,
      "missed" => atom_string(schedule.missed || :skip),
      "opts" => opts(schedule.opts)
    }
  end

  defp decode_schedule(%{"id" => id, "task" => task} = data) do
    {:ok,
     %Schedule{
       id: id,
       task: task,
       role: data["role"],
       parent_session_id: data["parent_session_id"],
       at: parse_datetime(data["run_at"]),
       every_ms: data["every_ms"],
       missed: missed(data["missed"]),
       opts: decode_opts(data["opts"] || %{})
     }}
  end

  defp decode_schedule(_data), do: :error

  defp opts(opts) do
    opts
    |> Enum.filter(fn {_key, value} -> json_safe?(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), json_safe(value)} end)
  end

  defp decode_opts(opts) when is_map(opts) do
    Enum.map(opts, fn {key, value} -> {String.to_existing_atom(key), value} end)
  rescue
    ArgumentError -> []
  end

  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  defp json_safe?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp json_safe?(value) when is_atom(value), do: true
  defp json_safe?(value) when is_list(value), do: Enum.all?(value, &json_safe?/1)

  defp json_safe?(value) when is_map(value),
    do: Enum.all?(value, fn {key, val} -> json_safe?(key) and json_safe?(val) end)

  defp json_safe?(_value), do: false

  defp atom_string(nil), do: nil
  defp atom_string(value) when is_atom(value), do: Atom.to_string(value)
  defp atom_string(value), do: to_string(value)

  defp missed("run_once"), do: :run_once
  defp missed("catch_up"), do: :catch_up
  defp missed(_value), do: :skip

  defp datetime(nil), do: nil
  defp datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp datetime(value), do: value

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp path, do: Exy.Paths.subagent_schedules()
end
