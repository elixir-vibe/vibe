defmodule Vibe.Plugins.Safety.Patterns do
  @moduledoc """
  Safety checks for potentially destructive commands.

  Returns a warning label when a command matches a known dangerous pattern.
  The caller decides whether to prompt for confirmation or proceed.
  """

  @patterns [
    {~r/\bgh\s+pr\s+create\b/, "Create GitHub PR"},
    {~r/\bgh\s+issue\s+create\b/, "Create GitHub issue"},
    {~r/\bgh\s+pr\s+comment\b/, "Comment on GitHub PR"},
    {~r/\bgh\s+issue\s+comment\b/, "Comment on GitHub issue"},
    {~r/\bgh\s+pr\s+review\b/, "Submit GitHub PR review"},
    {~r/\bgh\s+pr\s+merge\b/, "Merge GitHub PR"},
    {~r/\bglab\s+mr\s+create\b/, "Create GitLab MR"},
    {~r/\bglab\s+issue\s+create\b/, "Create GitLab issue"},
    {~r/\bglab\s+mr\s+note\b/, "Comment on GitLab MR"},
    {~r/\bglab\s+mr\s+merge\b/, "Merge GitLab MR"},
    {~r/\bgit\s+push\s+.*--force\b/, "Force push"},
    {~r/\bgit\s+push\s+.*-f\b/, "Force push"},
    {~r/\brm\s+-rf\s+\//, "Delete from root"},
    {~r/\bsudo\b/, "Run as root"},
    {~r/\bdropdb\b/, "Drop database"},
    {~r/DROP\s+(TABLE|DATABASE)\b/i, "Drop database object"}
  ]

  @spec check_command(String.t()) :: {:ok, String.t()} | :safe
  def check_command(command) when is_binary(command) do
    Enum.find_value(@patterns, :safe, fn {pattern, label} ->
      if Regex.match?(pattern, command), do: {:ok, label}
    end)
  end

  @spec dangerous?(String.t()) :: boolean()
  def dangerous?(command), do: check_command(command) != :safe
end
