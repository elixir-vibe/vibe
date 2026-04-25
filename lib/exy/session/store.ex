defmodule Exy.Session.Store do
  @moduledoc """
  Durable JSONL sessions for dialogs, tool events, and usage.
  """

  alias Exy.Trajectory

  @spec new_id() :: String.t()
  def new_id do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    now <> "-" <> suffix
  end

  @spec dir() :: String.t()
  def dir do
    :exy
    |> Application.get_env(:session_dir, "~/.exy/sessions")
    |> Path.expand()
  end

  @spec path(String.t()) :: String.t()
  def path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".jsonl")
  end

  @spec log_path(String.t()) :: String.t()
  def log_path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".log")
  end

  @spec append(Trajectory.t()) :: :ok | {:error, term()}
  def append(%Trajectory{session_id: nil}), do: :ok

  def append(%Trajectory{} = event) do
    with :ok <- File.mkdir_p(dir()),
         line <- Jason.encode!(encode_event(event)) <> "\n" do
      File.write(path(event.session_id), line, [:append])
    end
  end

  @spec events(String.t()) :: [Trajectory.t()]
  def events(session_id) when is_binary(session_id) do
    case File.read(path(session_id)) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.map(&decode_event/1)

      {:error, :enoent} ->
        []
    end
  end

  @spec list() :: [map()]
  def list do
    case File.ls(dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
        |> Enum.map(&session_info/1)
        |> Enum.sort_by(&DateTime.to_unix(&1.updated_at), :desc)

      {:error, _reason} ->
        []
    end
  end

  defp session_info(file) do
    full_path = Path.join(dir(), file)
    stat = File.stat!(full_path, time: :posix)

    %{
      id: Path.rootname(file),
      path: full_path,
      size: stat.size,
      updated_at: DateTime.from_unix!(stat.mtime)
    }
  end

  defp encode_event(%Trajectory{} = event) do
    %{
      "id" => event.id,
      "session_id" => event.session_id,
      "type" => Atom.to_string(event.type),
      "at" => DateTime.to_iso8601(event.at),
      "data" => json_safe(event.data)
    }
  end

  defp decode_event(line) do
    with {:ok, map} <- Jason.decode(line),
         {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]) do
      Trajectory.new(String.to_atom(map["type"]), atomize(map["data"] || %{}),
        id: map["id"],
        session_id: map["session_id"],
        at: at
      )
    end
  end

  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value), do: value

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {to_string(key), json_safe(value)} end)
  rescue
    _exception -> inspect(value, limit: 50)
  end

  defp json_safe(value), do: inspect(value, limit: 50)

  defp atomize(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {String.to_atom(key), atomize(value)} end)

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(value), do: value

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
