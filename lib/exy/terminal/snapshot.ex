defmodule Exy.Terminal.Snapshot do
  @moduledoc """
  Terminal-aware snapshots for ANSI/VT output.

  Uses Ghostty when available so cursor movement, carriage returns, wrapping,
  colors, and Unicode width are interpreted like a real terminal.
  """

  @type t :: %{
          plain: String.t(),
          html: String.t() | nil,
          vt: String.t() | nil,
          cells: list() | nil,
          truncated?: boolean()
        }

  @spec from_ansi(iodata(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_ansi(data, opts \\ []) do
    if Code.ensure_loaded?(Ghostty.Terminal) do
      cols = Keyword.get(opts, :cols, 120)
      rows = Keyword.get(opts, :rows, 80)
      max_bytes = Keyword.get(opts, :max_bytes, Exy.ToolOutput.default_max_bytes())

      with {:ok, term} <- Ghostty.Terminal.start_link(cols: cols, rows: rows),
           :ok <- Ghostty.Terminal.write(term, data),
           {:ok, plain} <- Ghostty.Terminal.snapshot(term, :plain),
           {:ok, html} <- Ghostty.Terminal.snapshot(term, :html),
           {:ok, vt} <- Ghostty.Terminal.snapshot(term, :vt) do
        cells = Ghostty.Terminal.cells(term)
        GenServer.stop(term)

        limited = Exy.ToolOutput.limit_text(plain, max_bytes)

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
      plain = data |> IO.iodata_to_binary() |> Exy.ToolOutput.limit_text()
      {:ok, %{plain: plain, html: nil, vt: nil, cells: nil, truncated?: true}}
    end
  end
end
