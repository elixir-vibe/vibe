defmodule Exy.Dogfood.TUI do
  @moduledoc false

  require Exy.Debug

  @type result :: %{
          name: String.t(),
          status: :pass | :fail,
          trace_dir: Path.t(),
          final_frame: String.t() | nil,
          error: String.t() | nil
        }

  @scenarios [
    "cancel_notice",
    "clear_confirmation",
    "autocomplete_footer",
    "loader_tick"
  ]

  @spec scenarios() :: [String.t()]
  def scenarios, do: @scenarios

  if Exy.Debug.enabled?() do
    alias Exy.TUI.{TerminalLoop, Width}

    @spec run(keyword()) :: {:ok, [result()]}
    def run(opts \\ []) do
      selected = Keyword.get(opts, :scenario, "all")
      names = scenario_names(selected)
      root = Keyword.get_lazy(opts, :dir, &default_dir/0)
      File.mkdir_p!(root)

      results = Enum.map(names, &run_scenario(&1, root, opts))
      write_report(root, results)
      {:ok, results}
    end

    defp scenario_names("all"), do: @scenarios
    defp scenario_names(name) when name in @scenarios, do: [name]
    defp scenario_names(name), do: raise(ArgumentError, "unknown TUI dogfood scenario: #{name}")

    defp run_scenario(name, root, opts) do
      trace_dir = Path.join(root, name)
      File.rm_rf!(trace_dir)
      do_run_scenario(name, trace_dir, opts)
    end

    defp do_run_scenario(name, trace_dir, opts) do
      case dispatch(name, trace_dir, opts) do
        {:ok, loop} ->
          final_frame = write_final_frame(trace_dir, loop)

          %{
            name: name,
            status: :pass,
            trace_dir: trace_dir,
            final_frame: final_frame,
            error: nil
          }

        {:error, reason, loop} ->
          final_frame = if loop, do: write_final_frame(trace_dir, loop), else: nil

          %{
            name: name,
            status: :fail,
            trace_dir: trace_dir,
            final_frame: final_frame,
            error: Exception.format(:error, reason)
          }
      end
    rescue
      error ->
        %{
          name: name,
          status: :fail,
          trace_dir: trace_dir,
          final_frame: nil,
          error: Exception.format(:error, error, __STACKTRACE__)
        }
    catch
      kind, reason ->
        %{
          name: name,
          status: :fail,
          trace_dir: trace_dir,
          final_frame: nil,
          error: Exception.format(kind, reason, __STACKTRACE__)
        }
    end

    defp dispatch("cancel_notice", trace_dir, _opts), do: cancel_notice(trace_dir)
    defp dispatch("clear_confirmation", trace_dir, _opts), do: clear_confirmation(trace_dir)
    defp dispatch("autocomplete_footer", trace_dir, _opts), do: autocomplete_footer(trace_dir)
    defp dispatch("loader_tick", trace_dir, _opts), do: loader_tick(trace_dir)

    defp cancel_notice(trace_dir) do
      {:ok, loop} =
        TerminalLoop.start_link(
          output: false,
          width: 80,
          height: 24,
          persist?: false,
          trace_dir: trace_dir,
          ask_fun: fn _text, _opts ->
            Process.sleep(5_000)
            {:ok, "ok"}
          end
        )

      :ok = TerminalLoop.input(loop, "hello")
      :ok = TerminalLoop.input_key(loop, key(:enter))
      Process.sleep(100)
      :ok = TerminalLoop.input_key(loop, key(:escape))

      plain = wait_until_render(loop, &contains?(&1, "! cancelled"))
      assert_gap_between(plain, "hello", "! cancelled")
      {:ok, loop}
    rescue
      error -> {:error, error, binding()[:loop]}
    end

    defp clear_confirmation(trace_dir) do
      {:ok, loop} =
        TerminalLoop.start_link(
          output: false,
          width: 80,
          height: 30,
          persist?: false,
          trace_dir: trace_dir,
          ask_fun: fn _text, _opts -> {:ok, "ok"} end
        )

      :ok = TerminalLoop.input(loop, "hello")
      :ok = TerminalLoop.input_key(loop, key(:enter))
      plain = wait_until_render(loop, &contains?(&1, "ok"))
      assert_contains!(plain, "hello")

      :ok = TerminalLoop.input(loop, "/clear")
      :ok = TerminalLoop.input_key(loop, key(:enter))
      plain = wait_until_render(loop, &contains?(&1, "Clear session?"))

      assert_contains!(plain, "hello")
      assert_contains!(plain, "→ Yes")
      assert_before!(plain, "Clear session?", "Prompt")
      assert_adjacent!(plain, "openai_codex:gpt-5.5", "Prompt")
      {:ok, loop}
    rescue
      error -> {:error, error, binding()[:loop]}
    end

    defp autocomplete_footer(trace_dir) do
      {:ok, loop} =
        TerminalLoop.start_link(
          output: false,
          width: 80,
          height: 20,
          persist?: false,
          trace_dir: trace_dir
        )

      :ok = TerminalLoop.input(loop, "/se")
      plain = wait_until_render(loop, &contains?(&1, "/sessions"))

      assert_before!(plain, "/sessions", "openai_codex:gpt-5.5")
      assert_adjacent!(plain, "openai_codex:gpt-5.5", "Prompt")
      {:ok, loop}
    rescue
      error -> {:error, error, binding()[:loop]}
    end

    defp loader_tick(trace_dir) do
      {:ok, loop} =
        TerminalLoop.start_link(
          output: false,
          width: 80,
          height: 20,
          persist?: false,
          trace_dir: trace_dir,
          event_target: self()
        )

      session_id =
        loop
        |> :sys.get_state()
        |> Map.fetch!(:app)
        |> Exy.TUI.App.snapshot()
        |> Map.fetch!(:ui)
        |> Map.fetch!(:session_id)

      :ok = Exy.UI.Bus.emit(session_id, :assistant_stream_started, %{})

      receive do
        {TerminalLoop, :event, :loader_tick} -> :ok
      after
        500 -> raise "loader tick did not fire"
      end

      plain = render_plain(loop)

      unless Enum.any?(plain, &String.contains?(&1, "Thinking")) do
        raise "loader frame did not render Thinking"
      end

      {:ok, loop}
    rescue
      error -> {:error, error, binding()[:loop]}
    end

    defp write_final_frame(trace_dir, loop) do
      path = Path.join(trace_dir, "final-frame.txt")
      loop |> render_plain() |> Enum.join("\n") |> then(&File.write!(path, &1))
      path
    end

    defp write_report(root, results) do
      report = %{
        dir: root,
        commit: git_commit(),
        generated_at: DateTime.utc_now(),
        results: results,
        summary: %{
          total: length(results),
          passed: Enum.count(results, &(&1.status == :pass)),
          failed: Enum.count(results, &(&1.status == :fail))
        }
      }

      File.write!(Path.join(root, "report.json"), Jason.encode!(json_safe(report), pretty: true))
      File.write!(Path.join(root, "report.md"), markdown_report(report))
    end

    defp markdown_report(report) do
      rows =
        Enum.map(report.results, fn result ->
          status = if result.status == :pass, do: "PASS", else: "FAIL"
          "| #{status} | #{result.name} | `#{result.trace_dir}` | #{result.error || ""} |"
        end)

      Enum.join(
        [
          "# Exy TUI dogfood",
          "",
          "Commit: `#{report.commit || "-"}`",
          "",
          "Passed: #{report.summary.passed}/#{report.summary.total}",
          "",
          "| Status | Scenario | Trace | Error |",
          "| --- | --- | --- | --- |"
          | rows
        ],
        "\n"
      )
    end

    defp render_plain(loop),
      do: loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    defp wait_until_render(
           loop,
           predicate,
           deadline \\ System.monotonic_time(:millisecond) + 1_000
         ) do
      plain = render_plain(loop)

      cond do
        predicate.(plain) ->
          plain

        System.monotonic_time(:millisecond) >= deadline ->
          raise "timed out waiting for render predicate\n\n#{Enum.join(plain, "\n")}"

        true ->
          Process.sleep(10)
          wait_until_render(loop, predicate, deadline)
      end
    end

    defp assert_contains!(plain, text) do
      unless contains?(plain, text), do: raise("expected frame to contain #{inspect(text)}")
    end

    defp assert_before!(plain, first, second) do
      first_index = index_of(plain, first)
      second_index = index_of(plain, second)

      unless first_index && second_index && first_index < second_index do
        raise "expected #{inspect(first)} before #{inspect(second)}"
      end
    end

    defp assert_adjacent!(plain, first, second) do
      first_index = index_of(plain, first)
      second_index = index_of(plain, second)

      unless first_index && second_index && second_index == first_index + 1 do
        raise "expected #{inspect(first)} directly above #{inspect(second)}"
      end
    end

    defp assert_gap_between(plain, first, second) do
      first_index = index_of(plain, first)
      second_index = index_of(plain, second)

      unless first_index && second_index do
        raise "expected #{inspect(first)} and #{inspect(second)} in frame"
      end

      has_gap? =
        plain
        |> Enum.slice((first_index + 1)..(second_index - 1)//1)
        |> Enum.any?(&(String.trim(&1) == ""))

      unless has_gap?,
        do: raise("expected a blank line between #{inspect(first)} and #{inspect(second)}")
    end

    defp contains?(plain, text), do: Enum.any?(plain, &String.contains?(&1, text))

    defp index_of(plain, text), do: Enum.find_index(plain, &String.contains?(&1, text))

    defp key(key), do: %Ghostty.KeyEvent{key: key}

    defp default_dir do
      timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
      Path.join([System.tmp_dir!(), "exy-dogfood", timestamp])
    end

    defp git_commit do
      case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
        {commit, 0} -> String.trim(commit)
        _result -> nil
      end
    end

    defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
    defp json_safe(%_struct{} = value), do: value |> Map.from_struct() |> json_safe()

    defp json_safe(map) when is_map(map),
      do: Map.new(map, fn {key, value} -> {key, json_safe(value)} end)

    defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
    defp json_safe(value), do: value
  else
    @spec run(keyword()) :: {:error, :debug_not_compiled}
    def run(_opts \\ []), do: {:error, :debug_not_compiled}
  end
end
