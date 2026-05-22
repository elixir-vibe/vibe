defmodule Vibe.Presentation.RuntimeAlert do
  @moduledoc "Renderer-neutral presentation for runtime alerts."

  alias Vibe.SystemAlarms.Alert

  @enforce_keys [:id, :severity, :title, :message]
  defstruct [:id, :severity, :title, :message, :footer_label]

  @type t :: %__MODULE__{
          id: String.t(),
          severity: Alert.severity(),
          title: String.t(),
          message: String.t(),
          footer_label: String.t() | nil
        }

  @spec from_alert(Alert.t()) :: t()
  def from_alert(%Alert{} = alert) do
    %__MODULE__{
      id: alert.id,
      severity: alert.severity,
      title: title(alert),
      message: message(alert),
      footer_label: footer_label(alert)
    }
  end

  @spec notification_attrs(t()) :: map()
  def notification_attrs(%__MODULE__{} = alert) do
    %{
      id: {:runtime_alert, alert.id},
      level: alert.severity,
      text: "#{alert.title}: #{alert.message}"
    }
  end

  defp title(%Alert{severity: :info, type: :disk_almost_full}), do: "Disk pressure cleared"
  defp title(%Alert{type: :disk_almost_full}), do: "Disk almost full"

  defp title(%Alert{severity: :info, type: :system_memory_high_watermark}),
    do: "Memory pressure cleared"

  defp title(%Alert{type: :system_memory_high_watermark}), do: "System memory pressure"
  defp title(%Alert{severity: :info}), do: "Runtime alert cleared"
  defp title(%Alert{}), do: "Runtime alert"

  defp message(%Alert{severity: :info, type: :disk_almost_full, context: context}) do
    "#{disk_path(context)} has recovered."
  end

  defp message(%Alert{type: :disk_almost_full, context: context}) do
    "#{disk_path(context)} is low on space; large writes, downloads, and artifacts may fail."
  end

  defp message(%Alert{severity: :info, type: :system_memory_high_watermark}) do
    "Memory pressure has cleared."
  end

  defp message(%Alert{type: :system_memory_high_watermark}) do
    "Prefer targeted work and avoid broad parallel scans until pressure clears."
  end

  defp message(%Alert{severity: :info, type: type}), do: "#{type} cleared."
  defp message(%Alert{type: type}), do: "#{type} was raised by the BEAM alarm handler."

  defp footer_label(%Alert{type: :disk_almost_full, context: context}),
    do: "disk low: #{disk_path(context)}"

  defp footer_label(%Alert{type: :system_memory_high_watermark}), do: "memory pressure"
  defp footer_label(%Alert{} = alert), do: title(alert)

  defp disk_path(context), do: Map.get(context, :path) || "disk"
end

defimpl Vibe.Presentation.Presentable, for: Vibe.SystemAlarms.Alert do
  def present(alert), do: Vibe.Presentation.RuntimeAlert.from_alert(alert)
end
