defmodule Exy.CLI.Runner do
  @moduledoc "Internal implementation module."
  alias Exy.CLI.{Logging, Output}

  require Exy.Debug

  @default_print_timeout_ms 120_000

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

          case direct_prompt(prompt, opts) do
            {:error, reason} ->
              {:error, reason}

            prompt ->
              if stream?(opts) do
                Exy.Model.Direct.stream(prompt, llm_opts)
              else
                direct_ask_fun(opts).(prompt, llm_opts)
              end
          end
        else
          case agent_prompt(prompt, opts) do
            {:error, reason} ->
              {:error, reason}

            prompt ->
              with {:ok, pid} <- Exy.start_link(agent_opts(opts)) do
                Exy.ask(pid, prompt,
                  timeout: opts[:timeout] || @default_print_timeout_ms,
                  session_id: session_id,
                  on_result: trace_print_delta(:content),
                  on_thinking: trace_print_delta(:thinking)
                )
              end
          end
        end
      end)

    Output.print(result, opts)
  end

  defp direct_ask_fun(opts), do: Keyword.get(opts, :direct_ask_fun, &Exy.Model.Direct.ask/2)

  defp direct_prompt(prompt, opts) do
    case resolve_file_args(opts) do
      {:ok, []} -> Exy.Prompt.Attachments.expand(prompt, root: File.cwd!())
      {:ok, file_args} -> build_or_expand(prompt, file_args)
      {:error, reason} -> {:error, reason}
    end
  end

  defp agent_prompt(prompt, opts) do
    case resolve_file_args(opts) do
      {:ok, []} -> prompt
      {:ok, file_args} -> build_text_prompt(prompt, file_args)
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_file_args(opts) do
    file_args = Keyword.get(opts, :file_args, [])

    if file_args == [] do
      {:ok, []}
    else
      case Exy.Prompt.Attachments.process_file_args(file_args, root: File.cwd!()) do
        {:ok, _processed} -> {:ok, file_args}
        {:error, reason} -> {:error, format_file_error(reason)}
      end
    end
  end

  defp build_or_expand(prompt, file_args) do
    case Exy.Prompt.Attachments.build_initial(prompt, file_args, root: File.cwd!()) do
      {:ok, content} -> content
      {:error, reason} -> {:error, format_file_error(reason)}
    end
  end

  defp build_text_prompt(prompt, file_args) do
    case Exy.Prompt.Attachments.process_file_args(file_args, root: File.cwd!()) do
      {:ok, %{text: file_text}} -> file_text <> prompt
      {:error, reason} -> {:error, format_file_error(reason)}
    end
  end

  defp format_file_error({:file_not_found, path}), do: "File not found: #{path}"
  defp format_file_error({reason, path}) when is_atom(reason), do: "#{reason}: #{path}"
  defp format_file_error(reason), do: inspect(reason)

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

    model = Exy.Model.Config.resolve(opts)

    cond do
      String.starts_with?(model, "openai_codex:") -> Exy.Auth.Codex.ensure_fresh()
      String.starts_with?(model, "opencode") -> Exy.Auth.OpenCode.ensure_fresh()
      true -> :ok
    end

    :ok
  end

  if Exy.Debug.enabled?() do
    defp trace_print_delta(type) do
      fn text ->
        Exy.Agent.Streaming.Trace.record(:print_delta, %{chunk_type: type, text: text})
      end
    end
  else
    defp trace_print_delta(_type), do: fn _text -> :ok end
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
