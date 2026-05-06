defmodule Vibe.Model.Effort do
  @moduledoc "Model effort values used by agent profiles and sessions."

  @type t :: :off | :minimal | :low | :medium | :high | :xhigh

  @values [:off, :minimal, :low, :medium, :high, :xhigh]
  @default :medium

  @spec values() :: [t()]
  def values, do: @values

  @spec default() :: t()
  def default, do: @default

  @spec valid?(atom()) :: boolean()
  def valid?(value), do: value in @values

  @spec from_string(String.t()) :: {:ok, t()} | {:error, {:unknown_effort, String.t()}}
  def from_string(value) when is_binary(value) do
    value = value |> String.trim() |> String.downcase()

    case Enum.find(@values, &(Atom.to_string(&1) == value)) do
      nil -> {:error, {:unknown_effort, value}}
      effort -> {:ok, effort}
    end
  end

  @spec label(t()) :: String.t()
  def label(value) when value in @values, do: Atom.to_string(value)
end
