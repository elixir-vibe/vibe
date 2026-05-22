defmodule Vibe.Event.Surface do
  @moduledoc "Typed semantic surface-state event payloads."

  defmodule StatusChanged do
    @moduledoc "Payload for session status changes."
    @enforce_keys [:status]
    defstruct [:status]
  end

  defmodule OverlayOpened do
    @moduledoc "Payload for opening an overlay."
    @enforce_keys [:overlay]
    defstruct [:overlay]
  end

  defmodule OverlayClosed do
    @moduledoc "Payload for closing the active overlay."
    defstruct []
  end

  defmodule TruncationToggled do
    @moduledoc "Payload for toggling prompt truncation."
    defstruct []
  end

  defmodule ToolToggled do
    @moduledoc "Payload for toggling an expanded tool result."
    @enforce_keys [:id]
    defstruct [:id]
  end

  defmodule ConfirmationRequested do
    @moduledoc "Payload for confirmation selector requests."
    @enforce_keys [:confirmation]
    defstruct [:confirmation]
  end

  defmodule WorkingMessageUpdated do
    @moduledoc "Payload for updating the working indicator label."
    defstruct [:message]
  end

  defmodule HiddenThinkingLabelUpdated do
    @moduledoc "Payload for updating the hidden-thinking label."
    defstruct [:label]
  end

  defmodule TitleUpdated do
    @moduledoc "Payload for updating the session title."
    defstruct [:title]
  end

  def status_changed(status), do: %StatusChanged{status: status}
  def overlay_opened(overlay) when is_map(overlay), do: %OverlayOpened{overlay: overlay}
  def overlay_closed, do: %OverlayClosed{}
  def truncation_toggled, do: %TruncationToggled{}
  def tool_toggled(id) when is_binary(id), do: %ToolToggled{id: id}

  def confirmation_requested(confirmation) when is_map(confirmation),
    do: %ConfirmationRequested{confirmation: confirmation}

  def working_message_updated(message), do: %WorkingMessageUpdated{message: message}
  def hidden_thinking_label_updated(label), do: %HiddenThinkingLabelUpdated{label: label}
  def title_updated(title), do: %TitleUpdated{title: title}
end
