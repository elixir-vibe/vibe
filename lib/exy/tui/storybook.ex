defmodule Exy.TUI.Storybook do
  @moduledoc """
  Small storybook for TUI widgets and views.
  """

  use Exy.TUI

  alias Exy.TUI.{Node, Theme, Widget, Width}
  alias Exy.UI.{Event, Reducer, State, ViewModel}

  @spec stories() :: [atom()]
  def stories do
    [
      :chat_basic,
      :tool_eval_ok,
      :tool_ast_matches,
      :tool_lsp_diagnostics,
      :footer_usage,
      :status_rows,
      :section_header,
      :markdown_rich,
      :markdown_streaming,
      :model_info,
      :input,
      :themes,
      :dialog,
      :diff
    ]
  end

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
    DSL.tool(%{
      id: "eval-1",
      name: :elixir_eval,
      status: :ok,
      args: %{code: "Exy.OTP.runtime_info()"},
      output: "%{elixir: \"1.19.5\", process_count: 187}",
      expanded?: true
    })
  end

  def story(:tool_ast_matches) do
    DSL.tool(%{
      id: "ast-1",
      name: :elixir_ast,
      status: :ok,
      args: %{action: :search, pattern: "def handle_call(_, _, _) do _ end"},
      output: [%{file: "lib/exy/trajectory/store.ex", line: 35}],
      expanded?: true
    })
  end

  def story(:tool_lsp_diagnostics) do
    DSL.tool(%{
      id: "lsp-1",
      name: :elixir_lsp,
      status: :ok,
      args: %{action: :diagnostics, file: "lib/exy.ex"},
      output: [],
      expanded?: true
    })
  end

  def story(:footer_usage) do
    DSL.footer(%{
      cwd: File.cwd!(),
      session_id: "story-footer",
      model: "openai_codex:gpt-5.5",
      status: :idle,
      usage: %{total_tokens: 12_345}
    })
  end

  def story(:status_rows) do
    vertical do
      status(
        icon: Theme.symbol(Theme.default(), :success_icon),
        title: "Expert",
        description: "ready",
        color: :success
      )

      status(
        icon: Theme.symbol(Theme.default(), :error_icon),
        title: "Auth",
        description: "missing credentials",
        color: :error
      )

      status(
        icon: Theme.symbol(Theme.default(), :status_icon),
        title: "Runtime",
        description: "standalone BEAM",
        extra: "idle",
        color: :accent
      )
    end
  end

  def story(:section_header) do
    box("Tools", [
      horizontal([
        status(title: "elixir_eval", description: "runtime introspection", color: :accent),
        status(title: "elixir_ast", description: "syntax search", color: :accent),
        status(title: "elixir_lsp", description: "Expert gateway", color: :accent)
      ])
    ])
  end

  def story(:markdown_rich) do
    DSL.markdown("""
    # Markdown renderer

    Exy renders **bold**, *italic*, `inline code`, links like [MDEx](https://mdelixir.dev), quotes, lists, code blocks, and tables.

    > Streaming Markdown is parsed with MDEx, so partial LLM chunks stay renderable.

    - semantic TUI state
    - ANSI themed output
    - future LiveView renderer

    ```elixir
    Exy.LLM.stream("hello", on_result: &IO.write/1)
    ```

    | Feature | Status |
    |---|---|
    | headers | styled |
    | tables | framed |
    | code | highlighted |
    """)
  end

  def story(:markdown_streaming) do
    document =
      Exy.TUI.Markdown.new_stream()
      |> Exy.TUI.Markdown.put_chunk("## Partial stream\n\nThis has **bo")

    DSL.markdown(MDEx.to_markdown!(MDEx.Document.run(document)))
  end

  def story(:model_info) do
    DSL.model_info(
      model: "gpt-5.5",
      provider: "openai_codex",
      reasoning: "medium",
      context_percent: 88.5,
      subscription: "chatgpt",
      usage: %{total_tokens: 123_456, total_cost: 0.023}
    )
  end

  def story(:input) do
    textarea(
      title: "Prompt",
      value: "Use elixir_eval to inspect runtime info\nThen summarize the important findings.",
      cursor: 24,
      min_rows: 4,
      placeholder: "Ask Exy to change this project..."
    )
  end

  def story(:themes) do
    vertical do
      section("Dark", [textarea(title: "Prompt", value: "dark prompt", cursor: 4, min_rows: 2)])
      section("Light", [textarea(title: "Prompt", value: "light prompt", cursor: 5, min_rows: 2)])
    end
  end

  def story(:dialog) do
    DSL.dialog(
      "Resume Session",
      [
        DSL.status(icon: "1", title: "story-chat", description: "now", color: :accent),
        DSL.status(icon: "2", title: "previous-work", description: "2h", color: :muted)
      ],
      hint: "enter opens • esc cancels"
    )
  end

  def story(:diff) do
    DSL.diff(
      lines: [{:context, "def hello do"}, {:del, "  :old"}, {:add, "  :new"}, {:context, "end"}]
    )
  end

  @spec render(atom(), keyword()) :: [IO.chardata()]
  def render(name, opts \\ []) do
    width = Keyword.get(opts, :width, 100)
    theme = Keyword.get_lazy(opts, :theme, &Theme.default/0)

    case {name, story(name)} do
      {:themes, %Node{} = node} -> render_theme_story(node, width)
      {_name, %{body: _body} = view} -> Exy.TUI.Renderer.render(view, width, theme)
      {_name, %Node{} = node} -> Widget.render(node, width, theme)
    end
  end

  defp render_theme_story(%Node{children: [dark, light]}, width) do
    Exy.TUI.Lines.join(
      Widget.render(dark, width, Theme.dark()),
      Widget.render(light, width, Theme.light())
    )
  end

  @spec render_plain(atom(), keyword()) :: [String.t()]
  def render_plain(name, opts \\ []) do
    name
    |> render(opts)
    |> Enum.map(&Width.visible_text/1)
  end
end
