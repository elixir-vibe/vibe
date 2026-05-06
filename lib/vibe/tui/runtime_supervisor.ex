defmodule Vibe.TUI.RuntimeSupervisor do
  @moduledoc "Supervisor for TUI runtime child processes."
  use Supervisor

  alias Vibe.Session
  alias Vibe.TUI.{App, TerminalLoop}
  alias Vibe.UI.EditorServer

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

    session_server = Keyword.get(opts, :session_server)

    children = [
      local_session_child(session_server, opts, session_name),
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
             |> Keyword.put(:session_server, session_server || session_name)
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

    children
    |> Enum.reject(&is_nil/1)
    |> Supervisor.init(strategy: :one_for_all)
  end

  defp local_session_child(nil, opts, session_name) do
    %{
      id: Session,
      start: {Session, :start_link, [Keyword.put(opts, :name, session_name)]}
    }
  end

  defp local_session_child(_session_server, _opts, _session_name), do: nil

  @spec name(term(), atom()) :: GenServer.name()
  def name(id, child), do: {:via, Registry, {Vibe.Registry, {__MODULE__, id, child}}}
end
