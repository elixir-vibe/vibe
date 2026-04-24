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
    defstruct [:id, :text, :error, :result, :at]
  end

  defmodule ToolCall do
    @moduledoc false
    defstruct [:id, :name, :status, :args, :output, :expanded?]
  end

  defmodule Footer do
    @moduledoc false
    defstruct [:cwd, :model, :session_id, :status, :usage]

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
end
