defmodule Vibe.SystemAlarms.Alert do
  @moduledoc """
  Runtime alert surfaced by Vibe system services.

  Alerts describe operational state such as BEAM memory pressure or low disk
  space. They carry semantic runtime state only.
  """

  @enforce_keys [:id, :source, :type, :severity, :at]
  defstruct [:id, :source, :type, :severity, :detail, :at, context: %{}]

  @type severity :: :info | :warning | :error
  @type t :: %__MODULE__{
          id: String.t(),
          source: atom(),
          type: atom(),
          severity: severity(),
          detail: String.t() | nil,
          at: DateTime.t(),
          context: map()
        }

  @spec from_alarm(:set | :clear, term(), term(), keyword()) :: t()
  def from_alarm(action, alarm_id, description, opts \\ []) when action in [:set, :clear] do
    type = alarm_type(alarm_id)
    context = alarm_context(alarm_id)

    %__MODULE__{
      id: alert_id(type, context),
      source: :beam_alarm,
      type: type,
      severity: severity(action, type),
      detail: inspect({alarm_id, description}, limit: 20),
      at: Keyword.get_lazy(opts, :at, &DateTime.utc_now/0),
      context: context
    }
  end

  defp alert_id(:disk_almost_full, context),
    do: "disk_almost_full:#{Map.get(context, :path) || "unknown"}"

  defp alert_id(type, _context), do: to_string(type)

  defp severity(:clear, _type), do: :info
  defp severity(:set, :disk_almost_full), do: :error
  defp severity(:set, :system_memory_high_watermark), do: :warning
  defp severity(:set, _type), do: :warning

  defp alarm_type({type, _details}) when is_atom(type), do: type
  defp alarm_type(type) when is_atom(type), do: type
  defp alarm_type(_alarm_id), do: :unknown

  defp alarm_context({:disk_almost_full, path}) do
    path
    |> to_string()
    |> normalize_path()
    |> case do
      nil -> %{}
      path -> %{path: path}
    end
  end

  defp alarm_context(_alarm_id), do: %{}

  defp normalize_path(""), do: nil
  defp normalize_path(path), do: path
end
