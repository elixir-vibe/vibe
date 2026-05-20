defmodule Vibe.CLI.Commands.Default do
  @moduledoc "Default CLI entrypoint: prompt, TUI, eval, and flag dispatch."
  alias Vibe.CLI.{Output, Runner, Server, Sessions}

  @version Mix.Project.config()[:version]
  @default_eval_timeout_ms 30_000

  @spec run([String.t()], keyword()) :: :ok | {:error, term()}
  def run(args, opts) do
    cond do
      opts[:help] ->
        Mix.Tasks.Help.run(["vibe"])
        :ok

      opts[:version] ->
        IO.puts(@version)
        :ok

      opts[:login] ->
        Vibe.Auth.login(opts[:login])

      opts[:web] ->
        web(opts)

      code = opts[:eval] ->
        Output.print(
          Vibe.Eval.once(code, timeout: opts[:timeout] || @default_eval_timeout_ms),
          opts
        )

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        Output.print(Vibe.Code.Checks.run_all(), opts)

      opts[:codex_usage] ->
        Output.print(Vibe.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        Output.print({:ok, Vibe.Session.Store.list()}, opts)

      opts[:bg] == true and args != [] ->
        prompt = Enum.join(args, " ")
        background(prompt, opts)

      opts[:print] == true or args != [] ->
        {file_args, message_args} = split_file_args(args)

        opts = Keyword.put(opts, :file_args, file_args)

        message_args
        |> Enum.join(" ")
        |> Runner.ask(opts)

      true ->
        Sessions.attach_default(opts)
    end
  end

  defp split_file_args(args) do
    {files, messages} = Enum.split_with(args, &String.starts_with?(&1, "@"))
    {Enum.map(files, &String.replace_prefix(&1, "@", "")), messages}
  end

  defp web(opts) do
    _ = Server.ensure_running(20_000, opts)
    url = Vibe.Web.Auth.authenticated_url(port: opts[:port] || 4321)
    IO.puts(url)

    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, _linux} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
    end

    :ok
  rescue
    _error -> :ok
  end

  defp compact(opts) do
    opts =
      opts
      |> maybe_put(:keep_recent, opts[:keep_recent])
      |> maybe_put(:model, opts[:model])

    Output.print(Vibe.Context.compact(opts), opts)
  end

  defp background(prompt, opts) do
    Runner.configure_api_key(opts)
    Vibe.Application.configure_dependency_logging()

    session_id = Vibe.Session.Store.new_id()
    model = Vibe.Model.Config.resolve(opts)

    case Vibe.Session.start(session_id: session_id, cwd: File.cwd!(), model: model) do
      {:ok, session} ->
        Vibe.Session.dispatch(session, {:submit_prompt, %{text: prompt}})
        IO.puts("backgrounded · #{session_id}")
        IO.puts("  mix vibe sessions          list sessions")
        IO.puts("  mix vibe attach #{session_id}   attach")
        :ok

      {:error, reason} ->
        Output.error("Failed to start background session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
