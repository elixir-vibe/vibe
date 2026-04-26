defmodule Exy.CLI do
  @moduledoc false

  alias Exy.CLI.Output

  @version Mix.Project.config()[:version]

  @switches [
    help: :boolean,
    version: :boolean,
    model: :string,
    api_key: :string,
    system_prompt: :string,
    mode: :string,
    print: :boolean,
    login: :string,
    eval: :string,
    compact: :boolean,
    keep_recent: :integer,
    checks: :boolean,
    codex_usage: :boolean,
    timeout: :integer,
    session: :string,
    sessions: :boolean,
    direct: :boolean,
    stream: :boolean,
    no_stream: :boolean,
    foreground: :boolean,
    all: :boolean,
    live: :boolean,
    failed: :boolean,
    limit: :integer
  ]

  @aliases [h: :help, v: :version, p: :print]

  def main(argv) do
    {opts, args, invalid} = parse(argv)

    cond do
      invalid == [] and match?(["server" | _], args) ->
        server_command(tl(args), opts)

      invalid == [] and match?([command | _] when command in ["new", "n"], args) ->
        if opts[:print] == true or opts[:mode] == "json",
          do: new_session(opts),
          else: new_session_tui(opts)

      invalid == [] and match?([command | _] when command in ["sessions", "ls"], args) ->
        [_command | rest] = args
        sessions_command(rest, opts)

      invalid == [] and match?(["send", _session_id | _], args) ->
        ["send", session_id | prompt_parts] = args

        Output.print(
          server_call(fn ->
            Exy.Remote.Session.send_prompt(session_id, Enum.join(prompt_parts, " "))
          end),
          opts
        )

      invalid == [] and match?([command] when command in ["attach", "a"], args) ->
        attach_default_session(opts)

      invalid == [] and match?([command, _session_id] when command in ["attach", "a"], args) ->
        [_command, session_id] = args
        attach_session(session_id, opts)

      true ->
        main_options(opts, args, invalid)
    end
  end

  defp main_options(opts, args, invalid) do
    cond do
      invalid != [] ->
        Enum.each(invalid, fn {flag, _} -> Output.error("Unknown option: #{flag}") end)
        {:error, :invalid_args}

      opts[:help] ->
        Mix.Tasks.Help.run(["exy"])
        :ok

      opts[:version] ->
        IO.puts(@version)
        :ok

      opts[:login] ->
        login(opts[:login])

      code = opts[:eval] ->
        Output.print(Exy.Eval.run(code, timeout: opts[:timeout] || 30_000), opts)

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        Output.print(Exy.Code.Checks.run_all(), opts)

      opts[:codex_usage] ->
        Output.print(Exy.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        Output.print({:ok, Exy.Session.Store.list()}, opts)

      opts[:print] == true or args != [] ->
        prompt = Enum.join(args, " ")
        ask(prompt, opts)

      true ->
        attach_default_session(opts)
    end
  end

  defp server_command(["start"], opts), do: server_command(["start", "--auto"], opts)

  defp server_command(["start", _mode], opts) do
    if opts[:foreground] do
      Exy.Server.start(foreground: true)
    else
      Output.print(start_background_server(), opts)
    end
  end

  defp server_command(["status"], opts), do: Output.print(Exy.Server.status(), opts)
  defp server_command(["stop"], opts), do: Output.print(Exy.Server.stop(), opts)

  defp server_command(_args, _opts) do
    Output.error("Usage: exy server start [--foreground] | status | stop")
    {:error, :invalid_server_command}
  end

  defp sessions_command(["prune", "--empty"], opts) do
    Output.print(prune_empty_sessions(), opts)
  end

  defp sessions_command(["prune"], _opts) do
    Output.error("Usage: exy sessions prune --empty")
    {:error, :invalid_sessions_command}
  end

  defp sessions_command([], opts) do
    case server_call(&Exy.Remote.Session.list/0) do
      {:ok, sessions} -> Output.print({:ok, filter_sessions(sessions, opts)}, opts)
      error -> Output.print(error, opts)
    end
  end

  defp sessions_command(_args, _opts) do
    Output.error("Usage: exy sessions [--all] [--live] [--failed] [--limit n] | prune --empty")

    {:error, :invalid_sessions_command}
  end

  defp new_session_tui(opts) do
    case server_call(fn -> Exy.Remote.Session.start(model: Exy.Model.Config.resolve(opts)) end) do
      {:ok, %{id: session_id}} -> attach_session(session_id, opts)
      other -> Output.print(other, opts)
    end
  end

  defp new_session(opts) do
    Output.print(
      server_call(fn -> Exy.Remote.Session.start(model: Exy.Model.Config.resolve(opts)) end),
      opts
    )
  end

  defp attach_default_session(opts) do
    configure_api_key(opts)

    case Exy.Remote.connect() do
      {:ok, node} ->
        session_id =
          opts[:session] || latest_live_remote_session_id() || new_remote_session_id(opts)

        attach_session(session_id, Keyword.put(opts, :remote_node, node))

      {:error, _reason} ->
        launch_background_server()
        tui(opts)
    end
  end

  defp attach_session(session_id, opts) do
    case server_call(fn -> Exy.Remote.Session.lookup(session_id) end) do
      {:ok, session} ->
        opts = Keyword.put_new(opts, :remote_node, session_node(session))
        tui(opts, session_server: session, session_id: session_id)

      {:error, reason} ->
        Output.print({:error, reason}, opts)
    end
  end

  defp session_node(session) when is_pid(session) do
    node = node(session)
    if node == Node.self(), do: nil, else: node
  end

  defp session_node(_session), do: nil

  defp ensure_server_running(timeout_ms \\ 20_000) do
    case Exy.Remote.connect() do
      {:ok, _node} -> :ok
      {:error, _reason} -> start_background_server(timeout_ms)
    end
  end

  defp filter_sessions(sessions, opts) do
    sessions
    |> maybe_filter_live(opts[:live])
    |> maybe_filter_failed(opts[:failed])
    |> maybe_filter_useful(opts[:all] || opts[:live] || opts[:failed])
    |> Enum.take(opts[:limit] || if(opts[:all], do: length(sessions), else: 20))
  end

  defp maybe_filter_live(sessions, true), do: Enum.filter(sessions, & &1[:live?])
  defp maybe_filter_live(sessions, _live?), do: sessions

  defp maybe_filter_failed(sessions, true), do: Enum.filter(sessions, &failed_session?/1)
  defp maybe_filter_failed(sessions, _failed?), do: sessions

  defp maybe_filter_useful(sessions, true), do: sessions

  defp maybe_filter_useful(sessions, _raw?) do
    Enum.filter(sessions, fn session ->
      session[:live?] or useful_session?(session)
    end)
  end

  defp useful_session?(session) do
    message_count = session[:message_count] || 0
    preview = session[:first_message] || session[:last_message_preview] || ""

    message_count > 0 and preview != "" and not internal_session_id?(session[:id])
  end

  defp failed_session?(session) do
    preview = session[:last_message_preview] || ""

    String.contains?(preview, [
      "ERROR",
      "failed",
      "http_streaming_failed",
      "provider_build_failed"
    ])
  end

  defp internal_session_id?(id) when is_binary(id) do
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

  defp internal_session_id?(_id), do: false

  defp prune_empty_sessions do
    sessions = Exy.Session.Store.list()

    pruned =
      sessions
      |> Enum.filter(fn session ->
        not session[:live?] and (session[:message_count] || 0) == 0
      end)
      |> Enum.map(fn session ->
        :ok = File.rm(session.path)
        session.id
      end)

    {:ok, %{pruned: length(pruned), sessions: pruned}}
  end

  defp latest_live_remote_session_id do
    case server_call(&Exy.Remote.Session.list/0) do
      {:ok, sessions} -> sessions |> Enum.find(& &1[:live?]) |> then(&(&1 && &1.id))
      {:error, _reason} -> nil
    end
  end

  defp new_remote_session_id(opts) do
    case server_call(fn -> Exy.Remote.Session.start(model: Exy.Model.Config.resolve(opts)) end) do
      {:ok, %{id: id}} -> id
      {:error, reason} -> raise "cannot create Exy session: #{inspect(reason)}"
    end
  end

  defp server_call(fun) do
    case ensure_server_running() do
      :ok -> fun.()
      {:error, reason} -> {:error, {:server_not_running, reason}}
    end
  end

  defp start_background_server(timeout_ms \\ 20_000) do
    launch_background_server()

    case wait_for_server(timeout_ms) do
      :ok ->
        :ok

      {:error, reason} ->
        Exy.Server.cleanup_metadata()
        {:error, reason}
    end
  end

  defp launch_background_server do
    log_path = Exy.Paths.server_log()
    File.mkdir_p!(Path.dirname(log_path))

    command = "exec #{background_server_command()} > #{shell_quote(log_path)} 2>&1 < /dev/null"

    :erlang.open_port({:spawn_executable, "/bin/sh"}, [
      :binary,
      :nouse_stdio,
      {:args, ["-c", command]}
    ])

    :ok
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end

  defp background_server_command do
    case :escript.script_name() do
      path when is_list(path) and path != [] ->
        path = path |> List.to_string() |> Path.expand()

        if Path.basename(path) in ["mix", "mix.bat"] do
          "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && #{shell_quote(path)} exy server start --foreground")}"
        else
          "#{shell_quote(path)} server start --foreground"
        end

      _other ->
        installed_exy_command()
    end
  rescue
    _error -> installed_exy_command()
  end

  defp installed_exy_command do
    case System.find_executable("exy") do
      nil ->
        "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && mix exy server start --foreground")}"

      path ->
        "#{shell_quote(path)} server start --foreground"
    end
  end

  defp wait_for_server(timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_server_until(deadline)
  end

  defp wait_for_server_until(deadline) do
    case Exy.Remote.connect() do
      {:ok, _node} ->
        :ok

      {:error, reason} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, reason}
        else
          Process.sleep(100)
          wait_for_server_until(deadline)
        end
    end
  end

  @doc false
  def parse(argv) do
    OptionParser.parse(argv, strict: @switches, aliases: @aliases)
  end

  defp login(provider), do: Exy.Auth.login(provider)

  defp compact(opts) do
    opts =
      opts
      |> maybe_put(:keep_recent, opts[:keep_recent])
      |> maybe_put(:model, opts[:model])

    Output.print(Exy.Context.compact(opts), opts)
  end

  defp ask("", _opts) do
    Output.error("No prompt provided. Run `mix exy --help` for usage.")
    {:error, :missing_prompt}
  end

  defp ask(prompt, opts) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()
    session_id = session_id(opts)

    result =
      with_console_logs_suppressed(session_id, fn ->
        if opts[:direct] do
          llm_opts = Keyword.put(llm_opts(opts), :session_id, session_id)

          if stream?(opts) do
            Exy.Model.Direct.stream(prompt, llm_opts)
          else
            Exy.Model.Direct.ask(prompt, llm_opts)
          end
        else
          with {:ok, pid} <- Exy.start_link(agent_opts(opts)) do
            Exy.ask(pid, prompt, timeout: opts[:timeout] || 120_000, session_id: session_id)
          end
        end
      end)

    Output.print(result, opts)
  end

  defp tui(opts, runtime_extra \\ []) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()

    runtime_opts =
      [session_id: session_id(opts), model: Exy.Model.Config.resolve(opts)]
      |> maybe_put(:remote_node, opts[:remote_node])
      |> Keyword.merge(runtime_extra)
      |> maybe_put_system_prompt(opts[:system_prompt])

    case with_console_logs_suppressed(runtime_opts[:session_id], fn ->
           Exy.TUI.Runtime.run(runtime_opts)
         end) do
      :ok ->
        :ok

      {:error, reason} ->
        Output.error("Cannot start Exy TUI: #{reason}")
        {:error, reason}
    end
  end

  defp maybe_put_system_prompt(opts, nil), do: opts
  defp maybe_put_system_prompt(opts, system_prompt), do: Keyword.put(opts, :system, system_prompt)

  defp configure_api_key(opts) do
    if key = opts[:api_key] do
      ReqLLM.put_key(:openai_api_key, key)
    end

    if Exy.Model.Config.resolve(opts) |> String.starts_with?("openai_codex:") do
      Exy.Auth.Codex.ensure_fresh()
    end

    :ok
  end

  defp agent_opts(opts) do
    []
    |> maybe_put(:model, opts[:model])
  end

  defp llm_opts(opts) do
    []
    |> maybe_put(:model, opts[:model])
    |> maybe_put(:system, opts[:system_prompt])
  end

  defp session_id(opts), do: opts[:session] || Exy.Session.Store.new_id()

  defp stream?(opts), do: opts[:no_stream] != true and opts[:stream] != false

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp with_console_logs_suppressed(session_id, fun) do
    handlers = console_handlers()
    log_handler = attach_session_log(session_id)

    Enum.each(handlers, fn {handler, _level} ->
      :logger.set_handler_config(handler, :level, :emergency)
    end)

    try do
      fun.()
    after
      Enum.each(handlers, fn {handler, level} ->
        :logger.set_handler_config(handler, :level, level)
      end)

      detach_session_log(log_handler)
    end
  end

  defp attach_session_log(nil), do: nil

  defp attach_session_log(session_id) do
    path = Exy.Session.Store.log_path(session_id)
    File.mkdir_p!(Path.dirname(path))
    _ = :logger.remove_handler(:exy_session_log)

    case :logger.add_handler(:exy_session_log, :logger_std_h, %{
           level: :debug,
           config: %{type: {:file, String.to_charlist(path)}}
         }) do
      :ok -> :exy_session_log
      {:error, _reason} -> nil
    end
  end

  defp detach_session_log(nil), do: :ok
  defp detach_session_log(handler), do: :logger.remove_handler(handler)

  defp console_handlers do
    :logger.get_handler_ids()
    |> Enum.flat_map(fn handler ->
      case :logger.get_handler_config(handler) do
        {:ok, %{module: :logger_std_h, config: %{type: type}, level: level}}
        when type in [:standard_io, :standard_error] ->
          [{handler, level}]

        _ ->
          []
      end
    end)
  end
end
