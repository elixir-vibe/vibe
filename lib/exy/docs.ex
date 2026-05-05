defmodule Exy.Docs do
  @moduledoc """
  Built-in task-focused documentation for Exy users.

  These docs are short operational guides intended for `exy help`, TUI help,
  and eval rendering. API contracts stay in module docs; the README stays focused
  on first-run orientation.
  """

  @topics [
    {"quickstart", "Quickstart"},
    {"sessions", "Sessions"},
    {"eval", "Eval"},
    {"ast", "AST"},
    {"lsp", "LSP"},
    {"slash-commands", "Slash commands"},
    {"memory", "Memory"},
    {"subagents", "Subagents"},
    {"plugins", "Plugins"},
    {"storage", "Storage"},
    {"web", "Web"},
    {"troubleshooting", "Troubleshooting"}
  ]

  @topic_titles Map.new(@topics)

  @aliases %{
    "commands" => "slash-commands",
    "slash" => "slash-commands",
    "help" => "quickstart",
    "session" => "sessions",
    "subagent" => "subagents",
    "plugin" => "plugins",
    "search" => "web",
    "fetch" => "web",
    "code" => "ast",
    "code-intelligence" => "lsp"
  }

  @doc "Returns the built-in help topic names and titles."
  @spec topics() :: [%{name: String.t(), title: String.t()}]
  def topics do
    Enum.map(@topics, fn {name, title} -> %{name: name, title: title} end)
  end

  @doc "Returns Markdown for a built-in help topic."
  @spec read(String.t() | atom() | nil) ::
          {:ok, String.t()} | {:error, {:unknown_topic, String.t()}}
  def read(topic \\ "quickstart") do
    topic = normalize_topic(topic)

    case Map.fetch(@topic_titles, topic) do
      {:ok, _title} -> File.read(topic_path(topic))
      :error -> {:error, {:unknown_topic, topic}}
    end
  end

  @doc "Returns Markdown listing all built-in help topics."
  @spec index() :: String.t()
  def index do
    topic_lines =
      Enum.map_join(topics(), "\n", fn %{name: name, title: title} -> "- `#{name}` — #{title}" end)

    """
    # Exy help

    Usage:

    ```bash
    exy help <topic>
    ```

    Topics:

    #{topic_lines}
    """
  end

  @doc "Returns Markdown for a topic, or the index when the topic is missing or unknown."
  @spec render(String.t() | atom() | nil) :: String.t()
  def render(nil), do: index()
  def render(""), do: index()

  def render(topic) do
    case read(topic) do
      {:ok, markdown} -> markdown
      {:error, {:unknown_topic, unknown}} -> unknown_topic(unknown)
    end
  end

  defp unknown_topic(topic) do
    """
    # Unknown help topic

    No built-in help topic named `#{topic}`.

    #{index()}
    """
  end

  defp normalize_topic(nil), do: "quickstart"

  defp normalize_topic(topic) do
    topic
    |> to_string()
    |> String.trim()
    |> String.trim_leading("/")
    |> String.downcase()
    |> then(&Map.get(@aliases, &1, &1))
  end

  defp topic_path(topic), do: Path.join(docs_dir(), topic <> ".md")

  defp docs_dir, do: Application.app_dir(:exy, "priv/docs")
end
