defmodule TestCritic.Credo.ReviewRegressionTest do
  use Credo.Test.Case

  alias TestCritic.Credo.Check

  @checks [
    Check.AsyncGlobalState,
    Check.NamedProcessOutsideSupervision,
    Check.NondeterministicConfig,
    Check.ProcessSleepInTest,
    Check.ShortReceiveTimeout,
    Check.TrivialAssertion,
    Check.UnverifiedMoxExpect
  ]

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "every check tolerates awkward source across test and config paths" do
    sources = [
      "",
      "# Process.sleep(10) and Mox.expect(WidgetMock, :go, fn -> :ok end)",
      "answer = 42",
      "test \"declared before implementation\"",
      ~S|doc = "Process.sleep(10)" <> ~S"Mox.expect(WidgetMock, :go, fn -> :ok end)"|,
      ~S'''
      @doc """
      System.os_time()
      Process.sleep(10)
      """
      ''',
      """
      defmodule WidgetTest do
        use ExUnit.Case, async: true

        for name <- [:read, :write] do
          defp unquote(name)(), do: unquote(name)
          defp unquote(name)(value) when is_integer(value), do: value
        end
      end
      """,
      """
      defmodule unquote(name) do
        use ExUnit.Case
        alias __MODULE__.{A, B}
        import unquote(Mox)
        def unquote(name)(value) when is_atom(value), do: value
      end
      """
    ]

    for {body, index} <- Enum.with_index(sources),
        location <- [
          "test/probe_#{index}_test.exs",
          "lib/probe_#{index}.ex",
          "config/probe_#{index}.exs"
        ],
        check <- @checks do
      assert is_list(check.run(to_source_file(body, location), [])),
             "#{inspect(check)} failed on source #{index} at #{location}"
    end

    invalid = Credo.SourceFile.parse("defmodule Widget do", "test/invalid_test.exs")
    assert invalid.status == :invalid
    for check <- @checks, do: refute_issues(check.run(invalid, []))
  end

  test "test checks leave production modules alone" do
    source = """
    defmodule Widget do
      use Widget.Plugin, async: true

      test "an internal DSL call" do
        Application.put_env(:widget, :mode, :probe)
        Mox.expect(WidgetMock, :read, fn -> :ok end)
        Process.sleep(10)
        assert_receive :ready, 10
        assert true
        Widget.Server.start_link(name: Widget.Server)
      end
    end
    """

    for check <- @checks -- [Check.NondeterministicConfig] do
      refute_issues(run(source, check, "lib/widget.ex"))
    end
  end

  test "short waits never suggest an unknown suite default" do
    for statement <- ["assert_receive :ready, 100", "assert_receive :ready, 0"] do
      [issue] = run(statement, Check.ShortReceiveTimeout)
      refute issue.message =~ "suite default"
      if statement == "assert_receive :ready, 0", do: assert(issue.message =~ "assert_received")
    end
  end

  test "test helpers require an adequate default unless opted out" do
    check = Check.ShortReceiveTimeout
    helper = "test/test_helper.exs"

    for statement <- [
          "ExUnit.start()",
          "ExUnit.start(assert_receive_timeout: 10)",
          "ExUnit.configure(assert_receive_timeout: -1)",
          "ExUnit.configure(assert_receive_timeout: \"slow\")"
        ] do
      assert_issue(run(statement, check, helper), %{message: ~r/assert_receive_timeout.*500 ms/})
    end

    for statement <- [
          "ExUnit.start(assert_receive_timeout: 500)",
          "ExUnit.configure(assert_receive_timeout: deadline())"
        ] do
      refute_issues(run(statement, check, helper))
    end

    refute_issues(run("ExUnit.start()", check, helper, require_configured_default: false))

    assert_issue(
      run("ExUnit.start(assert_receive_timeout: 750)", check, helper, min_timeout: 1_000)
    )
  end

  for statement <- [
        "assert :ok",
        "assert 1",
        "assert -7",
        "assert 1.25",
        ~s(assert "ready"),
        "assert Widget",
        "assert [1]",
        "assert {:ok, 1}",
        "assert %{enabled: true}",
        "refute false",
        "refute nil",
        "assert not false",
        "assert !nil",
        "assert !false",
        "assert is_atom(:made_up)",
        "assert is_integer(9)",
        ~s|assert Kernel.is_binary("text")|,
        "refute is_list(42)"
      ] do
    @statement statement
    test "trivial assertion reports #{statement}" do
      assert_issue(run(@statement, Check.TrivialAssertion))
    end
  end

  test "literal type guards allow actual values under test" do
    """
    assert is_integer(count)
    assert is_struct(result, Widget)
    assert is_map(Widget.options())
    refute is_list(result)
    """
    |> run(Check.TrivialAssertion)
    |> refute_issues()
  end

  for statement <- [
        ":ok = Process.sleep(10)",
        "_ = Process.sleep(10)",
        "assert :ok = Process.sleep(10)",
        "receive do after 50 -> :ok end",
        "import Process, only: [sleep: 1], warn: false\nsleep(10)",
        "import :timer, only: [sleep: 1]\n10 |> sleep()"
      ] do
    @statement statement
    test "test-flow sleep reports #{inspect(statement)}" do
      for params <- [[], [scope: :all]] do
        source = "test \"waits\" do\n" <> @statement <> "\nend"
        assert_issue(run(source, Check.ProcessSleepInTest, "test/widget_test.exs", params))
      end
    end
  end

  test "sleep checks cover feature, property and single-sleep helpers" do
    """
    feature "waits", do: Process.sleep(10)
    property "waits", do: Process.sleep(10)
    defp nap(ms), do: Process.sleep(ms)
    def nap_twice(ms) do
      Process.sleep(ms)
      :ok
    end
    def other(ms) do
      Process.sleep(ms)
      work()
    end
    def delayed(ms, callback) do
      receive do
      after
        ms -> callback.()
      end
    end
    """
    |> run(Check.ProcessSleepInTest)
    |> assert_issues_match(Enum.map([1, 2, 3, 5], &%{line_no: &1}))
  end

  test "sleep checks ignore a real receive and an indefinite receive" do
    """
    test "waits for a message" do
      receive do
        :ready -> :ok
      after
        50 -> flunk()
      end

      receive do
      after
        :infinity -> :ok
      end
    end
    """
    |> run(Check.ProcessSleepInTest)
    |> refute_issues()
  end

  for verification <- [
        "Mox.verify!()",
        "verify!(WidgetMock)",
        "on_exit(fn -> Mox.verify!() end)",
        "on_exit(&Mox.verify!/0)"
      ] do
    @verification verification
    test "Mox recognizes verification #{verification}" do
      source = """
      defmodule WidgetTest do
        use ExUnit.Case
        import Mox

        test "checks this call" do
          Mox.expect(WidgetMock, :go, fn -> :ok end)
          @VERIFY@
        end

        test "does not verify a different call" do
          Mox.expect(WidgetMock, :go, fn -> :ok end)
        end
      end
      """

      source
      |> String.replace("@VERIFY@", @verification)
      |> run(Check.UnverifiedMoxExpect)
      |> assert_issue(%{line_no: 11, message: ~r/verifying_case_templates/})
    end
  end

  test "Mox ignores tests under a test support segment" do
    source = """
    defmodule WidgetCase do
      use ExUnit.CaseTemplate

      def expect_ok(mock), do: Mox.expect(mock, :go, fn -> :ok end)
    end
    """

    for path <- ["test/support/case.ex", "/workspace/apps/example/test/support/case_test.exs"] do
      refute_issues(run(source, Check.UnverifiedMoxExpect, path))
    end
  end

  test "Mox does not infer imports from another mocking library" do
    """
    defmodule WidgetTest do
      use ExUnit.Case
      use Mimic

      test "stubs a response with Mimic" do
        expect(Widget, :read, fn -> :ok end)
      end
    end
    """
    |> run(Check.UnverifiedMoxExpect)
    |> refute_issues()
  end

  test "async resolves literal attributes as of each use" do
    """
    defmodule WidgetTest do
      @run_async true
      use ExUnit.Case, async: @run_async
      @run_async false
      Application.put_env(:widget, :a, 1)
    end

    defmodule SyncTest do
      @run_async false
      use ExUnit.Case, async: @run_async
      @run_async true
      Application.put_env(:widget, :a, 1)
    end
    """
    |> run(Check.AsyncGlobalState)
    |> assert_issue(%{line_no: 5})
  end

  test "async recognizes imported writers and keeps ETS and Mox advice specific" do
    """
    defmodule WidgetTest do
      use ExUnit.Case, async: true
      import Application, only: [put_env: 3]
      import System, only: [delete_env: 1]
      put_env(:widget, :a, 1)
      delete_env("WIDGET")
      :ets.new(:shared, [:named_table])
      :ets.new(:"t_\#{System.unique_integer()}", [:named_table])
      setup :set_mox_global
    end
    """
    |> run(Check.AsyncGlobalState)
    |> assert_issues_match([
      %{line_no: 5},
      %{line_no: 6},
      %{line_no: 7, message: ~r/unnamed ETS/},
      %{line_no: 9, message: ~r/Mox.*private/}
    ])
  end

  test "nondeterministic config covers direct Erlang calls and imported System calls" do
    """
    import System, only: [monotonic_time: 0]
    :erlang.unique_integer()
    :os.system_time()
    :erlang.make_ref()
    Ecto.UUID.generate()
    monotonic_time()
    """
    |> run(Check.NondeterministicConfig, "config/config.exs")
    |> assert_issues(5)
  end

  test "invalid custom params produce a configuration issue naming the check and param" do
    for {check, param, value} <- [
          {Check.UnverifiedMoxExpect, :verifying_case_templates, ["Widget.Case"]},
          {Check.ProcessSleepInTest, :scope, :typo},
          {Check.ProcessSleepInTest, :excluded_paths, [:support]},
          {Check.ShortReceiveTimeout, :min_timeout, "500"},
          {Check.ShortReceiveTimeout, :macros, [:assert_receive, "render_async"]},
          {Check.ShortReceiveTimeout, :require_configured_default, 1}
        ] do
      [issue] =
        check.run(to_source_file("test \"idle\", do: :ok", "test/widget_test.exs"), [
          {param, value}
        ])

      assert issue.message =~ "Invalid Credo configuration"
      assert issue.message =~ inspect(check)
      assert issue.message =~ inspect(param)
    end
  end

  test "an invalid option produces one error for the entire Credo run" do
    [
      to_source_file("# first", "test/first_test.exs"),
      to_source_file("# second", "test/second_test.exs")
    ]
    |> run_check(Check.ProcessSleepInTest, scope: :typo)
    |> assert_issue(%{
      filename: "test/first_test.exs",
      message: ~r/:scope must be :test_flow or :all/
    })
  end

  defp run(source, check, filename \\ "test/widget_test.exs", params \\ []) do
    source |> to_source_file(filename) |> run_check(check, params)
  end
end
