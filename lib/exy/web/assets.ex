defmodule Exy.Web.Assets do
  @moduledoc false

  @spec ensure_built!() :: :ok
  def ensure_built! do
    build_tailwind!()
    :ok
  end

  defp build_tailwind! do
    if Code.ensure_loaded?(Volt.Tailwind) do
      outdir = Application.app_dir(:exy, "priv/static/assets")
      File.mkdir_p!(outdir)

      case Volt.Tailwind.build(
             css: File.read!("assets/web/app.css"),
             css_base: Path.expand("assets/web"),
             sources: [
               %{base: "lib/", pattern: "**/*.{ex,heex}"},
               %{base: "assets/", pattern: "**/*.{ts,css}"}
             ]
           ) do
        {:ok, css} -> File.write!(Path.join(outdir, "app.css"), css)
        {:error, reason} -> raise "failed to build Tailwind CSS: #{inspect(reason)}"
      end
    end
  end
end
