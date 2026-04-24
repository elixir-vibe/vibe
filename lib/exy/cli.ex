defmodule Exy.CLI do
  @moduledoc false

  @version Mix.Project.config()[:version]

  def main(argv) do
    {opts, args, invalid} = parse(argv)

    cond do
      invalid != [] ->
        Enum.each(invalid, fn {flag, _} -> Mix.shell().error("Unknown option: #{flag}") end)
        {:error, :invalid_args}

      opts[:help] ->
        IO.puts(help())
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

      opts[:print] or args != [] ->
        prompt = Enum.join(args, " ")
        ask(prompt, opts)

      true ->
        repl(opts)
    end
  end

  defp parse(argv) do
    OptionParser.parse(argv,
      strict: [
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
        no_agent: :boolean
      ],
      aliases: [h: :help, v: :version, p: :print]
    )
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
    Mix.shell().error("No prompt provided. Run `mix exy --help` for usage.")
    {:error, :missing_prompt}
  end

  defp ask(prompt, opts) do
    configure_api_key(opts)

    result =
      if opts[:no_agent] do
        Exy.LLM.ask(prompt, llm_opts(opts))
      else
        with {:ok, pid} <- Exy.start_link(agent_opts(opts)) do
          Exy.ask(pid, prompt, timeout: opts[:timeout] || 120_000)
        end
      end

    print_result(result, opts)
  end

  defp repl(opts) do
    configure_api_key(opts)
    {:ok, pid} = Exy.start_link(agent_opts(opts))
    IO.puts("Exy #{@version}. Type /quit to exit, /help for commands.\n")
    loop(pid, opts)
  end

  defp loop(pid, opts) do
    case IO.gets("exy> ") do
      nil ->
        :ok

      line ->
        line = String.trim(line)

        case line do
          "" ->
            loop(pid, opts)

          "/quit" ->
            :ok

          "/exit" ->
            :ok

          "/help" ->
            IO.puts(repl_help())
            loop(pid, opts)

          prompt ->
            print_result(Exy.ask(pid, prompt, timeout: opts[:timeout] || 120_000), opts)
            loop(pid, opts)
        end
    end
  end

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
      _ -> Mix.shell().error(inspect(reason))
    end

    {:error, reason}
  end

  defp render_result(results) when is_list(results),
    do: Enum.map_join(results, "\n", &inspect(&1, pretty: true, limit: 20))

  defp render_result(%{summary: summary}), do: summary
  defp render_result(%{output: output}), do: output
  defp render_result(result) when is_binary(result), do: result
  defp render_result(result), do: inspect(result, pretty: true, limit: 50)

  defp configure_api_key(opts) do
    if key = opts[:api_key] do
      ReqLLM.put_key(:openai_api_key, key)
    end
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

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp repl_help do
    """
    /help   Show this help
    /quit   Exit
    /exit   Exit
    """
  end

  defp help do
    """
    exy - BEAM-native Elixir coding agent

    Usage:
      mix exy [options] [message...]

    Options:
      --model <provider:model>       ReqLLM/Jido model (default: EXY_MODEL or openai:gpt-4o-mini)
      --api-key <key>                API key for OpenAI-compatible requests
      --system-prompt <text>         Override system prompt for --no-agent direct ReqLLM calls
      --mode <text|json>             Output mode (default: text)
      --print, -p                    Non-interactive mode: process prompt and exit
      --no-agent                     Use direct ReqLLM call instead of Jido.AI agent
      --eval <code>                  Evaluate Elixir code through Exy.Eval
      --compact                      Compact stored trajectory context
      --keep-recent <n>              Events to keep when compacting (default: 12)
      --checks                       Run Exy validation gates
      --codex-usage                  Show Codex subscription usage via Codex app-server RPC
      --timeout <ms>                 Request/eval timeout
      --login codex                  Sign in with ChatGPT/Codex OAuth
      --help, -h                     Show help
      --version, -v                  Show version

    Examples:
      mix exy
      mix exy -p "Inspect runtime info with elixir_eval"
      mix exy --model anthropic:claude-sonnet-4-5-20250929 "Review this project"
      mix exy --login codex
      mix exy --compact --keep-recent 20
      mix exy --eval "Exy.OTP.runtime_info()"
    """
  end
end
