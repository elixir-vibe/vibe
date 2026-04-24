defmodule Exy.UI.EditorServer do
  @moduledoc """
  `:gen_statem` wrapper around `Exy.UI.Editor`.
  """

  @behaviour :gen_statem

  alias Exy.UI.Editor

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    :gen_statem.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec key(pid() | atom(), Editor.key()) :: [Editor.command()]
  def key(server, key), do: :gen_statem.call(server, {:key, key})

  @spec state(pid() | atom()) :: Editor.t()
  def state(server), do: :gen_statem.call(server, :state)

  @spec replace(pid() | atom(), String.t()) :: :ok
  def replace(server, text), do: :gen_statem.call(server, {:replace, text})

  @impl true
  def callback_mode, do: :handle_event_function

  @impl true
  def init(opts) do
    {:ok, :editing, Editor.new(opts)}
  end

  @impl true
  def handle_event({:call, from}, :state, _state_name, editor) do
    {:keep_state_and_data, [{:reply, from, editor}]}
  end

  def handle_event({:call, from}, {:replace, text}, _state_name, editor) do
    editor = %{editor | text: text, cursor: String.length(text)}
    {:next_state, :editing, editor, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:key, key}, state_name, editor) do
    {editor, commands} = Editor.handle_key(editor, key)
    next_state = next_state(state_name, key, editor)
    {:next_state, next_state, editor, [{:reply, from, commands}]}
  end

  defp next_state(_state_name, {:complete, [_ | _]}, _editor), do: :completion
  defp next_state(_state_name, :tab, %Editor{completions: [_ | _]}), do: :completion
  defp next_state(_state_name, :external_editor, _editor), do: :external
  defp next_state(:external, {:external_result, _text}, _editor), do: :editing
  defp next_state(_state_name, :cancel, _editor), do: :editing
  defp next_state(_state_name, :submit, _editor), do: :editing
  defp next_state(state_name, _key, _editor), do: state_name
end
