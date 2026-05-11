defmodule Vibe.Web.Assets do
  @moduledoc "Builds web assets using Volt's configured JS bundler and Tailwind compiler."

  @spec ensure_built!() :: :ok
  def ensure_built! do
    if Code.ensure_loaded?(Volt.Builder) do
      build_tailwind!()
      build_javascript!()
    end

    :ok
  end

  defp build_javascript! do
    config = Volt.Config.build()

    case Volt.Builder.build(
           entry: config.entry,
           outdir: to_string(config.outdir),
           target: config.target,
           hash: config.hash,
           sourcemap: false,
           format: config.format,
           external: config.external,
           resolve_dirs: config.resolve_dirs,
           aliases: config.aliases,
           plugins: config.plugins,
           minify: false
         ) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Volt JS build failed: #{inspect(reason)}"
    end
  end

  defp build_tailwind! do
    tw = Volt.Config.tailwind()
    css_path = Keyword.get(tw, :css)

    if css_path do
      outdir = Volt.Config.build().outdir |> to_string()
      File.mkdir_p!(outdir)

      case Volt.Tailwind.build(
             css: File.read!(css_path),
             css_base: Path.dirname(css_path),
             sources: Keyword.get(tw, :sources, [])
           ) do
        {:ok, css} -> File.write!(Path.join(outdir, "app.css"), css)
        {:error, reason} -> raise "Volt Tailwind build failed: #{inspect(reason)}"
      end
    end
  end
end
