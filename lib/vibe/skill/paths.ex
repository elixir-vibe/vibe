defmodule Vibe.Skill.Paths do
  @moduledoc false

  @spec script_paths() :: [String.t()]
  def script_paths do
    [
      Application.app_dir(:vibe, "priv/skills"),
      Path.join(File.cwd!(), "skills"),
      Path.join([File.cwd!(), ".vibe", "skills"]),
      Vibe.Paths.skills_dir()
    ]
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end
end
