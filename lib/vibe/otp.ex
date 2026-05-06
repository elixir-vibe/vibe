defmodule Vibe.OTP do
  @moduledoc """
  Small OTP/runtime introspection helpers intended for `Vibe.Eval`.
  """

  @spec top(:memory | :reductions | :message_queue_len, keyword()) :: [map()]
  def top(sort \\ :memory, opts \\ []) do
    sort
    |> sorted_processes()
    |> Enum.take(Keyword.get(opts, :limit, 15))
    |> Enum.flat_map(&process_summary/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {summary, index} -> Map.put(summary, :index, index) end)
  end

  @spec process_at(:memory | :reductions | :message_queue_len, pos_integer()) :: pid() | nil
  def process_at(sort \\ :memory, index \\ 1) when is_integer(index) and index > 0 do
    sort
    |> sorted_processes()
    |> Enum.at(index - 1)
  end

  @spec process_info(
          pid()
          | atom()
          | String.t()
          | {:pid, pid()}
          | {:registered, atom() | String.t()}
        ) ::
          map() | nil
  def process_info(process) do
    process
    |> resolve_process()
    |> case do
      nil ->
        nil

      pid ->
        keys = [
          :registered_name,
          :initial_call,
          :current_function,
          :status,
          :message_queue_len,
          :memory,
          :reductions,
          :links,
          :monitors,
          :monitored_by,
          :dictionary
        ]

        pid
        |> Process.info(keys)
        |> case do
          nil -> nil
          info -> Map.new(info) |> Map.put(:pid, inspect(pid))
        end
    end
  end

  @spec supervision_tree(module() | pid() | atom() | nil, keyword()) :: map() | nil
  def supervision_tree(root \\ nil, opts \\ []) do
    depth = Keyword.get(opts, :depth, :infinity)

    root
    |> resolve_root_supervisor()
    |> case do
      nil -> nil
      pid -> supervisor_node(pid, depth)
    end
  end

  @spec ets_tables(keyword()) :: [map()]
  def ets_tables(opts \\ []) do
    sort = Keyword.get(opts, :sort, :memory)
    limit = Keyword.get(opts, :limit, 50)

    :ets.all()
    |> Enum.map(&ets_info/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&Map.get(&1, sort, 0), :desc)
    |> Enum.take(limit)
  end

  @spec runtime_info() :: map()
  def runtime_info do
    %{
      otp_release: :erlang.system_info(:otp_release) |> List.to_string(),
      elixir: System.version(),
      schedulers: :erlang.system_info(:schedulers_online),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      memory: :erlang.memory() |> Map.new()
    }
  end

  defp sorted_processes(sort) do
    Process.list()
    |> Enum.flat_map(&process_sort_value(&1, sort))
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(&elem(&1, 0))
  end

  defp process_sort_value(pid, sort) do
    case Process.info(pid, sort) do
      {^sort, value} when is_integer(value) -> [{pid, value}]
      _info -> []
    end
  end

  defp process_summary(pid) do
    keys = [
      :registered_name,
      :initial_call,
      :current_function,
      :message_queue_len,
      :memory,
      :reductions
    ]

    case Process.info(pid, keys) do
      nil ->
        []

      info ->
        map = Map.new(info)

        [
          %{
            pid: inspect(pid),
            name: map[:registered_name],
            initial_call: map[:initial_call],
            current_function: map[:current_function],
            message_queue_len: map[:message_queue_len] || 0,
            memory: map[:memory] || 0,
            reductions: map[:reductions] || 0
          }
        ]
    end
  end

  defp resolve_process(pid) when is_pid(pid), do: pid
  defp resolve_process({:pid, pid}) when is_pid(pid), do: pid
  defp resolve_process({:registered, name}), do: resolve_registered_name(name)
  defp resolve_process(name) when is_atom(name), do: Process.whereis(name)
  defp resolve_process(name) when is_binary(name), do: resolve_registered_name(name)
  defp resolve_process(_process), do: nil

  defp resolve_registered_name(name) when is_atom(name), do: Process.whereis(name)

  defp resolve_registered_name(text) when is_binary(text) do
    text
    |> registered_name_from_string()
    |> resolve_process()
  end

  defp resolve_registered_name(_name), do: nil

  defp registered_name_from_string(text) do
    Enum.find(Process.registered(), fn name ->
      Atom.to_string(name) == text or inspect(name) == text
    end)
  end

  defp resolve_root_supervisor(nil) do
    Process.whereis(Vibe.Supervisor) || first_supervisor()
  end

  defp resolve_root_supervisor(root), do: resolve_process(root) || first_supervisor()

  defp first_supervisor do
    Process.registered()
    |> Enum.find_value(fn name ->
      pid = Process.whereis(name)

      if pid && supervisor?(pid), do: pid
    end)
  end

  defp supervisor?(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        Keyword.get(dict, :"$initial_call") == {Supervisor, Supervisor.Default, 1}

      _ ->
        false
    end
  end

  defp supervisor_node(pid, 0), do: %{pid: inspect(pid), children: :max_depth}

  defp supervisor_node(pid, depth) do
    children =
      try do
        Supervisor.which_children(pid)
      catch
        _, _ -> []
      end

    %{
      pid: inspect(pid),
      name: Process.info(pid, :registered_name) |> elem(1),
      children: Enum.map(children, &child_node(&1, next_depth(depth)))
    }
  end

  defp child_node({id, pid, type, modules}, depth) when is_pid(pid) do
    base = %{id: id, pid: inspect(pid), type: type, modules: modules}

    if type == :supervisor and depth != 0,
      do: Map.put(base, :children, supervisor_node(pid, depth).children),
      else: base
  end

  defp child_node({id, value, type, modules}, _depth),
    do: %{id: id, value: inspect(value), type: type, modules: modules}

  defp next_depth(:infinity), do: :infinity
  defp next_depth(depth) when is_integer(depth), do: max(depth - 1, 0)

  defp ets_info(table) do
    case :ets.info(table) do
      :undefined ->
        nil

      info ->
        map = Map.new(info)

        %{
          id: inspect(table),
          name: map[:name],
          owner: inspect(map[:owner]),
          size: map[:size],
          memory: map[:memory],
          type: map[:type],
          protection: map[:protection]
        }
    end
  end
end
