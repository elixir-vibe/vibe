defmodule Vibe.CLI.Sessions do
  @moduledoc "Session listing, prune, and attach helpers for CLI."
  alias Vibe.CLI.{Output, Runner, Server}
  alias Vibe.CLI.Sessions.Filter

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["prune", "--empty"], opts), do: Output.print(prune_empty(), opts)
  def command(["prune", "--artifacts"], opts), do: Output.print(prune_artifacts(), opts)

  def command(["prune"], _opts) do
    Output.error("Usage: vibe sessions prune --empty|--artifacts")
    {:error, :invalid_sessions_command}
  end

  def command([], opts) do
    case server_call(&Vibe.Remote.Session.list/0) do
      {:ok, sessions} -> Output.print({:ok, Filter.apply(sessions, opts)}, opts)
      error -> Output.print(error, opts)
    end
  end

  def command(_args, _opts) do
    Output.error(
      "Usage: vibe sessions [--all] [--live] [--failed] [--limit n] | prune --empty|--artifacts"
    )

    {:error, :invalid_sessions_command}
  end

  @spec new(keyword()) :: :ok | {:error, term()}
  def new(opts) do
    Output.print(
      server_call(fn -> Vibe.Remote.Session.start(session_opts(opts)) end),
      opts
    )
  end

  @spec new_tui(keyword()) :: :ok | {:error, term()}
  def new_tui(opts) do
    case server_call(fn -> Vibe.Remote.Session.start(session_opts(opts)) end) do
      {:ok, %{id: session_id}} -> attach(session_id, opts)
      other -> Output.print(other, opts)
    end
  end

  @spec send_prompt(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def send_prompt(session_id, text, opts) do
    Output.print(server_call(fn -> Vibe.Remote.Session.send_prompt(session_id, text) end), opts)
  end

  @spec attach_default(keyword()) :: :ok | {:error, term()}
  def attach_default(opts) do
    Runner.configure_api_key(opts)

    case Vibe.Remote.connect() do
      {:ok, node} ->
        session_id = opts[:session] || new_remote_session_id(opts)
        attach(session_id, Keyword.put(opts, :remote_node, node))

      {:error, _reason} ->
        Server.launch_background()
        Runner.tui(opts, start_server_async: true)
    end
  end

  @spec attach(String.t(), keyword()) :: :ok | {:error, term()}
  def attach(session_id, opts) do
    case server_call(fn -> Vibe.Remote.Session.lookup(session_id) end) do
      {:ok, session} ->
        opts = Keyword.put_new(opts, :remote_node, session_node(session))
        Runner.tui(opts, session_server: session, session_id: session_id)

      {:error, :not_found} ->
        attach_subagent_child(session_id, opts)

      {:error, reason} ->
        Output.print({:error, reason}, opts)
    end
  end

  defp attach_subagent_child(job_id, opts) do
    case server_call(fn -> Vibe.Subagents.status(job_id) end) do
      {:ok, %{child_session_id: child_session_id}} when is_binary(child_session_id) ->
        attach(child_session_id, opts)

      {:ok, _job} ->
        Output.print({:error, :subagent_has_no_child_session}, opts)

      {:error, reason} ->
        Output.print({:error, reason}, opts)
    end
  end

  defp session_opts(opts) do
    opts
    |> Keyword.take([:model, :role, :system])
    |> Keyword.put_new_lazy(:model, fn -> Vibe.Model.Config.resolve(opts) end)
  end

  defp server_call(fun) do
    case Server.ensure_running() do
      :ok -> fun.()
      {:error, reason} -> {:error, {:server_not_running, reason}}
    end
  end

  @doc """
  Returns the newest live remote session id for explicit attach commands.

  Plain `mix vibe` intentionally starts a fresh session; this helper is limited to
  attach-oriented CLI flows and tests that need to inspect server listings.
  """
  def latest_live_remote_session_id do
    case server_call(&Vibe.Remote.Session.list/0) do
      {:ok, sessions} -> latest_live_session_id(sessions)
      sessions when is_list(sessions) -> latest_live_session_id(sessions)
      {:error, _reason} -> nil
      {:badrpc, _reason} -> nil
    end
  end

  @doc """
  Picks the first live session id from a remote session listing.
  """
  def latest_live_session_id(sessions) when is_list(sessions) do
    sessions
    |> Enum.find(fn session -> Map.get(session, :live?, false) end)
    |> then(fn session -> session && Map.get(session, :id) end)
  end

  defp new_remote_session_id(opts) do
    case server_call(fn -> Vibe.Remote.Session.start(session_opts(opts)) end) do
      {:ok, %{id: id}} -> id
      {:error, reason} -> raise "cannot create Vibe session: #{inspect(reason)}"
    end
  end

  defp session_node(session) when is_pid(session) do
    node = node(session)
    if node == Node.self(), do: nil, else: node
  end

  defp session_node(_session), do: nil

  defp prune_empty do
    pruned = Vibe.Session.Store.prune_empty()

    {:ok, %{pruned: length(pruned), sessions: pruned}}
  end

  defp prune_artifacts do
    pruned = Vibe.Files.Artifacts.prune_orphans()

    {:ok, %{pruned: length(pruned), artifact_dirs: pruned}}
  end
end
