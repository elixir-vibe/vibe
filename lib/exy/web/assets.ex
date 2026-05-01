defmodule Exy.Web.Assets do
  @moduledoc "Internal implementation module."
  @spec ensure_built!() :: :ok
  def ensure_built! do
    build_tailwind!()
    build_javascript!()
    :ok
  end

  defp build_javascript! do
    if Code.ensure_loaded?(Volt.Builder) do
      outdir = Application.app_dir(:exy, "priv/static/assets")
      File.mkdir_p!(outdir)

      case Volt.Builder.build(
             entry: "assets/web/app.ts",
             outdir: outdir,
             name: "app",
             hash: false,
             sourcemap: false,
             format: :iife,
             resolve_dirs: ["deps"]
           ) do
        {:ok, _result} -> :ok
        {:error, reason} -> raise "failed to build web JavaScript with Volt: #{inspect(reason)}"
      end
    end
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
