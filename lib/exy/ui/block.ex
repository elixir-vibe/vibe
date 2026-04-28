defmodule Exy.UI.Block do
  @moduledoc """
  Semantic UI blocks shared by TUI and future LiveView renderers.
  """

  defmodule UserMessage do
    @moduledoc false
    defstruct [:id, :text, :at]
  end

  defmodule AssistantMessage do
    @moduledoc false
    defstruct [:id, :text, :error, :result, :at, :loader_label]
  end

  defmodule ToolCall do
    @moduledoc false
    defstruct [:id, :name, :status, :args, :output, :output_format, :expanded?, :truncate?]
  end

  defmodule SubagentLifecycle do
    @moduledoc false
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
    @moduledoc false
    defstruct [:cwd, :model, :session_id, :status, :usage, :active_sessions, plugin_statuses: %{}]

    @type t :: %__MODULE__{}
  end

  defmodule Overlay do
    @moduledoc false
    defstruct [:kind, :data]

    @type t :: %__MODULE__{}
  end

  defmodule NotificationList do
    @moduledoc false
    defstruct items: []

    @type t :: %__MODULE__{}
  end

  defmodule PluginWidget do
    @moduledoc false
    defstruct [:id, :type, :props, placement: :above_editor, version: 0]

    @type t :: %__MODULE__{}
  end
end
