defmodule Vibe.TUI.Storybook do
  @moduledoc """
  Small storybook for TUI widgets and views.
  """

  use Vibe.TUI

  alias Vibe.Code.AST.Result
  alias Vibe.Model.Content
  alias Vibe.TUI
  alias Vibe.TUI.{Node}
  alias Vibe.Terminal.{Theme, Width}
  alias Vibe.TUI.Widget
  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.Event
  alias Vibe.UI.{Reducer, State, ViewModel}

  defmodule ToolExample do
    @moduledoc false
    defstruct [
      :args,
      :id,
      :name,
      :output,
      :status,
      expanded?: false,
      truncate?: true,
      output_parts: []
    ]
  end

  @sample_footer_tokens 12_345
  @sample_model_tokens 123_456

  @spec stories() :: [atom()]
  def stories do
    [
      :chat_basic,
      :tool_eval_ok,
      :tool_eval_preparing,
      :tool_eval_running,
      :tool_eval_ansi_output,
      :tool_eval_expanded,
      :tool_read_markdown,
      :tool_read_markdown_expanded,
      :tool_read_image,
      :tool_write_created_file,
      :tool_edit_diff,
      :chat_tool_stress,
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
      Event.new(
        :user_message_added,
        "story-chat",
        Vibe.Event.Message.user_added(text: "Inspect runtime info")
      )
    )
    |> Reducer.apply_event(
      Event.new(
        :assistant_message_added,
        "story-chat",
        Vibe.Event.Message.assistant_added(text: "Runtime looks healthy.")
      )
    )
    |> Reducer.apply_event(
      Event.new(
        :usage_updated,
        "story-chat",
        Vibe.Event.Model.usage_updated(%{
          input_tokens: 120,
          output_tokens: 32,
          total_tokens: 152
        })
      )
    )
    |> ViewModel.from_state()
  end

  def story(:tool_eval_ok) do
    TUI.tool(%ToolExample{
      id: "eval-1",
      name: :eval,
      status: :ok,
      args: %{code: "Vibe.OTP.runtime_info()"},
      output: "%{elixir: \"1.19.5\", process_count: 187}",
      expanded?: true
    })
  end

  def story(:tool_eval_preparing) do
    TUI.tool(%ToolExample{
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
    TUI.tool(%ToolExample{
      id: "eval-running",
      name: :eval,
      status: :running,
      args: %{
        code:
          ~S|task = Cmd.start(["sh", "-c", "for i in 1 2 3 4 5; do echo tick:$i; sleep 10; done"], timeout: 60_000)|,
        timeout: 60_000
      },
      output_parts: [
        %{
          output: 1..40 |> Enum.map(&["tick:", Integer.to_string(&1)]) |> join_lines(),
          format: :text
        }
      ]
    })
  end

  def story(:tool_eval_ansi_output) do
    TUI.tool(%ToolExample{
      id: "eval-ansi",
      name: :eval,
      status: :ok,
      args: %{code: ~S|Cmd.run(["sh", "-c", "printf '\e[31mred\e[0m\n'"] )|},
      output_parts: [
        %{
          output:
            "\e[31mred\e[0m normal\nstart\rfinal\n\e[2J\e[Hafter-clear\n\e]0;title\aafter-osc",
          format: :text
        }
      ]
    })
  end

  def story(:tool_eval_expanded) do
    TUI.tool(%ToolExample{
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
    TUI.tool(%ToolExample{
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

  def story(:tool_read_markdown_expanded) do
    :tool_read_markdown
    |> story()
    |> Map.update!(:props, &Map.put(&1, :truncate?, false))
  end

  def story(:tool_read_image) do
    TUI.tool(%ToolExample{
      id: "read-image",
      name: :read,
      status: :ok,
      args: %{path: "test/fixtures/images/two-by-two.png"},
      output: %{
        path: "test/fixtures/images/two-by-two.png",
        content_type: :image,
        mime_type: "image/png",
        size_bytes: 79,
        width: 2,
        height: 2,
        parts: [
          Content.text("Read image file [image/png]\n2x2"),
          Content.image(
            data: Base.encode64(File.read!("test/fixtures/images/two-by-two.png")),
            mime_type: "image/png",
            filename: "two-by-two.png",
            width: 2,
            height: 2
          )
        ]
      },
      expanded?: true
    })
  end

  def story(:tool_write_created_file) do
    TUI.tool(%ToolExample{
      id: "write-created",
      name: :write,
      status: :ok,
      args: %{path: "lib/my_app_web/live/dashboard_live.ex"},
      output: %{
        path: "lib/my_app_web/live/dashboard_live.ex",
        language: "elixir",
        change: %{
          path: "lib/my_app_web/live/dashboard_live.ex",
          old: "",
          new: """
          defmodule MyAppWeb.DashboardLive do
            use MyAppWeb, :live_view

            def mount(_params, _session, socket) do
              {:ok, assign(socket, count: 0, status: :ready)}
            end

            def handle_event("inc", _params, socket) do
              {:noreply, update(socket, :count, &(&1 + 1))}
            end
          end
          """
        }
      }
    })
  end

  def story(:tool_edit_diff) do
    TUI.tool(%ToolExample{
      id: "edit-diff",
      name: :edit,
      status: :ok,
      args: %{path: "lib/my_app_web/router.ex"},
      output: %{
        path: "lib/my_app_web/router.ex",
        language: "elixir",
        diff: """
        --- lib/my_app_web/router.ex
        +++ lib/my_app_web/router.ex
        @@
        -    get "/", PageController, :home
        +    live "/", DashboardLive, :index
        +    live "/metrics", MetricsLive, :index
        """
      }
    })
  end

  def story(:chat_tool_stress) do
    session_id = "story-stress"

    State.new(
      session_id: session_id,
      cwd: Path.join(System.user_home!(), "Development/vibe"),
      model: "openai_codex:gpt-5.5"
    )
    |> apply_events([
      Event.new(
        :user_message_added,
        session_id,
        Vibe.Event.Message.user_added(
          text: "Run the test matrix, inspect the README, and stop if it takes too long."
        )
      ),
      Event.new(:assistant_stream_started, session_id, Vibe.Event.AssistantStream.started()),
      Event.new(
        :tool_updated,
        session_id,
        tool_updated(
          id: "eval-matrix",
          name: :eval,
          args: %{
            code:
              ~S|for dir <- ~w(reach quickbeam volt phoenix_vapor phoenix_replay vue-pencil vize_ex oxc_ex) do
  path = "/Users/dannote/Development/#{dir}"
  Cmd.run(["mix", "test"], cd: path, timeout: 900_000)
end|,
            timeout: 900_000
          }
        )
      ),
      Event.new(
        :tool_started,
        session_id,
        tool_started(
          id: "eval-matrix",
          name: :eval,
          args: %{
            code:
              ~S|for dir <- ~w(reach quickbeam volt phoenix_vapor phoenix_replay vue-pencil vize_ex oxc_ex) do
  path = "/Users/dannote/Development/#{dir}"
  Cmd.run(["mix", "test"], cd: path, timeout: 900_000)
end|,
            timeout: 900_000
          }
        )
      ),
      Event.new(
        :tool_finished,
        session_id,
        tool_finished(
          id: "eval-matrix",
          name: :eval,
          args: %{
            code:
              ~S|for dir <- ~w(reach quickbeam volt phoenix_vapor phoenix_replay vue-pencil vize_ex oxc_ex) do
  path = "/Users/dannote/Development/#{dir}"
  Cmd.run(["mix", "test"], cd: path, timeout: 900_000)
end|,
            timeout: 900_000
          },
          output: %{
            output: project_status_lines(),
            output_format: :text,
            output_parts: [
              %{
                output: project_status_lines(),
                format: :text
              }
            ]
          }
        )
      ),
      Event.new(
        :tool_started,
        session_id,
        tool_started(
          id: "read-reach",
          name: :read,
          args: %{path: "/Users/dannote/Development/reach/README.md"}
        )
      ),
      Event.new(
        :tool_finished,
        session_id,
        tool_finished(
          id: "read-reach",
          name: :read,
          args: %{path: "/Users/dannote/Development/reach/README.md"},
          output: %{
            output: %{
              path: "/Users/dannote/Development/reach/README.md",
              language: "markdown",
              omitted_lines: 391,
              content:
                "# Reach\n\nProgram dependence graph.\n\n```elixir\nReach.graph(:demo)\n```"
            }
          }
        )
      ),
      Event.new(
        :assistant_aborted,
        session_id,
        Vibe.Event.AssistantStream.aborted(reason: "Cancelled.")
      ),
      Event.new(
        :usage_updated,
        session_id,
        Vibe.Event.Model.usage_updated(%{input_tokens: 12_000, output_tokens: 3_500})
      )
    ])
    |> ViewModel.from_state()
  end

  def story(:tool_ast_matches) do
    TUI.tool(%ToolExample{
      id: "ast-1",
      name: :ast,
      status: :ok,
      args: %{action: :search, pattern: "def handle_call(_, _, _) do _ end"},
      output: [%{file: "lib/vibe/trajectory/store.ex", line: 35}],
      expanded?: true
    })
  end

  def story(:tool_ast_replace) do
    TUI.tool(%ToolExample{
      id: "ast-replace-1",
      name: :ast,
      status: :ok,
      args: %{
        action: :replace,
        path: "lib/tic_tac_toe_web/router.ex",
        pattern: ~S|get "/", PageController, :home|,
        replacement: ~S|live "/", GameLive, :index|
      },
      output: %Result{
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
    TUI.tool(%ToolExample{
      id: "lsp-1",
      name: :lsp,
      status: :ok,
      args: %{action: :diagnostics, file: "lib/vibe.ex"},
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

    Vibe renders **bold**, *italic*, `inline code`, links like [MDEx](https://mdelixir.dev), quotes, lists, code blocks, and tables.

    > Streaming Markdown is parsed with MDEx, so partial LLM chunks stay renderable.

    - semantic TUI state
    - ANSI themed output
    - future LiveView renderer

    ```elixir
    Vibe.Model.Direct.stream("hello", on_result: &IO.write/1)
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
      Vibe.Terminal.Markdown.new_stream()
      |> Vibe.Terminal.Markdown.put_chunk("## Partial stream\n\nThis has **bo")

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
      placeholder: "Ask Vibe anything..."
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

  defp apply_events(state, events), do: Enum.reduce(events, state, &Reducer.apply_event(&2, &1))

  defp project_status_lines do
    1..24
    |> Enum.map(fn index ->
      [
        "project_",
        Integer.to_string(index),
        ": ",
        if(rem(index, 5) == 0, do: "FAILED", else: "ok")
      ]
    end)
    |> join_lines()
  end

  defp join_lines(lines), do: lines |> Enum.intersperse("\n") |> IO.iodata_to_binary()

  @spec render(atom(), keyword()) :: [IO.chardata()]
  def render(name, opts \\ []) do
    width = Keyword.get(opts, :width, 100)
    theme = Keyword.get_lazy(opts, :theme, &Theme.default/0)

    case {name, story(name)} do
      {:themes, %Node{} = node} -> render_theme_story(node, width)
      {_name, %{body: _body} = view} -> Vibe.TUI.Renderer.render(view, width, theme)
      {_name, %Node{} = node} -> Widget.render(node, width, theme)
    end
  end

  defp render_theme_story(%Node{children: [dark, light]}, width) do
    Vibe.Terminal.Lines.join(
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

  defp tool_started(opts), do: Vibe.Event.Tool.started(ToolEvent.started(opts))
  defp tool_updated(opts), do: Vibe.Event.Tool.updated(ToolEvent.preparing(opts))
  defp tool_finished(opts), do: Vibe.Event.Tool.finished(ToolEvent.finished(opts))
end
