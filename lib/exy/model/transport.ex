defmodule Exy.Model.Transport do
  @moduledoc """
  Applies provider transport policy to model request options.

  Agent-facing APIs pass semantic model requests. This module is the internal
  boundary that turns Exy/profile transport policy into ReqLLM provider options
  such as reusable Responses WebSocket session pids.
  """

  @spec prepare_stream_opts(term(), keyword(), String.t()) :: {:ok, keyword()} | {:error, term()}
  def prepare_stream_opts(model, request_opts, session_id)
      when is_list(request_opts) and is_binary(session_id) do
    provider_opts = Keyword.get(request_opts, :provider_options, [])

    if reusable_responses_websocket?(provider_opts) do
      put_reusable_responses_websocket(model, request_opts, provider_opts, session_id)
    else
      {:ok, request_opts}
    end
  end

  defp reusable_responses_websocket?(provider_opts) do
    Keyword.get(provider_opts, :openai_reuse_websocket, false) == true
  end

  defp put_reusable_responses_websocket(model, request_opts, provider_opts, session_id) do
    with {:ok, pid} <- Exy.Model.Transport.WebSocketPool.get(model, request_opts, session_id) do
      provider_opts =
        provider_opts
        |> Keyword.put(:openai_stream_transport, :websocket)
        |> Keyword.put(:openai_websocket_session, pid)

      {:ok, Keyword.put(request_opts, :provider_options, provider_opts)}
    end
  end
end
