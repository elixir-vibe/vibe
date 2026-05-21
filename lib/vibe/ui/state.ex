defmodule Vibe.UI.State do
  @moduledoc """
  UI-neutral session state shared by terminal and LiveView renderers.

  This struct is the semantic UI source of truth. Reducers update it from Vibe UI
  events and renderers adapt it to terminal widgets, LiveView assigns, or tests.
  Keep terminal control sequences and renderer-specific details outside this
  state so alternate clients can consume the same session model.
  """

  alias Vibe.Model.Effort
  alias Vibe.UI.{Event, Notification, Selector}

  defstruct session_id: nil,
            cwd: nil,
            model: nil,
            effort: nil,
            messages: [],
            pending_tools: %{},
            usage: %{input_tokens: 0, output_tokens: 0, total_tokens: 0, total_cost: 0.0},
            usage_preview: %{input_tokens: 0, output_tokens: 0, total_tokens: 0},
            goal: nil,
            truncate?: true,
            status: :idle,
            overlays: [],
            notifications: [],
            runtime_alerts: %{},
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
          required(:role) => :user | :assistant | :tool | :subagent,
          required(:at) => DateTime.t(),
          optional(atom()) => term()
        }

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          cwd: String.t() | nil,
          model: String.t() | nil,
          effort: Effort.t() | nil,
          messages: [message()],
          pending_tools: map(),
          usage: map(),
          usage_preview: map(),
          goal: Vibe.Goals.Goal.t() | nil,
          truncate?: boolean(),
          status: atom(),
          overlays: [map()],
          notifications: [Notification.t()],
          runtime_alerts: %{String.t() => Vibe.Runtime.Alert.t()},
          plugin_statuses: map(),
          active_sessions: non_neg_integer() | nil,
          plugin_widgets: map(),
          working_message: String.t() | nil,
          hidden_thinking_label: String.t() | nil,
          title: String.t() | nil,
          selector: Selector.t() | nil,
          streaming_message: map() | nil,
          editor: map(),
          events: [Event.t()]
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      session_id: Keyword.get_lazy(opts, :session_id, &Vibe.Session.Store.new_id/0),
      cwd: Keyword.get_lazy(opts, :cwd, fn -> File.cwd!() end),
      model: Keyword.get_lazy(opts, :model, &Vibe.Agent.Profile.default_model/0),
      effort: Keyword.get_lazy(opts, :effort, &Vibe.Agent.Profile.default_effort/0),
      runtime_alerts: active_runtime_alerts()
    }
  end

  defp active_runtime_alerts do
    Vibe.SystemAlarms.active()
    |> Map.new(&{&1.id, &1})
  catch
    :exit, _reason -> %{}
  end
end
