defmodule Vibe.Model.Resolver do
  @moduledoc """
  Fuzzy model resolution with `model:effort` shorthand.

  Resolution order:
  1. Exact `provider:model_id` match
  2. LLMDB catalog search by substring
  3. `model:effort` shorthand — split on last colon, resolve model, parse effort

  Examples:
      resolve("anthropic:claude-sonnet-4")    → {:ok, "anthropic:claude-sonnet-4", nil}
      resolve("claude-sonnet")                → {:ok, "anthropic:claude-sonnet-4-...", nil}
      resolve("claude-sonnet:high")           → {:ok, "anthropic:claude-sonnet-4-...", :high}
      resolve("sonnet")                       → {:ok, "anthropic:claude-sonnet-4-...", nil}
  """

  alias Vibe.Model.Effort

  @type result :: {:ok, String.t(), Effort.t() | nil} | {:error, :not_found}

  @spec resolve(String.t()) :: result()
  def resolve(spec) when is_binary(spec) do
    with :not_found <- try_with_effort(spec),
         :not_found <- try_exact_result(spec),
         :not_found <- try_fuzzy(spec) do
      {:error, :not_found}
    end
  end

  defp try_exact_result(spec) do
    case try_exact(spec) do
      {:ok, model} -> {:ok, model, nil}
      :not_found -> :not_found
    end
  end

  defp try_exact(spec) do
    case ReqLLM.model(spec) do
      {:ok, model} -> {:ok, model_spec(model)}
      {:error, _} -> :not_found
    end
  rescue
    _error -> :not_found
  end

  defp try_with_effort(spec) do
    case String.split(spec, ":") do
      [_, _ | _] = parts ->
        {effort_str, model_parts} = List.pop_at(parts, -1)

        case Effort.from_string(effort_str) do
          {:ok, effort} ->
            model_spec = Enum.join(model_parts, ":")

            case try_exact(model_spec) do
              {:ok, model} -> {:ok, model, effort}
              :not_found -> try_fuzzy_bare(model_spec, effort)
            end

          {:error, _} ->
            :not_found
        end

      _no_colon ->
        :not_found
    end
  end

  defp try_fuzzy(spec) do
    case search_catalog(spec) do
      {:ok, model} -> {:ok, model, nil}
      :not_found -> {:error, :not_found}
    end
  end

  defp try_fuzzy_bare(spec, effort) do
    case search_catalog(spec) do
      {:ok, model} -> {:ok, model, effort}
      :not_found -> :not_found
    end
  end

  defp search_catalog(query) do
    Vibe.Model.Config.available_providers()
    |> Enum.find_value(fn provider ->
      spec = "#{provider}:#{query}"

      case ReqLLM.model(spec) do
        {:ok, model} -> {:ok, model_spec(model)}
        _error -> nil
      end
    end)
    |> case do
      {:ok, _} = result -> result
      nil -> :not_found
    end
  rescue
    _error -> :not_found
  end

  defp model_spec(%{provider: provider, id: id}) when is_atom(provider),
    do: "#{provider}:#{id}"

  defp model_spec(%{provider: provider, model: model}) when is_atom(provider),
    do: "#{provider}:#{model}"

  defp model_spec(model) when is_binary(model), do: model
  defp model_spec(model), do: inspect(model)
end
