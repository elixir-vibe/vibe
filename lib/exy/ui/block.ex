defmodule Exy.UI.Block do
  @moduledoc """
  Semantic UI blocks shared by TUI and future LiveView renderers.
  """

  defmodule UserMessage do
    @moduledoc "Semantic content block types for UI state messages."
    defstruct [:id, :text, :at]
  end

  defmodule AssistantMessage do
    @moduledoc "Assistant response block with text, error, or streaming loader."
    defstruct [:id, :text, :error, :result, :at, :loader_label]
  end

  defmodule ToolCall do
    @moduledoc "Tool invocation block with args, status, and output."
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
    @moduledoc "Subagent job lifecycle event block."
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
    @moduledoc "Footer state: model, effort, usage, session, and plugin statuses."
    defstruct [
      :cwd,
      :model,
      :effort,
      :session_id,
      :status,
      :usage,
      :active_sessions,
      runtime_alerts: [],
      plugin_statuses: %{}
    ]

    @type t :: %__MODULE__{}
  end

  defmodule Overlay do
    @moduledoc "Modal overlay state for selectors and dialogs."
    defstruct [:kind, :data]

    @type t :: %__MODULE__{}
  end

  defmodule NotificationList do
    @moduledoc "Transient notification stack."
    defstruct items: []

    @type t :: %__MODULE__{}
  end

  defmodule PluginWidget do
    @moduledoc "Plugin-owned semantic widget rendered in the session UI."
    defstruct [:id, :type, :props, placement: :above_editor, version: 0]

    @type t :: %__MODULE__{}
  end
end
