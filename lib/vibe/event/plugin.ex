defmodule Vibe.Event.Plugin do
  @moduledoc "Typed semantic plugin presentation event payloads."

  defmodule StatusUpdated do
    @moduledoc "Payload for updating plugin status text."
    @enforce_keys [:key, :text]
    defstruct [:key, :text]
  end

  defmodule StatusCleared do
    @moduledoc "Payload for clearing plugin status text."
    @enforce_keys [:key]
    defstruct [:key]
  end

  defmodule WidgetUpdated do
    @moduledoc "Payload for updating a plugin widget."
    @enforce_keys [:widget]
    defstruct [:widget]
  end

  defmodule WidgetCleared do
    @moduledoc "Payload for clearing a plugin widget."
    @enforce_keys [:key]
    defstruct [:key]
  end

  def status_updated(key, text), do: %StatusUpdated{key: key, text: text}
  def status_cleared(key), do: %StatusCleared{key: key}
  def widget_updated(widget), do: %WidgetUpdated{widget: widget}
  def widget_cleared(key), do: %WidgetCleared{key: key}
end
