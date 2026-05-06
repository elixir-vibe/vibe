defmodule Vibe.Model.Switcher do
  @moduledoc "Model and effort switching helpers."

  alias Vibe.Model.Effort

  @type direction :: :forward | :backward

  @spec model_options(String.t() | nil) :: [String.t()]
  def model_options(current_model \\ nil) do
    Vibe.Agent.Profile.models()
    |> include_current(current_model)
  end

  @spec cycle_model(String.t() | nil, direction()) :: {:ok, String.t()} | {:error, :one_model}
  def cycle_model(current_model, direction \\ :forward) when direction in [:forward, :backward] do
    models = model_options(current_model)

    case models do
      [] -> {:error, :one_model}
      [_model] -> {:error, :one_model}
      models -> {:ok, cycle_value(models, current_model, direction)}
    end
  end

  @spec effort_options(String.t() | nil) :: [Effort.t()]
  def effort_options(_model \\ nil), do: Effort.values()

  @spec cycle_effort(Effort.t() | nil, String.t() | nil) :: Effort.t()
  def cycle_effort(current_effort, model \\ nil) do
    efforts = effort_options(model)
    current_effort = if Effort.valid?(current_effort), do: current_effort, else: Effort.default()
    cycle_value(efforts, current_effort, :forward)
  end

  defp cycle_value(values, current, direction) do
    index = Enum.find_index(values, &(&1 == current)) || 0
    count = length(values)

    next_index =
      case direction do
        :forward -> rem(index + 1, count)
        :backward -> rem(index - 1 + count, count)
      end

    Enum.at(values, next_index)
  end

  defp include_current(models, current_model) when is_binary(current_model) do
    models
    |> Enum.reject(&is_nil/1)
    |> Kernel.++([current_model])
    |> Enum.uniq()
  end

  defp include_current(models, _current_model), do: Enum.reject(models, &is_nil/1)
end
