defmodule Vibe.CLI.Commands.Default do
  @moduledoc "Default CLI entrypoint: prompt, TUI, eval, and flag dispatch."
  alias Vibe.CLI.{Output, Runner, Server, Sessions}
  alias Vibe.CLI.Commands.Default.Dispatch

  @version Mix.Project.config()[:version]

  @spec run([String.t()], keyword()) :: :ok | {:error, term()}
  def run(args, opts) do
    args
    |> Dispatch.action(opts)
    |> execute(opts)
  end

  defp execute({:help}, _opts) do
    Mix.Tasks.Help.run(["vibe"])
    :ok
  end

  defp execute({:version}, _opts) do
    IO.puts(@version)
    :ok
  end

  defp execute({:login, provider}, _opts), do: Vibe.Auth.login(provider)
  defp execute({:web}, opts), do: web(opts)

  defp execute({:eval, code, timeout}, opts) do
    Output.print(Vibe.Eval.once(code, timeout: timeout), opts)
  end

  defp execute({:compact}, opts), do: compact(opts)
  defp execute({:checks}, opts), do: Output.print(Vibe.Code.Checks.run_all(), opts)

  defp execute({:codex_usage}, opts),
    do: Output.print(Vibe.Subscription.usage("openai-codex"), opts)

  defp execute({:sessions}, opts), do: Output.print({:ok, Vibe.Session.Store.list()}, opts)

  defp execute({:background, prompt}, opts), do: background(prompt, opts)

  defp execute({:ask, {file_args, message_args}}, opts) do
    opts = Keyword.put(opts, :file_args, file_args)

    message_args
    |> Enum.join(" ")
    |> Runner.ask(opts)
  end

  defp execute({:attach_default}, opts), do: Sessions.attach_default(opts)

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

    prompt
    |> start_background_session(background_session_opts(opts))
    |> print_background_result()
  end

  defp background_session_opts(opts) do
    [
      session_id: Vibe.Session.Store.new_id(),
      cwd: File.cwd!(),
      model: Vibe.Model.Selection.resolve(opts)
    ]
  end

  defp start_background_session(prompt, session_opts) do
    session_id = Keyword.fetch!(session_opts, :session_id)

    case Vibe.Session.start(session_opts) do
      {:ok, session} ->
        Vibe.Session.dispatch(session, {:submit_prompt, %{text: prompt}})
        {:ok, session_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp print_background_result({:ok, session_id}) do
    IO.puts("backgrounded · #{session_id}")
    IO.puts("  mix vibe sessions          list sessions")
    IO.puts("  mix vibe attach #{session_id}   attach")
    :ok
  end

  defp print_background_result({:error, reason}) do
    Output.error("Failed to start background session: #{inspect(reason)}")
    {:error, reason}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
