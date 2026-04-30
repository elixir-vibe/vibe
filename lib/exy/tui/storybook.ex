defmodule Exy.TUI.Storybook do
  @moduledoc """
  Small storybook for TUI widgets and views.
  """

  use Exy.TUI

  alias Exy.TUI
  alias Exy.TUI.{Node, Theme, Widget, Width}
  alias Exy.UI.{Event, Reducer, State, ViewModel}

  @sample_footer_tokens 12_345
  @sample_model_tokens 123_456

  @spec stories() :: [atom()]
  def stories do
    [
      :chat_basic,
      :tool_eval_ok,
      :tool_eval_preparing,
      :tool_eval_running,
      :tool_eval_expanded,
      :tool_read_markdown,
      :tool_ast_matches,
      :tool_ast_replace,
      :tool_lsp_diagnostics,
      :footer_usage,
      :footer_plugin_status,
      :plugin_widget,
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
    TUI.tool(%{
      id: "eval-1",
      name: :eval,
      status: :ok,
      args: %{code: "Exy.OTP.runtime_info()"},
      output: "%{elixir: \"1.19.5\", process_count: 187}",
      expanded?: true
    })
  end

  def story(:tool_eval_preparing) do
    TUI.tool(%{
      id: "eval-preparing",
      name: :eval,
      status: :preparing,
      args: %{
        code:
          ~S|{:ok, job} = Cmd.start(["sh", "-c", "sleep 30; echo long-running-task-complete"], timeout: 60_000); long_task_info = %{id: job.id, pid: inspect(job.pid), output: Cmd.output(job)}|,
        timeout: 5_000
      }
    })
  end

  def story(:tool_eval_running) do
    TUI.tool(%{
      id: "eval-running",
      name: :eval,
      status: :running,
      args: %{
        code:
          ~S|task = Cmd.start(["sh", "-c", "for i in 1 2 3 4 5; do echo tick:$i; sleep 10; done"], timeout: 60_000)|,
        timeout: 60_000
      },
      output_parts: [%{output: Enum.map_join(1..40, "\n", &"tick:#{&1}"), format: :text}]
    })
  end

  def story(:tool_eval_expanded) do
    TUI.tool(%{
      id: "eval-expanded",
      name: :eval,
      status: :ok,
      args: %{
        code:
          ~S|projects = ~w(reach quickbeam volt phoenix_vapor phoenix_replay vue-pencil vize_ex oxc_ex)
for dir <- projects do
  path = "/Users/dannote/Development/#{dir}"
  IO.puts("== #{dir} ==")
end|,
        timeout: 60_000
      },
      output_parts: [%{output: "== reach ==\n3 properties, 484 tests, 0 failures", format: :text}],
      expanded?: true,
      truncate?: false
    })
  end

  def story(:tool_read_markdown) do
    TUI.tool(%{
      id: "read-markdown",
      name: :read,
      status: :ok,
      args: %{path: "/Users/dannote/Development/reach/README.md"},
      output: %{
        path: "/Users/dannote/Development/reach/README.md",
        language: "markdown",
        omitted_lines: 391,
        omitted_bytes: 602,
        content: """
        # Reach

        Program dependence graph for Elixir, Erlang, Gleam, JavaScript, and TypeScript.

        ```elixir
        defmodule Demo do
          use Reach
        end
        ```
        """
      }
    })
  end

  def story(:tool_ast_matches) do
    TUI.tool(%{
      id: "ast-1",
      name: :ast,
      status: :ok,
      args: %{action: :search, pattern: "def handle_call(_, _, _) do _ end"},
      output: [%{file: "lib/exy/trajectory/store.ex", line: 35}],
      expanded?: true
    })
  end

  def story(:tool_ast_replace) do
    TUI.tool(%{
      id: "ast-replace-1",
      name: :ast,
      status: :ok,
      args: %{
        action: :replace,
        path: "lib/tic_tac_toe_web/router.ex",
        pattern: ~S|get "/", PageController, :home|,
        replacement: ~S|live "/", GameLive, :index|
      },
      output: %Exy.Code.AST.Result{
        action: :replace,
        path: "lib/tic_tac_toe_web/router.ex",
        pattern: ~S|get "/", PageController, :home|,
        replacement: ~S|live "/", GameLive, :index|,
        dry_run: false,
        result: [{"lib/tic_tac_toe_web/router.ex", 1}],
        diff: [
          %{
            path: "lib/tic_tac_toe_web/router.ex",
            diff:
              ~s|--- lib/tic_tac_toe_web/router.ex\n+++ lib/tic_tac_toe_web/router.ex\n@@\n-    get "/", PageController, :home\n+    live "/", GameLive, :index|
          }
        ]
      },
      expanded?: true
    })
  end

  def story(:tool_lsp_diagnostics) do
    TUI.tool(%{
      id: "lsp-1",
      name: :lsp,
      status: :ok,
      args: %{action: :diagnostics, file: "lib/exy.ex"},
      output: [],
      expanded?: true
    })
  end

  def story(:footer_usage) do
    TUI.footer(%{
      cwd: File.cwd!(),
      session_id: "story-footer",
      model: "openai_codex:gpt-5.5",
      status: :idle,
      usage: %{total_tokens: @sample_footer_tokens}
    })
  end

  def story(:footer_plugin_status) do
    TUI.footer(%{
      cwd: File.cwd!(),
      session_id: "story-footer",
      model: "openai_codex:gpt-5.5",
      status: :idle,
      usage: %{total_tokens: @sample_footer_tokens},
      plugin_statuses: %{
        "git" => " main",
        "worker" => "background index ready",
        "model" => "🤖 gpt-5.5"
      }
    })
  end

  def story(:plugin_widget) do
    plugin_widget(%{
      id: "indexer",
      type: :progress,
      placement: :above_editor,
      props: %{
        title: "Indexer",
        current: 3,
        total: 8,
        message: "embeddings warm"
      }
    })
  end

  def story(:status_rows) do
    vertical([
      status(
        icon: Theme.symbol(Theme.default(), :success_icon),
        title: "Expert",
        description: "ready",
        color: :success
      ),
      status(
        icon: Theme.symbol(Theme.default(), :error_icon),
        title: "Auth",
        description: "missing credentials",
        color: :error
      ),
      status(
        icon: Theme.symbol(Theme.default(), :status_icon),
        title: "Runtime",
        description: "standalone BEAM",
        extra: "idle",
        color: :accent
      )
    ])
  end

  def story(:section_header) do
    box("Tools", [
      horizontal([
        status(title: "eval", description: "runtime introspection", color: :accent),
        status(title: "ast", description: "syntax search", color: :accent),
        status(title: "lsp", description: "Expert gateway", color: :accent)
      ])
    ])
  end

  def story(:markdown_rich) do
    TUI.markdown("""
    # Markdown renderer

    Exy renders **bold**, *italic*, `inline code`, links like [MDEx](https://mdelixir.dev), quotes, lists, code blocks, and tables.

    > Streaming Markdown is parsed with MDEx, so partial LLM chunks stay renderable.

    - semantic TUI state
    - ANSI themed output
    - future LiveView renderer

    ```elixir
    Exy.Model.Direct.stream("hello", on_result: &IO.write/1)
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

    TUI.markdown(MDEx.to_markdown!(MDEx.Document.run(document)))
  end

  def story(:model_info) do
    TUI.model_info(
      model: "gpt-5.5",
      provider: "openai_codex",
      reasoning: "medium",
      context_percent: 88.5,
      subscription: "chatgpt",
      usage: %{total_tokens: @sample_model_tokens, total_cost: 0.023}
    )
  end

  def story(:input) do
    textarea(
      title: "Prompt",
      value: "Use eval to inspect runtime info\nThen summarize the important findings.",
      cursor: 24,
      min_rows: 4,
      placeholder: "Ask Exy to change this project..."
    )
  end

  def story(:themes) do
    vertical([
      section("Dark", [textarea(title: "Prompt", value: "dark prompt", cursor: 4, min_rows: 2)]),
      section("Light", [textarea(title: "Prompt", value: "light prompt", cursor: 5, min_rows: 2)])
    ])
  end

  def story(:dialog) do
    TUI.dialog(
      "Resume Session",
      [
        TUI.status(icon: "1", title: "story-chat", description: "now", color: :accent),
        TUI.status(icon: "2", title: "previous-work", description: "2h", color: :muted)
      ],
      hint: "enter opens • esc cancels"
    )
  end

  def story(:diff) do
    TUI.diff(
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
