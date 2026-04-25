defmodule Exy.TUI.RuntimeSupervisor do
  @moduledoc false

  use Supervisor

  alias Exy.Session
  alias Exy.TUI.{App, TerminalLoop}
  alias Exy.UI.EditorServer

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    {supervisor_opts, init_opts} = Keyword.split(opts, [:name])
    Supervisor.start_link(__MODULE__, init_opts, supervisor_opts)
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :runtime_id)
    session_name = name(id, :session)
    editor_name = name(id, :editor)
    app_name = name(id, :app)

    children = [
      %{
        id: Session,
        start: {Session, :start_link, [Keyword.put(opts, :name, session_name)]}
      },
      %{
        id: EditorServer,
        start:
          {EditorServer, :start_link,
           [[name: editor_name, history: Keyword.get(opts, :history, [])]]}
      },
      %{
        id: App,
        start:
          {App, :start_link,
           [
             opts
             |> Keyword.put(:name, app_name)
             |> Keyword.put(:session_server, session_name)
             |> Keyword.put(:editor_server, editor_name)
           ]}
      },
      %{
        id: TerminalLoop,
        start:
          {TerminalLoop, :start_link,
           [opts |> Keyword.put(:name, name(id, TerminalLoop)) |> Keyword.put(:app, app_name)]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @spec name(term(), atom()) :: GenServer.name()
  def name(id, child), do: {:via, Registry, {Exy.Registry, {__MODULE__, id, child}}}
end
