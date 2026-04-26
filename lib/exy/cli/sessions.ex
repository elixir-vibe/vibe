defmodule Exy.CLI.Sessions do
  @moduledoc false

  alias Exy.CLI.{Output, Runner, Server}

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["prune", "--empty"], opts), do: Output.print(prune_empty(), opts)

  def command(["prune"], _opts) do
    Output.error("Usage: exy sessions prune --empty")
    {:error, :invalid_sessions_command}
  end

  def command([], opts) do
    case server_call(&Exy.Remote.Session.list/0) do
      {:ok, sessions} -> Output.print({:ok, filter(sessions, opts)}, opts)
      error -> Output.print(error, opts)
    end
  end

  def command(_args, _opts) do
    Output.error("Usage: exy sessions [--all] [--live] [--failed] [--limit n] | prune --empty")
    {:error, :invalid_sessions_command}
  end

  @spec new(keyword()) :: :ok | {:error, term()}
  def new(opts) do
    Output.print(
      server_call(fn -> Exy.Remote.Session.start(session_opts(opts)) end),
      opts
    )
  end

  @spec new_tui(keyword()) :: :ok | {:error, term()}
  def new_tui(opts) do
    case server_call(fn -> Exy.Remote.Session.start(session_opts(opts)) end) do
      {:ok, %{id: session_id}} -> attach(session_id, opts)
      other -> Output.print(other, opts)
    end
  end

  @spec send_prompt(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def send_prompt(session_id, text, opts) do
    Output.print(server_call(fn -> Exy.Remote.Session.send_prompt(session_id, text) end), opts)
  end

  @spec attach_default(keyword()) :: :ok | {:error, term()}
  def attach_default(opts) do
    Runner.configure_api_key(opts)

    case Exy.Remote.connect() do
      {:ok, node} ->
        session_id =
          opts[:session] || latest_live_remote_session_id() || new_remote_session_id(opts)

        attach(session_id, Keyword.put(opts, :remote_node, node))

      {:error, _reason} ->
        Server.launch_background()
        Runner.tui(opts)
    end
  end

  @spec attach(String.t(), keyword()) :: :ok | {:error, term()}
  def attach(session_id, opts) do
    case server_call(fn -> Exy.Remote.Session.lookup(session_id) end) do
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
    case server_call(fn -> Exy.Subagents.status(job_id) end) do
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
    |> Keyword.put_new_lazy(:model, fn -> Exy.Model.Config.resolve(opts) end)
  end

  defp server_call(fun) do
    case Server.ensure_running() do
      :ok -> fun.()
      {:error, reason} -> {:error, {:server_not_running, reason}}
    end
  end

  defp latest_live_remote_session_id do
    case server_call(&Exy.Remote.Session.list/0) do
      {:ok, sessions} -> sessions |> Enum.find(& &1[:live?]) |> then(&(&1 && &1.id))
      {:error, _reason} -> nil
    end
  end

  defp new_remote_session_id(opts) do
    case server_call(fn -> Exy.Remote.Session.start(session_opts(opts)) end) do
      {:ok, %{id: id}} -> id
      {:error, reason} -> raise "cannot create Exy session: #{inspect(reason)}"
    end
  end

  defp session_node(session) when is_pid(session) do
    node = node(session)
    if node == Node.self(), do: nil, else: node
  end

  defp session_node(_session), do: nil

  defp filter(sessions, opts) do
    sessions
    |> maybe_filter_live(opts[:live])
    |> maybe_filter_failed(opts[:failed])
    |> maybe_filter_useful(opts[:all] || opts[:live] || opts[:failed])
    |> Enum.take(opts[:limit] || if(opts[:all], do: length(sessions), else: 20))
  end

  defp maybe_filter_live(sessions, true), do: Enum.filter(sessions, & &1[:live?])
  defp maybe_filter_live(sessions, _live?), do: sessions

  defp maybe_filter_failed(sessions, true), do: Enum.filter(sessions, &failed?/1)
  defp maybe_filter_failed(sessions, _failed?), do: sessions

  defp maybe_filter_useful(sessions, true), do: sessions

  defp maybe_filter_useful(sessions, _raw?) do
    Enum.filter(sessions, fn session -> session[:live?] or useful?(session) end)
  end

  defp useful?(session) do
    message_count = session[:message_count] || 0
    preview = session[:first_message] || session[:last_message_preview] || ""
    message_count > 0 and preview != "" and not internal_id?(session[:id])
  end

  defp failed?(session) do
    preview = session[:last_message_preview] || ""

    String.contains?(preview, [
      "ERROR",
      "failed",
      "http_streaming_failed",
      "provider_build_failed"
    ])
  end

  defp internal_id?(id) when is_binary(id) do
    String.starts_with?(id, [
      "plugin-",
      "selector-",
      "attach-",
      "durable-",
      "restore-",
      "ui-session",
      "loader-",
      "background-"
    ])
  end

  defp internal_id?(_id), do: false

  defp prune_empty do
    pruned =
      Exy.Session.Store.list()
      |> Enum.filter(fn session ->
        not session[:live?] and (session[:message_count] || 0) == 0
      end)
      |> Enum.map(fn session ->
        :ok = File.rm(session.path)
        session.id
      end)

    {:ok, %{pruned: length(pruned), sessions: pruned}}
  end
end
