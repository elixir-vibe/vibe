defmodule Exy.TUI.Storybook do
  @moduledoc """
  Small storybook for TUI widgets and views.
  """

  alias Exy.TUI.{Node, Theme, Width}
  alias Exy.UI.{Event, Reducer, State, ViewModel}

  @spec stories() :: [atom()]
  def stories,
    do: [:chat_basic, :tool_eval_ok, :tool_ast_matches, :tool_lsp_diagnostics, :footer_usage]

  @spec story(atom()) :: Node.t() | map()
  def story(:chat_basic) do
    State.new(session_id: "story-chat", cwd: File.cwd!(), model: "openai_codex:gpt-5.5")
    |> Reducer.apply_event(
      Event.new(:user_message_added, "story-chat", %{text: "Inspect runtime info"})
    )
    |> Reducer.apply_event(
      Event.new(:assistant_message_added, "story-chat", %{text: "Runtime looks healthy."})
    )
    |> Reducer.apply_event(
      Event.new(:usage_updated, "story-chat", %{
        input_tokens: 120,
        output_tokens: 32,
        total_tokens: 152
      })
    )
    |> ViewModel.from_state()
  end

  def story(:tool_eval_ok) do
    Node.tool(%{
      id: "eval-1",
      name: :elixir_eval,
      status: :ok,
      args: %{code: "Exy.OTP.runtime_info()"},
      output: "%{elixir: \"1.19.5\", process_count: 187}",
      expanded?: true
    })
  end

  def story(:tool_ast_matches) do
    Node.tool(%{
      id: "ast-1",
      name: :elixir_ast,
      status: :ok,
      args: %{action: :search, pattern: "def handle_call(_, _, _) do _ end"},
      output: [%{file: "lib/exy/trajectory/store.ex", line: 35}],
      expanded?: true
    })
  end

  def story(:tool_lsp_diagnostics) do
    Node.tool(%{
      id: "lsp-1",
      name: :elixir_lsp,
      status: :ok,
      args: %{action: :diagnostics, file: "lib/exy.ex"},
      output: [],
      expanded?: true
    })
  end

  def story(:footer_usage) do
    Node.footer(%{
      cwd: File.cwd!(),
      session_id: "story-footer",
      model: "openai_codex:gpt-5.5",
      status: :idle,
      usage: %{total_tokens: 12_345}
    })
  end

  @spec render(atom(), keyword()) :: [IO.chardata()]
  def render(name, opts \\ []) do
    width = Keyword.get(opts, :width, 100)
    theme = Keyword.get_lazy(opts, :theme, &Theme.default/0)

    case story(name) do
      %{body: _body} = view -> Exy.TUI.Renderer.render(view, width, theme)
      %Node{} = node -> Node.render(node, width, theme)
    end
  end

  @spec render_plain(atom(), keyword()) :: [String.t()]
  def render_plain(name, opts \\ []) do
    name
    |> render(opts)
    |> Enum.map(&Width.visible_text/1)
  end
end
