defmodule Vibe.Terminal.Snapshot do
  @moduledoc """
  Terminal-aware snapshots for ANSI/VT output.

  Uses Ghostty when available so cursor movement, carriage returns, wrapping,
  colors, and Unicode width are interpreted like a real terminal.
  """

  alias Ghostty.Terminal
  alias Vibe.ToolOutput

  @type t :: %{
          plain: String.t(),
          html: String.t() | nil,
          vt: String.t() | nil,
          cells: list() | nil,
          truncated?: boolean()
        }

  @spec from_ansi(iodata(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_ansi(data, opts \\ []) do
    if Code.ensure_loaded?(Terminal) do
      cols = Keyword.get(opts, :cols, 120)
      rows = Keyword.get(opts, :rows, 80)
      max_bytes = Keyword.get(opts, :max_bytes, ToolOutput.default_max_bytes())

      with {:ok, term} <- Terminal.start_link(cols: cols, rows: rows),
           :ok <- Terminal.write(term, data),
           {:ok, plain} <- Terminal.snapshot(term, :plain),
           {:ok, html} <- Terminal.snapshot(term, :html),
           {:ok, vt} <- Terminal.snapshot(term, :vt) do
        cells = Terminal.cells(term)
        GenServer.stop(term)

        limited = ToolOutput.limit_text(plain, max_bytes)

        {:ok,
         %{
           plain: limited,
           html: html,
           vt: vt,
           cells: cells,
           truncated?: byte_size(limited) != byte_size(plain)
         }}
      end
    else
      plain = data |> IO.iodata_to_binary() |> ToolOutput.limit_text()
      {:ok, %{plain: plain, html: nil, vt: nil, cells: nil, truncated?: true}}
    end
  end
end
