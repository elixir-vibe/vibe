defmodule Vibe.Web.ArtifactController do
  @moduledoc "Serves local session artifact files to the web UI."
  use Phoenix.Controller, formats: [:html]

  alias Plug.Conn
  alias Vibe.Files.Artifacts

  def show(conn, %{"session_id" => session_id, "path" => path_parts}) do
    relative_path = Path.join(List.wrap(path_parts))

    with :ok <- validate_session_id(session_id),
         {:ok, path} <- Artifacts.resolve_session_artifact(session_id, relative_path),
         true <- File.regular?(path) do
      conn
      |> Conn.put_resp_content_type(MIME.from_path(path))
      |> Conn.send_file(200, path)
    else
      {:error, :invalid_session_id} -> Conn.send_resp(conn, 404, "not found")
      {:error, :invalid_artifact_path} -> Conn.send_resp(conn, 404, "not found")
      false -> Conn.send_resp(conn, 404, "not found")
    end
  end

  defp validate_session_id(session_id) when is_binary(session_id) do
    if String.match?(session_id, ~r/^[A-Za-z0-9._-]+$/),
      do: :ok,
      else: {:error, :invalid_session_id}
  end

  defp validate_session_id(_session_id), do: {:error, :invalid_session_id}
end
