defmodule Exy.Runtime.Alert do
  @moduledoc """
  Renderer-neutral runtime alert surfaced by Exy system services.

  Alerts describe operational state such as BEAM memory pressure or low disk
  space. They are suitable for semantic UI state and dashboards; prompt/model
  injection remains a separate policy decision.
  """

  alias Exy.UI.Notification

  @enforce_keys [:id, :source, :type, :severity, :title, :message, :at]
  defstruct [:id, :source, :type, :severity, :title, :message, :detail, :at]

  @type severity :: :info | :warning | :error
  @type t :: %__MODULE__{
          id: String.t(),
          source: atom(),
          type: atom(),
          severity: severity(),
          title: String.t(),
          message: String.t(),
          detail: String.t() | nil,
          at: DateTime.t()
        }

  @spec from_alarm(:set | :clear, term(), term(), keyword()) :: t()
  def from_alarm(action, alarm_id, description, opts \\ []) when action in [:set, :clear] do
    type = alarm_type(alarm_id)
    path = disk_path(alarm_id)

    %__MODULE__{
      id: alert_id(type, path),
      source: :beam_alarm,
      type: type,
      severity: severity(action, type),
      title: title(action, type),
      message: message(action, type, path),
      detail: inspect({alarm_id, description}, limit: 20),
      at: Keyword.get_lazy(opts, :at, &DateTime.utc_now/0)
    }
  end

  @spec to_notification(t()) :: Notification.t()
  def to_notification(%__MODULE__{} = alert) do
    Notification.new(%{
      id: {:runtime_alert, alert.id},
      level: alert.severity,
      text: "#{alert.title}: #{alert.message}"
    })
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = alert) do
    %{
      id: alert.id,
      source: alert.source,
      type: alert.type,
      severity: alert.severity,
      title: alert.title,
      message: alert.message,
      detail: alert.detail,
      at: alert.at
    }
  end

  @spec normalize(t() | map()) :: t()
  def normalize(%__MODULE__{} = alert), do: alert

  def normalize(alert) when is_map(alert) do
    %__MODULE__{
      id: fetch_value!(alert, :id),
      source: atom_value(fetch_value(alert, :source, :unknown)),
      type: atom_value(fetch_value(alert, :type, :unknown)),
      severity: atom_value(fetch_value(alert, :severity, :info)),
      title: fetch_value(alert, :title, "Runtime alert"),
      message: fetch_value(alert, :message, "Runtime state changed."),
      detail: fetch_value(alert, :detail),
      at: normalize_at(fetch_value(alert, :at, DateTime.utc_now()))
    }
  end

  defp alert_id(:disk_almost_full, path), do: "disk_almost_full:#{path || "unknown"}"
  defp alert_id(type, _path), do: to_string(type)

  defp severity(:clear, _type), do: :info
  defp severity(:set, :disk_almost_full), do: :error
  defp severity(:set, :system_memory_high_watermark), do: :warning
  defp severity(:set, _type), do: :warning

  defp title(:clear, :disk_almost_full), do: "Disk pressure cleared"
  defp title(:set, :disk_almost_full), do: "Disk almost full"
  defp title(:clear, :system_memory_high_watermark), do: "Memory pressure cleared"
  defp title(:set, :system_memory_high_watermark), do: "System memory pressure"
  defp title(:clear, _type), do: "Runtime alert cleared"
  defp title(:set, _type), do: "Runtime alert"

  defp message(:clear, :disk_almost_full, path), do: "#{path || "disk"} has recovered."

  defp message(:set, :disk_almost_full, path) do
    "#{path || "disk"} is low on space; large writes, downloads, and artifacts may fail."
  end

  defp message(:clear, :system_memory_high_watermark, _path), do: "Memory pressure has cleared."

  defp message(:set, :system_memory_high_watermark, _path) do
    "Prefer targeted work and avoid broad parallel scans until pressure clears."
  end

  defp message(:clear, type, _path), do: "#{type} cleared."
  defp message(:set, type, _path), do: "#{type} was raised by the BEAM alarm handler."

  defp alarm_type({type, _details}) when is_atom(type), do: type
  defp alarm_type(type) when is_atom(type), do: type
  defp alarm_type(_alarm_id), do: :unknown

  defp disk_path({:disk_almost_full, path}), do: path |> to_string() |> normalize_path()
  defp disk_path(_alarm_id), do: nil

  defp normalize_path([]), do: nil
  defp normalize_path(path), do: path

  defp fetch_value!(map, key) do
    fetch_value(map, key) || raise KeyError, key: key, term: map
  end

  defp fetch_value(map, key, default \\ nil) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp normalize_at(%DateTime{} = at), do: at

  defp normalize_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, at, _offset} -> at
      _other -> DateTime.utc_now()
    end
  end

  defp normalize_at(_value), do: DateTime.utc_now()

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> :unknown
  end

  defp atom_value(_value), do: :unknown
end

defimpl Jason.Encoder, for: Exy.Runtime.Alert do
  def encode(alert, opts) do
    alert
    |> Exy.Runtime.Alert.to_map()
    |> Exy.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
