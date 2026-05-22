{output, status} = System.cmd("mix", ["reach.check", "--candidates", "--format", "json"], stderr_to_stdout: true)

if status != 0 do
  IO.write(output)
  System.halt(status)
end

case Jason.decode(output) do
  {:ok, %{"candidates" => candidates}} ->
    cycle_candidates = Enum.filter(candidates, &(&1["kind"] == "break_cycle"))

    if cycle_candidates == [] do
      IO.puts("Reach cycle candidate gate: OK")
    else
      IO.puts("Reach cycle candidate gate: #{length(cycle_candidates)} break_cycle candidate(s)")

      Enum.each(cycle_candidates, fn candidate ->
        IO.puts("- #{candidate["id"]} #{candidate["target"] || candidate["file"]}:#{candidate["line"]}")
      end)

      System.halt(1)
    end

  {:ok, decoded} ->
    IO.inspect(decoded, label: "unexpected reach output")
    System.halt(1)

  {:error, reason} ->
    IO.write(output)
    IO.puts("Failed to decode Reach candidates JSON: #{inspect(reason)}")
    System.halt(1)
end
