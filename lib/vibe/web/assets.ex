defmodule Vibe.Web.Assets do
  @moduledoc "Web static asset paths for the Vibe endpoint."

  @static_paths ~w(assets fonts images favicon.ico robots.txt)
  @required_assets ~w(assets/css/app.css assets/js/manifest.json)

  @spec static_paths() :: [String.t()]
  def static_paths, do: @static_paths

  @spec ensure_built!() :: :ok
  def ensure_built! do
    if Enum.all?(@required_assets, &File.exists?(priv_static_path(&1))) do
      :ok
    else
      raise "Web assets are missing. Run `mix assets.build` before packaging Vibe."
    end
  end

  defp priv_static_path(path), do: Application.app_dir(:vibe, Path.join("priv/static", path))
end
