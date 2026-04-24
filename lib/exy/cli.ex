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
    no_stream: :boolean
  ]

  @aliases [h: :help, v: :version, p: :print]

  def main(argv) do
    {opts, args, invalid} = parse(argv)

    cond do
      invalid != [] ->
        Enum.each(invalid, fn {flag, _} -> Mix.shell().error("Unknown option: #{flag}") end)
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
        print_result({:ok, Exy.Session.list()}, opts)

      opts[:print] == true or args != [] ->
        prompt = Enum.join(args, " ")
        ask(prompt, opts)

      true ->
        tui(opts)
    end
  end

  defp parse(argv) do
    OptionParser.parse(argv, strict: @switches, aliases: @aliases)
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
    session_id = session_id(opts)

    result =
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

    print_result(result, opts)
  end

  defp tui(opts) do
    configure_api_key(opts)

    case Exy.TUI.Runtime.run(
           session_id: session_id(opts),
           model: Exy.LLM.Model.resolve(opts),
           system: opts[:system_prompt]
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Cannot start Exy TUI: #{reason}")
        {:error, reason}
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

  defp session_id(opts), do: opts[:session] || Exy.Session.new_id()

  defp stream?(opts), do: not opts[:no_stream] and opts[:stream] != false

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
end
