defmodule Vibe.Model.Error do
  @moduledoc "Normalizes model/provider failures into semantic UI errors."

  alias Vibe.UI.Error

  @spec normalize(term()) :: Error.t()
  def normalize(%Error{} = error), do: error
  def normalize({:failed, _kind, reason}), do: normalize(reason)
  def normalize({:error, reason}), do: normalize(reason)
  def normalize({:http_streaming_failed, reason}), do: normalize(reason)
  def normalize({:provider_build_failed, reason}), do: normalize(reason)

  def normalize(%{__struct__: struct, reason: reason} = error)
      when struct in [ReqLLM.Error.API.Request, ReqLLM.Error.API.Stream] and is_binary(reason) do
    reason
    |> unwrap_reason()
    |> from_request_reason()
    |> maybe_put_detail(inspect(error, limit: 6, printable_limit: 220))
  end

  def normalize({:exception, kind, reason, stacktrace}) do
    Error.new(exception_message(kind, reason),
      kind: :prompt_exception,
      detail: Exception.format(kind, reason, stacktrace)
    )
  end

  def normalize(reason) when is_binary(reason) do
    case reason_from_tuple_string(reason) do
      nil -> Error.new(reason)
      extracted -> from_request_reason(extracted) |> maybe_put_detail(reason)
    end
  end

  def normalize(reason) do
    Error.new("Model request failed.", detail: inspect(reason, limit: 6, printable_limit: 220))
  end

  defp exception_message(:error, %{__struct__: module} = exception) do
    module
    |> Module.split()
    |> List.last()
    |> then(&"#{&1}: #{Exception.message(exception)}")
  end

  defp exception_message(kind, reason), do: "#{kind}: #{inspect(reason, limit: 4)}"

  defp from_request_reason(reason) do
    if codex_oauth_error?(reason) do
      Error.new(
        "Codex sign-in required.",
        kind: :auth_required,
        provider: :openai_codex,
        hint: "Run `vibe --login codex`, then retry.",
        retryable?: true
      )
    else
      Error.new(reason)
    end
  end

  defp maybe_put_detail(%Error{} = error, detail) do
    if error.detail in [nil, ""], do: %{error | detail: detail}, else: error
  end

  defp reason_from_tuple_string("{:failed" <> _rest = text), do: regex_reason(text)
  defp reason_from_tuple_string("{:error" <> _rest = text), do: regex_reason(text)
  defp reason_from_tuple_string(_text), do: nil

  defp regex_reason(text) do
    case Regex.run(~r/reason: "([^"]+)"/, text) do
      [_match, reason] -> reason
      _no_reason -> nil
    end
  end

  defp unwrap_reason("Stream failed: " <> inner), do: unwrap_reason(inner)

  defp unwrap_reason(reason) do
    case Regex.run(~r/reason: "([^"]+)"/, reason) do
      [_match, extracted] -> extracted
      _no_match -> reason
    end
  end

  defp codex_oauth_error?(reason) do
    String.contains?(reason, "OAuth mode requires") and
      String.contains?(reason, ":access_token or an oauth file")
  end
end
