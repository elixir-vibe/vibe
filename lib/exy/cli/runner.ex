defmodule Exy.CLI.Runner do
  @moduledoc false

  alias Exy.CLI.{Logging, Output}

  require Exy.Debug

  @spec ask(String.t(), keyword()) :: :ok | {:error, term()}
  def ask("", _opts) do
    Output.error("No prompt provided. Run `mix exy --help` for usage.")
    {:error, :missing_prompt}
  end

  def ask(prompt, opts) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()
    session_id = session_id(opts)

    result =
      Logging.with_session_log(session_id, fn ->
        if opts[:direct] do
          llm_opts = Keyword.put(model_opts(opts), :session_id, session_id)

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

  @spec tui(keyword(), keyword()) :: :ok | {:error, term()}
  def tui(opts, runtime_extra \\ []) do
    configure_api_key(opts)
    Exy.Application.configure_dependency_logging()

    runtime_opts =
      [session_id: session_id(opts), model: Exy.Model.Config.resolve(opts)]
      |> maybe_put(:trace_dir, trace_dir(opts))
      |> maybe_put(:remote_node, opts[:remote_node])
      |> Keyword.merge(runtime_extra)
      |> maybe_put_system_prompt(opts[:system_prompt])

    case Logging.with_session_log(runtime_opts[:session_id], fn ->
           Exy.TUI.Runtime.run(runtime_opts)
         end) do
      :ok ->
        :ok

      {:error, reason} ->
        Output.error("Cannot start Exy TUI: #{reason}")
        {:error, reason}
    end
  end

  @spec configure_api_key(keyword()) :: :ok
  def configure_api_key(opts) do
    if key = opts[:api_key] do
      ReqLLM.put_key(:openai_api_key, key)
    end

    if Exy.Model.Config.resolve(opts) |> String.starts_with?("openai_codex:") do
      Exy.Auth.Codex.ensure_fresh()
    end

    :ok
  end

  @spec session_id(keyword()) :: String.t()
  def session_id(opts), do: opts[:session] || Exy.Session.Store.new_id()

  if Exy.Debug.enabled?() do
    defp trace_dir(opts), do: opts[:trace_tui] || System.get_env("EXY_TUI_TRACE_DIR")
  else
    defp trace_dir(_opts), do: nil
  end

  defp maybe_put_system_prompt(opts, nil), do: opts
  defp maybe_put_system_prompt(opts, system_prompt), do: Keyword.put(opts, :system, system_prompt)

  defp agent_opts(opts), do: [] |> maybe_put(:model, opts[:model])

  defp model_opts(opts) do
    []
    |> maybe_put(:model, opts[:model])
    |> maybe_put(:system, opts[:system_prompt])
  end

  defp stream?(opts), do: opts[:no_stream] != true and opts[:stream] != false

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
