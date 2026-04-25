defmodule Exy.CLI do
  @moduledoc false

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
    no_agent: :boolean,
    stream: :boolean,
    no_stream: :boolean,
    foreground: :boolean
  ]

  @aliases [h: :help, v: :version, p: :print]

  def main(argv) do
    {opts, args, invalid} = parse(argv)

    cond do
      invalid == [] and match?(["server" | _], args) ->
        server_command(tl(args), opts)

      invalid == [] and match?(["new" | _], args) ->
        new_session(opts)

      invalid == [] and match?(["sessions" | _], args) ->
        print_result(remote_or_local(:sessions, []), opts)

      invalid == [] and match?(["send", _session_id | _], args) ->
        ["send", session_id | prompt_parts] = args

        print_result(
          remote_or_local(:send_prompt, [session_id, Enum.join(prompt_parts, " ")]),
          opts
        )

      invalid == [] and match?(["attach", _session_id], args) ->
        ["attach", session_id] = args
        attach_session(session_id, opts)

      true ->
        main_options(opts, args, invalid)
    end
  end

  defp main_options(opts, args, invalid) do
    cond do
      invalid != [] ->
        Enum.each(invalid, fn {flag, _} -> shell_error("Unknown option: #{flag}") end)
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
        print_result(Exy.Eval.run(code, timeout: opts[:timeout] || 30_000), opts)

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        print_result(Exy.Checks.run_all(), opts)

      opts[:codex_usage] ->
        print_result(Exy.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        print_result({:ok, Exy.Session.Store.list()}, opts)

      opts[:print] == true or args != [] ->
        prompt = Enum.join(args, " ")
        ask(prompt, opts)

      true ->
        tui(opts)
    end
  end

  defp server_command(["start"], opts), do: server_command(["start", "--auto"], opts)

  defp server_command(["start", _mode], opts) do
    if opts[:foreground] do
      Exy.Server.start(foreground: true)
    else
      start_background_server()
    end
  end

  defp server_command(["status"], opts), do: print_result(Exy.Server.status(), opts)
  defp server_command(["stop"], opts), do: print_result(Exy.Server.stop(), opts)

  defp server_command(_args, _opts) do
    shell_error("Usage: exy server start [--foreground] | status | stop")
    {:error, :invalid_server_command}
  end

  defp new_session(opts) do
    print_result(remote_or_local(:new_session, [[model: Exy.LLM.Model.resolve(opts)]]), opts)
  end

  defp attach_session(session_id, opts) do
    case remote_or_local(:session_pid, [session_id]) do
      {:ok, session} ->
        tui(opts, session_server: session, session_id: session_id)

      {:error, reason} ->
        print_result({:error, reason}, opts)
    end
  end

  defp remote_or_local(function, args) do
    case Exy.Remote.connect() do
      {:ok, node} -> :rpc.call(node, Exy.Server.RPC, function, args)
      {:error, _reason} -> apply(Exy.Server.RPC, function, args)
    end
  end

  defp start_background_server do
    executable = System.find_executable("exy") || List.first(System.argv())

    Port.open({:spawn_executable, executable}, [
      :binary,
      :exit_status,
      :hide,
      args: ["server", "start", "--foreground"]
    ])

    :ok
  end

  @doc false
  def parse(argv) do
    OptionParser.parse(argv, strict: @switches, aliases: @aliases)
  end

  defp shell_error(message) do
    if Code.ensure_loaded?(Mix) and function_exported?(Mix, :shell, 0) do
      Mix.shell().error(message)
    else
      IO.puts(:stderr, message)
    end
  end

  defp login(provider), do: Exy.Auth.login(provider)

  defp compact(opts) do
    opts =
      opts
      |> maybe_put(:keep_recent, opts[:keep_recent])
      |> maybe_put(:model, opts[:model])

    print_result(Exy.Context.compact(opts), opts)
  end

  defp ask("", _opts) do
    shell_error("No prompt provided. Run `mix exy --help` for usage.")
    {:error, :missing_prompt}
  end

  defp ask(prompt, opts) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()
    session_id = session_id(opts)

    result =
      with_console_logs_suppressed(session_id, fn ->
        if opts[:no_agent] do
          llm_opts = Keyword.put(llm_opts(opts), :session_id, session_id)

          if stream?(opts) do
            Exy.LLM.stream(prompt, llm_opts)
          else
            Exy.LLM.ask(prompt, llm_opts)
          end
        else
          with {:ok, pid} <- Exy.start_link(agent_opts(opts)) do
            Exy.ask(pid, prompt, timeout: opts[:timeout] || 120_000, session_id: session_id)
          end
        end
      end)

    print_result(result, opts)
  end

  defp tui(opts, runtime_extra \\ []) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()

    runtime_opts =
      [session_id: session_id(opts), model: Exy.LLM.Model.resolve(opts)]
      |> Keyword.merge(runtime_extra)
      |> maybe_put_system_prompt(opts[:system_prompt])

    case with_console_logs_suppressed(runtime_opts[:session_id], fn ->
           Exy.TUI.Runtime.run(runtime_opts)
         end) do
      :ok ->
        :ok

      {:error, reason} ->
        shell_error("Cannot start Exy TUI: #{reason}")
        {:error, reason}
    end
  end

  defp maybe_put_system_prompt(opts, nil), do: opts
  defp maybe_put_system_prompt(opts, system_prompt), do: Keyword.put(opts, :system, system_prompt)

  defp print_result({:ok, results}, opts) when is_list(results) do
    case opts[:mode] do
      "json" -> IO.puts(Jason.encode!(%{ok: true, results: results}, pretty: true))
      _ -> IO.puts(render_result(results))
    end

    :ok
  end

  defp print_result({:ok, result}, opts) do
    case opts[:mode] do
      "json" -> IO.puts(Jason.encode!(%{ok: true, result: result}, pretty: true))
      _ -> IO.puts(render_result(result))
    end

    :ok
  end

  defp print_result({:error, reason}, opts) do
    case opts[:mode] do
      "json" -> IO.puts(Jason.encode!(%{ok: false, error: inspect(reason)}, pretty: true))
      _ -> shell_error(inspect(reason))
    end

    {:error, reason}
  end

  defp render_result(results) when is_list(results),
    do: Enum.map_join(results, "\n", &inspect(&1, pretty: true, limit: 20))

  defp render_result(%ReqLLM.Response{} = response),
    do: response |> ReqLLM.Response.text() |> render_markdown()

  defp render_result(%{summary: summary}), do: render_markdown(summary)
  defp render_result(%{output: output}), do: output
  defp render_result(result) when is_binary(result), do: render_markdown(result)
  defp render_result(result), do: inspect(result, pretty: true, limit: 50)

  defp configure_api_key(opts) do
    if key = opts[:api_key] do
      ReqLLM.put_key(:openai_api_key, key)
    end

    if Exy.LLM.Model.resolve(opts) |> String.starts_with?("openai_codex:") do
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

  defp render_markdown(nil), do: ""

  defp render_markdown(text) do
    text
    |> Exy.TUI.Markdown.render(terminal_width(), Exy.TUI.Theme.default())
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
  end

  defp terminal_width do
    case :io.columns() do
      {:ok, columns} -> columns
      _ -> 100
    end
  end

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
