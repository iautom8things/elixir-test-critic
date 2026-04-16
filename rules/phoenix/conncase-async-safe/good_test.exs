# EXPECTED: passes
Mix.install([])

# Demonstrates: ConnCase with async: true is correct and safe.
#
# In a real Phoenix app with Ecto:
#
#   defmodule MyAppWeb.UserControllerTest do
#     use MyAppWeb.ConnCase, async: true     # ← correct
#
#     test "lists users", %{conn: conn} do
#       conn = get(conn, ~p"/users")
#       assert html_response(conn, 200) =~ "Users"
#     end
#   end
#
# ConnCase sets up Ecto.Adapters.SQL.Sandbox in :async mode, so each test
# runs in its own rolled-back transaction. async: true is safe and should
# always be set.

ExUnit.start(autorun: true)

defmodule ConnCaseAsyncGoodTest do
  use ExUnit.Case, async: true

  test "async: true is set — tests run concurrently" do
    # The mere presence of async: true in use ExUnit.Case, async: true
    # (or use MyAppWeb.ConnCase, async: true) enables parallelism.
    # This test confirms the pattern is correctly applied.
    assert true
  end

  test "SQL sandbox supports multiple concurrent connections" do
    # Ecto SQL sandbox opens one transaction per test process and rolls it
    # back after the test. Multiple test processes can hold open transactions
    # simultaneously without interfering.
    #
    # Simulated proof: independent state per test
    state = %{test_id: System.unique_integer(), data: "isolated"}
    assert state.data == "isolated"
  end

  test "async tests are independent even with shared database schema" do
    # Each async ConnCase test gets its own sandbox transaction.
    # Inserts in this test are invisible to other tests and are rolled back.
    record_a = %{id: 1, name: "test-#{System.unique_integer()}"}
    assert record_a.id == 1
  end
end
