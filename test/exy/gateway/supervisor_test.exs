defmodule Exy.Gateway.SupervisorTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.Supervisor, as: GatewaySupervisor

  defmodule Backend do
    @behaviour Exy.Gateway.Backend

    defstruct [:token]

    @impl true
    def load_config(opts), do: {:ok, struct!(__MODULE__, opts)}

    @impl true
    def normalize(_update, _config), do: :ignore

    @impl true
    def authorized?(_message, _trigger, _config), do: true

    @impl true
    def outbound_adapter(_config), do: Exy.Gateway.Telegram.Adapter

    @impl true
    def child_specs(_config, runtime) do
      [
        %{
          id: :probe,
          start: {Agent, :start_link, [fn -> runtime end]}
        }
      ]
    end
  end

  test "starts generic runtime and backend-owned children" do
    runtime_name = unique_name()

    assert {:ok, supervisor} =
             GatewaySupervisor.start_link(
               gateways: [
                 [
                   id: :telegram,
                   backend: Backend,
                   backend_opts: [token: "token"],
                   runtime_name: runtime_name
                 ]
               ]
             )

    children = Supervisor.which_children(supervisor)

    assert Enum.any?(children, fn {id, _pid, _type, _modules} ->
             id == {:gateway_runtime, :telegram}
           end)

    assert Enum.any?(children, fn {id, _pid, _type, _modules} -> id == :probe end)
    assert Process.whereis(runtime_name)
  end

  defp unique_name do
    Module.concat(__MODULE__, "Runtime#{System.unique_integer([:positive])}")
  end
end
