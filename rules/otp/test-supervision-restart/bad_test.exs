# EXPECTED: passes
# BAD PRACTICE: "Tests" restart behaviour without a real supervisor. Killing an
# unsupervised process just kills it — nothing restarts it. The test below
# demonstrates the pattern of killing a process and then asserting on state,
# without ever verifying that supervision actually works. In a real codebase
# this would be a test that either always fails or tests nothing meaningful.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP005Bad.Worker do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ready, opts)
  def status(pid), do: GenServer.call(pid, :status)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state, state}
end

defmodule OTP005Bad.SupervisionRestartBadTest do
  use ExUnit.Case, async: true

  test "demonstrates anti-pattern: no supervisor, restart cannot be verified" do
    # Start the worker WITHOUT a supervisor
    {:ok, pid} = OTP005Bad.Worker.start_link()
    Process.unlink(pid)
    assert OTP005Bad.Worker.status(pid) == :ready

    # In a real misguided test, a developer might do:
    # Process.exit(pid, :kill)
    # Process.sleep(100)
    # assert Process.alive?(pid)   # This will ALWAYS fail — nothing restarts it!
    #
    # Instead, they should start a Supervisor and test through it.
    # We assert the process is alive to show normal operation works.
    assert Process.alive?(pid)

    # Show that without a supervisor, killing the process is permanent
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1000

    # Without a supervisor, the process is gone forever
    refute Process.alive?(pid)

    # NOTE: A proper test would start a Supervisor here and verify restart.
    # See good_test.exs for the correct approach.
  end
end
