defmodule Exy.Subagents.Store do
  @moduledoc "JSONL-backed subagent schedule persistence."
  import Ecto.Query

  alias Exy.Storage
  alias Exy.Storage.Schema.SubagentSchedule
  alias Exy.Subagents.Schedule

  @spec append_created(Schedule.t()) :: :ok | {:error, term()}
  def append_created(%Schedule{} = schedule) do
    Storage.ensure!()
    now = Storage.normalize_datetime(DateTime.utc_now())

    %SubagentSchedule{}
    |> Map.merge(%{
      id: schedule.id,
      task: schedule.task,
      role: atom_string(schedule.role),
      parent_session_id: schedule.parent_session_id,
      run_at: Storage.normalize_datetime(schedule.at),
      every_ms: schedule.every_ms,
      missed: atom_string(schedule.missed || :skip),
      opts: opts(schedule.opts),
      next_run_at: Storage.normalize_datetime(schedule.next_run_at),
      inserted_at: now,
      updated_at: now
    })
    |> Exy.Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :id
    )
    |> ok()
  end

  @spec append_cancelled(String.t()) :: :ok | {:error, term()}
  def append_cancelled(id) do
    Storage.ensure!()
    now = Storage.normalize_datetime(DateTime.utc_now())

    SubagentSchedule
    |> where([schedule], schedule.id == ^id)
    |> Exy.Repo.update_all(set: [cancelled_at: now, updated_at: now])
    |> then(fn {_count, _rows} -> :ok end)
  end

  @spec schedules() :: [Schedule.t()]
  def schedules do
    if Storage.ready?() do
      SubagentSchedule
      |> where([schedule], is_nil(schedule.cancelled_at))
      |> order_by([schedule], schedule.inserted_at)
      |> Exy.Repo.all()
      |> Enum.map(&decode_schedule/1)
    else
      []
    end
  end

  defp decode_schedule(%SubagentSchedule{} = schedule) do
    %Schedule{
      id: schedule.id,
      task: schedule.task,
      role: schedule.role,
      parent_session_id: schedule.parent_session_id,
      at: schedule.run_at,
      every_ms: schedule.every_ms,
      missed: missed(schedule.missed),
      opts: decode_opts(schedule.opts || %{}),
      next_run_at: schedule.next_run_at
    }
  end

  defp opts(opts) do
    opts
    |> Enum.filter(fn {_key, value} -> json_safe?(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), json_safe(value)} end)
  end

  defp decode_opts(opts) when is_map(opts) do
    opts
    |> Enum.flat_map(&decode_opt/1)
  end

  defp decode_opt({"role", value}), do: [role: value]
  defp decode_opt({"parent_session_id", value}), do: [parent_session_id: value]
  defp decode_opt({"model", value}), do: [model: value]
  defp decode_opt({"provider_options", value}), do: [provider_options: value]
  defp decode_opt({"tools", value}), do: [tools: value]
  defp decode_opt({:role, value}), do: [role: value]
  defp decode_opt({:parent_session_id, value}), do: [parent_session_id: value]
  defp decode_opt({:model, value}), do: [model: value]
  defp decode_opt({:provider_options, value}), do: [provider_options: value]
  defp decode_opt({:tools, value}), do: [tools: value]
  defp decode_opt({_unknown, _value}), do: []

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

  defp ok({:ok, _result}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}
end
