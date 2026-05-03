defmodule Exy.Session.Preview do
  @moduledoc "Internal implementation module."

  alias ReqLLM.Error.API.Request
  @spec message(map() | nil) :: String.t()
  def message(nil), do: ""

  def message(message) when is_map(message) do
    message
    |> preview_value()
    |> preview_text()
    |> clean_text()
  end

  defp preview_value(message) do
    Map.get(message, :text) || Map.get(message, :result) || Map.get(message, :error) || ""
  end

  defp preview_text(text) when is_binary(text), do: preview_binary(text)
  defp preview_text({:failed, _kind, reason}), do: preview_error(reason)
  defp preview_text({:error, reason}), do: preview_error(reason)
  defp preview_text(%{output: output}), do: preview_text(output)
  defp preview_text(%{"output" => output}), do: preview_text(output)
  defp preview_text(%{message: %{content: content}}), do: content_text(content)
  defp preview_text(%{"message" => %{"content" => content}}), do: content_text(content)
  defp preview_text(%{content: content}), do: content_text(content)
  defp preview_text(%{"content" => content}), do: content_text(content)
  defp preview_text(value), do: inspect(value, limit: 6, printable_limit: 180)

  defp preview_error(%Request{reason: reason}), do: "ERROR #{reason}"
  defp preview_error({:provider_build_failed, reason}), do: preview_error(reason)
  defp preview_error({:http_streaming_failed, reason}), do: preview_error(reason)
  defp preview_error(reason) when is_binary(reason), do: preview_binary(reason)
  defp preview_error(reason), do: "ERROR #{inspect(reason, limit: 4, printable_limit: 160)}"

  defp preview_binary("{:failed" <> _rest = text) do
    case Regex.run(~r/reason: "([^"]+)"/, text) do
      [_match, reason] -> "ERROR #{reason}"
      _no_reason -> "ERROR #{text}"
    end
  end

  defp preview_binary("{:error" <> _rest = text), do: "ERROR #{text}"
  defp preview_binary(text), do: text

  defp content_text(content) when is_binary(content), do: content

  defp content_text(content) when is_list(content) do
    content
    |> Enum.map(fn
      %{type: :text, text: text} -> text
      %{type: "text", text: text} -> text
      %{text: text} -> text
      %{"type" => "text", "text" => text} -> text
      %{"text" => text} -> text
      value -> preview_text(value)
    end)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("")
  end

  defp content_text(content), do: preview_text(content)

  defp clean_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/^%\{output: "(.+)"\}$/s, "\\1")
    |> String.slice(0, 120)
  end
end
