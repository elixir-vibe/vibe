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
            status: :idle,
            overlays: [],
            editor: %{text: "", history: []},
            events: []

  @type message :: %{
          required(:role) => :user | :assistant,
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
          status: atom(),
          overlays: [map()],
          editor: map(),
          events: [Exy.UI.Event.t()]
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      session_id: Keyword.get_lazy(opts, :session_id, &Exy.Session.new_id/0),
      cwd: Keyword.get_lazy(opts, :cwd, fn -> File.cwd!() end),
      model: Keyword.get_lazy(opts, :model, &Exy.LLM.Model.default/0)
    }
  end
end
