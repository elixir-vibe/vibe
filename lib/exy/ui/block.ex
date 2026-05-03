defmodule Exy.UI.Block do
  @moduledoc """
  Semantic UI blocks shared by TUI and future LiveView renderers.
  """

  defmodule UserMessage do
    @moduledoc "Internal implementation module."
    defstruct [:id, :text, :at]
  end

  defmodule AssistantMessage do
    @moduledoc "Internal implementation module."
    defstruct [:id, :text, :error, :result, :at, :loader_label]
  end

  defmodule ToolCall do
    @moduledoc "Internal implementation module."
    defstruct [
      :id,
      :name,
      :status,
      :args,
      :output,
      :output_format,
      :output_parts,
      :expanded?,
      :truncate?
    ]
  end

  defmodule SubagentLifecycle do
    @moduledoc "Internal implementation module."
    defstruct [
      :id,
      :job_id,
      :role_name,
      :lifecycle,
      :status,
      :task,
      :child_session_id,
      :error,
      :at
    ]
  end

  defmodule Footer do
    @moduledoc "Internal implementation module."
    defstruct [
      :cwd,
      :model,
      :effort,
      :session_id,
      :status,
      :usage,
      :active_sessions,
      plugin_statuses: %{}
    ]

    @type t :: %__MODULE__{}
  end

  defmodule Overlay do
    @moduledoc "Internal implementation module."
    defstruct [:kind, :data]

    @type t :: %__MODULE__{}
  end

  defmodule NotificationList do
    @moduledoc "Internal implementation module."
    defstruct items: []

    @type t :: %__MODULE__{}
  end

  defmodule PluginWidget do
    @moduledoc "Internal implementation module."
    defstruct [:id, :type, :props, placement: :above_editor, version: 0]

    @type t :: %__MODULE__{}
  end
end
