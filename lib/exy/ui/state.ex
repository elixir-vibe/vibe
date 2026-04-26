defmodule Exy.UI.State do
  @moduledoc """
  UI-neutral session state shared by terminal and LiveView renderers.
  """

  defstruct session_id: nil,
            cwd: nil,
            model: nil,
            messages: [],
            pending_tools: %{},
            usage: %{input_tokens: 0, output_tokens: 0, total_tokens: 0, total_cost: 0.0},
            usage_preview: %{input_tokens: 0, output_tokens: 0, total_tokens: 0},
            truncate?: true,
            status: :idle,
            overlays: [],
            notifications: [],
            plugin_statuses: %{},
            active_sessions: nil,
            plugin_widgets: %{},
            working_message: nil,
            hidden_thinking_label: nil,
            title: nil,
            selector: nil,
            streaming_message: nil,
            editor: %{text: "", history: []},
            events: []

  @type message :: %{
          required(:role) => :user | :assistant | :tool,
          required(:at) => DateTime.t(),
          optional(atom()) => term()
        }

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          cwd: String.t() | nil,
          model: String.t() | nil,
          messages: [message()],
          pending_tools: map(),
          usage: map(),
          usage_preview: map(),
          truncate?: boolean(),
          status: atom(),
          overlays: [map()],
          notifications: [map()],
          plugin_statuses: map(),
          active_sessions: non_neg_integer() | nil,
          plugin_widgets: map(),
          working_message: String.t() | nil,
          hidden_thinking_label: String.t() | nil,
          title: String.t() | nil,
          selector: map() | nil,
          streaming_message: map() | nil,
          editor: map(),
          events: [Exy.UI.Event.t()]
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      session_id: Keyword.get_lazy(opts, :session_id, &Exy.Session.Store.new_id/0),
      cwd: Keyword.get_lazy(opts, :cwd, fn -> File.cwd!() end),
      model: Keyword.get_lazy(opts, :model, &Exy.Model.Config.default/0)
    }
  end
end
