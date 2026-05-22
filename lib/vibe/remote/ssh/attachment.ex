defmodule Vibe.Remote.SSH.Attachment do
  @moduledoc "Long-polling SSH attachment bridge for session events."

  use GenServer

  @default_timeout_ms 30_000

  defstruct [:id, :session_id, :session, :snapshot, :cursor, events: :queue.new(), waiter: nil]

  @type start_result ::
          {:ok, %{id: String.t(), state: Vibe.UI.State.t(), cursor: non_neg_integer()}}

  @spec start(String.t()) :: start_result() | {:error, term()}
  def start(session_id) do
    id = "ssh-attach-#{System.unique_integer([:positive, :monotonic])}"

    spec =
      Supervisor.child_spec({__MODULE__, [id: id, session_id: session_id]},
        id: {__MODULE__, id},
        restart: :temporary
      )

    with {:ok, pid} <- DynamicSupervisor.start_child(Vibe.Remote.SSH.AttachmentSupervisor, spec) do
      GenServer.call(pid, :snapshot)
    end
  end

  @spec next_events(String.t(), timeout()) :: {:ok, [Vibe.Event.t()]} | {:error, term()}
  def next_events(id, timeout_ms \\ @default_timeout_ms) do
    with {:ok, pid} <- lookup(id) do
      GenServer.call(pid, {:next_events, timeout_ms}, timeout_ms + 1_000)
    end
  end

  @spec detach(String.t()) :: :ok | {:error, term()}
  def detach(id) do
    with {:ok, pid} <- lookup(id) do
      GenServer.stop(pid, :normal)
      :ok
    end
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    session_id = Keyword.fetch!(opts, :session_id)

    with {:ok, session} <- Vibe.Session.lookup(session_id),
         {:ok, snapshot, cursor} <- Vibe.Session.attach(session, self()) do
      {:ok,
       %__MODULE__{
         id: id,
         session_id: session_id,
         session: session,
         snapshot: snapshot,
         cursor: cursor
       }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, %{id: state.id, state: state.snapshot, cursor: state.cursor}}, state}
  end

  def handle_call({:next_events, timeout_ms}, from, %{waiter: nil} = state) do
    case take_events(state.events) do
      {[], events} ->
        ref = Process.send_after(self(), {:poll_timeout, make_ref()}, timeout_ms)
        {:noreply, %{state | events: events, waiter: {from, ref}}}

      {events, queue} ->
        {:reply, {:ok, events}, %{state | events: queue}}
    end
  end

  def handle_call({:next_events, _timeout_ms}, _from, state) do
    {:reply, {:error, :poll_already_waiting}, state}
  end

  @impl true
  def handle_info({Vibe.Session, :event, event}, %{waiter: nil} = state) do
    {:noreply, %{state | events: :queue.in(event, state.events)}}
  end

  def handle_info({Vibe.Session, :event, event}, %{waiter: {from, timer}} = state) do
    Process.cancel_timer(timer)
    GenServer.reply(from, {:ok, [event]})
    {:noreply, %{state | waiter: nil}}
  end

  def handle_info({:poll_timeout, _ref}, %{waiter: {from, _timer}} = state) do
    GenServer.reply(from, {:ok, []})
    {:noreply, %{state | waiter: nil}}
  end

  def handle_info({:poll_timeout, _ref}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{session: session}) when is_pid(session) do
    Vibe.Session.detach(session, self())
  catch
    :exit, _reason -> :ok
  end

  def terminate(_reason, _state), do: :ok

  defp lookup(id) do
    case Registry.lookup(Vibe.Registry, {:ssh_attachment, id}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  defp via(id), do: {:via, Registry, {Vibe.Registry, {:ssh_attachment, id}}}

  defp take_events(queue), do: take_events(queue, [])

  defp take_events(queue, acc) do
    case :queue.out(queue) do
      {{:value, event}, rest} -> take_events(rest, [event | acc])
      {:empty, rest} -> {Enum.reverse(acc), rest}
    end
  end
end
