defmodule Vibe.UI.Notification do
  @moduledoc "Transient notification state for TUI and web UI."
  @type level :: :info | :success | :warning | :error | atom()
  @type t :: %__MODULE__{id: term(), level: level(), text: String.t()}

  defstruct [:id, :level, :text]

  @spec new(t() | map() | keyword() | String.t()) :: t()
  def new(%__MODULE__{} = notification), do: notification
  def new(text) when is_binary(text), do: %__MODULE__{text: text, level: :info}
  def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

  def new(fields) when is_map(fields) do
    %__MODULE__{
      id: Map.get(fields, :id),
      level: Map.get(fields, :level, :info),
      text: Map.get(fields, :text, "")
    }
  end
end
