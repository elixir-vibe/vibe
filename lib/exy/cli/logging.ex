defmodule Exy.CLI.Logging do
  @moduledoc false

  @spec with_session_log(String.t() | nil, (-> term())) :: term()
  def with_session_log(session_id, fun) do
    handlers = console_handlers()
    log_handler = attach_session_log(session_id)

    Enum.each(handlers, fn {handler, _level} ->
      :logger.set_handler_config(handler, :level, :emergency)
    end)

    try do
      fun.()
    after
      Enum.each(handlers, fn {handler, level} ->
        :logger.set_handler_config(handler, :level, level)
      end)

      detach_session_log(log_handler)
    end
  end

  defp attach_session_log(nil), do: nil

  defp attach_session_log(session_id) do
    path = Exy.Session.Store.log_path(session_id)
    File.mkdir_p!(Path.dirname(path))
    _ = :logger.remove_handler(:exy_session_log)

    case :logger.add_handler(:exy_session_log, :logger_std_h, %{
           level: :debug,
           config: %{type: {:file, String.to_charlist(path)}}
         }) do
      :ok -> :exy_session_log
      {:error, _reason} -> nil
    end
  end

  defp detach_session_log(nil), do: :ok
  defp detach_session_log(handler), do: :logger.remove_handler(handler)

  defp console_handlers do
    :logger.get_handler_ids()
    |> Enum.flat_map(fn handler ->
      case :logger.get_handler_config(handler) do
        {:ok, %{module: :logger_std_h, config: %{type: type}, level: level}}
        when type in [:standard_io, :standard_error] ->
          [{handler, level}]

        _ ->
          []
      end
    end)
  end
end
