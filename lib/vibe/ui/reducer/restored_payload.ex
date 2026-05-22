defmodule Vibe.UI.Reducer.RestoredPayload do
  @moduledoc false

  @spec user_message(term()) :: map()
  def user_message(payload) do
    map = payload_map(payload)

    %{text: Map.fetch!(map, :text)}
    |> maybe_put(:content, Map.get(map, :content))
    |> maybe_put(:image_count, Map.get(map, :image_count))
  end

  @spec assistant_message(term()) :: map()
  def assistant_message(payload), do: payload_map(payload)

  @spec patch_confirmation(term()) :: map()
  def patch_confirmation(payload), do: payload_map(payload)

  @spec usage(term()) :: map()
  def usage(payload), do: payload_map(payload)

  @spec overlay(term()) :: map()
  def overlay(payload), do: payload_map(payload)

  @spec notification(term()) :: map()
  def notification(payload), do: payload_map(payload)

  @spec subagent(term()) :: map()
  def subagent(payload), do: payload_map(payload)

  @spec assistant_abort(term()) :: %{reason: term(), notify?: term()}
  def assistant_abort(payload) do
    map = payload_map(payload)
    %{reason: Map.get(map, :reason, "Cancelled."), notify?: Map.get(map, :notify?, true)}
  end

  @spec text(term()) :: term()
  def text(payload), do: payload |> payload_map() |> Map.fetch!(:text)

  @spec optional_text(term()) :: term()
  def optional_text(payload), do: payload |> payload_map() |> Map.get(:text)

  @spec id(term()) :: term()
  def id(payload), do: payload |> payload_map() |> Map.fetch!(:id)

  @spec status(term()) :: term()
  def status(payload), do: payload |> payload_map() |> Map.fetch!(:status)

  @spec model(term()) :: term()
  def model(payload), do: payload |> payload_map() |> Map.fetch!(:model)

  @spec effort(term()) :: term()
  def effort(payload), do: payload |> payload_map() |> Map.fetch!(:effort)

  @spec session_id(term()) :: term()
  def session_id(payload), do: payload |> payload_map() |> Map.fetch!(:session_id)

  @spec count(term()) :: term()
  def count(payload), do: payload |> payload_map() |> Map.fetch!(:count)

  @spec key(term()) :: term()
  def key(payload), do: payload |> payload_map() |> Map.fetch!(:key)

  @spec widget(term()) :: term()
  def widget(payload), do: payload |> payload_map() |> Map.fetch!(:widget)

  @spec message(term()) :: term()
  def message(payload), do: payload |> payload_map() |> Map.fetch!(:message)

  @spec label(term()) :: term()
  def label(payload), do: payload |> payload_map() |> Map.fetch!(:label)

  @spec title(term()) :: term()
  def title(payload), do: payload |> payload_map() |> Map.fetch!(:title)

  @spec direction(term()) :: term()
  def direction(payload), do: payload |> payload_map() |> Map.fetch!(:direction)

  @spec context_tokens_before(term()) :: term()
  def context_tokens_before(payload), do: payload |> payload_map() |> Map.get(:tokens_before, 0)

  @spec context_failure_reason(term()) :: term()
  def context_failure_reason(payload) do
    payload |> payload_map() |> Map.get(:reason, "context compaction failed")
  end

  @spec context_summary(term()) :: term()
  def context_summary(payload),
    do: payload |> payload_map() |> Map.get(:summary, "context compacted")

  @spec plugin_status(term()) :: %{key: term(), text: term()}
  def plugin_status(payload) do
    map = payload_map(payload)
    %{key: Map.fetch!(map, :key), text: Map.fetch!(map, :text)}
  end

  defp payload_map(%struct{} = payload) when is_atom(struct) do
    payload
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {payload_key(key), value} end)
  end

  defp payload_map(payload) when is_map(payload) do
    Map.new(payload, fn {key, value} -> {payload_key(key), value} end)
  end

  defp payload_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp payload_key(key), do: key

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
