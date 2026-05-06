defmodule Vibe.Web.Components.API do
  @moduledoc "Components for rendering plugin and skill eval API details."
  use Phoenix.Component

  attr(:apis, :list, required: true)

  def api_sections(assigns) do
    ~H"""
    <div :if={@apis == []} class="text-sm text-vibe-dim">No eval APIs exposed.</div>
    <div :if={@apis != []} class="space-y-4">
      <article :for={api <- @apis} class="rounded-lg border border-vibe-border/40 bg-vibe-bg/55 p-4">
        <div class="flex flex-wrap items-center gap-2">
          <span class="rounded bg-vibe-accent/10 px-2 py-1 font-mono text-sm text-vibe-accent-strong">{api.alias}</span>
          <span class="break-words font-mono text-xs text-vibe-dim [overflow-wrap:anywhere]">{inspect(api.module)}</span>
        </div>
        <p :if={api.description not in [nil, ""]} class="mt-2 text-sm leading-6 text-vibe-fg">{api.description}</p>
        <pre :if={api.examples != []} class="mt-3 whitespace-pre-wrap rounded-md bg-vibe-code p-3 font-mono text-xs leading-5 text-vibe-muted">{Enum.join(api.examples, "\n")}</pre>

        <section class="mt-4">
          <h3 class="text-xs font-semibold uppercase tracking-[0.16em] text-vibe-dim">Functions</h3>
          <div class="mt-2 space-y-2">
            <div :for={function <- api_functions(api.module)} class="rounded-md border border-vibe-border/40 bg-vibe-surface-muted/20 p-3">
              <p class="font-mono text-sm text-vibe-fg-strong">{function.name}/{function.arity}</p>
              <p :if={function.doc} class="mt-2 text-sm leading-6 text-vibe-muted">{function.doc}</p>
              <p :if={!function.doc} class="mt-2 text-sm text-vibe-dim">No docs.</p>
            </div>
          </div>
        </section>
      </article>
    </div>
    """
  end

  defp api_functions(module) do
    docs = docs_by_function(module)

    module
    |> public_functions()
    |> Enum.map(fn {name, arity} ->
      %{name: name, arity: arity, doc: Map.get(docs, {name, arity})}
    end)
  end

  defp public_functions(module) do
    if Code.ensure_loaded?(module) do
      module.__info__(:functions)
      |> Enum.reject(fn {name, _arity} -> name in [:__info__, :module_info] end)
      |> Enum.sort()
    else
      []
    end
  end

  defp docs_by_function(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        docs
        |> Map.new(fn
          {{:function, name, arity}, _anno, _signature, doc, _metadata} ->
            {{name, arity}, doc_text(doc)}

          {_, _, _, _, _} ->
            {nil, nil}
        end)
        |> Map.delete(nil)

      _other ->
        %{}
    end
  end

  defp doc_text(:none), do: nil
  defp doc_text(:hidden), do: nil
  defp doc_text(%{"en" => text}) when is_binary(text), do: first_paragraph(text)
  defp doc_text(text) when is_binary(text), do: first_paragraph(text)
  defp doc_text(_doc), do: nil

  defp first_paragraph(text) do
    text
    |> String.trim()
    |> String.split(~r/\n\s*\n/, parts: 2)
    |> List.first()
  end
end
