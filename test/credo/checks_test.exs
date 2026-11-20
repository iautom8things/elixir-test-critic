defmodule TestCritic.Credo.ChecksTest do
  use Credo.Test.Case

  alias Credo.Check.ConfigCommentFinder
  alias Credo.CLI.Filter
  alias TestCritic.Credo.Check

  @test_file "test/widget_test.exs"

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "config rejects clock, random and unique values in build-time files" do
    """
    alias System, as: Clock
    Clock.os_time()
    System.system_time(:second)
    System.monotonic_time()
    System.unique_integer()
    DateTime.utc_now()
    NaiveDateTime.utc_now()
    Date.utc_today()
    :rand.uniform()
    :crypto.strong_rand_bytes(16)
    make_ref()
    Kernel.make_ref()
    System.get_env("WIDGET_URL")
    &System.os_time/0
    quote do: System.os_time()
    """
    |> run(Check.NondeterministicConfig, "config/test.exs")
    |> assert_issues(11)
    |> assert_issue_matches(%{line_no: 2, column: 7, trigger: "os_time"})

    for path <- [
          "config/runtime.exs",
          "config/sub/test.exs",
          "lib/config/test.exs",
          "config/dev.ex"
        ] do
      refute_issues(run("System.os_time()", Check.NondeterministicConfig, path))
    end
  end

  test "global state flags each write in a module with a literally async use" do
    """
    defmodule WidgetTest do
      use WidgetCase, async: true
      alias Elixir.Application, as: App
      setup :set_mox_global
      setup {Mox, :set_mox_global}
      setup [:set_mox_global]

      def write do
        App.put_env(:widget, :flag, true)
        Application.put_all_env(widget: [flag: true])
        Application.delete_env(:widget, :flag)
        System.put_env("WIDGET", "yes")
        System.delete_env("WIDGET")
        Logger.configure(level: :warning)
        Logger.put_module_level(Widget, :warning)
        Mox.set_mox_global()
        :persistent_term.put(:widget, true)
        :persistent_term.erase(:widget)
        :ets.new(:widget, [:set, :named_table])
      end
    end
    """
    |> run(Check.AsyncGlobalState)
    |> assert_issues(14)
    |> assert_issue_matches(%{line_no: 9, trigger: "put_env"})
  end

  test "global state allows reads and local tables and keeps nested module options separate" do
    """
    defmodule AsyncTest do
      use ExUnit.Case, async: true
      def read, do: Application.get_env(:widget, :flag)
      def table, do: :ets.new(:widget, [:set, :public])

      defmodule SyncTest do
        use ExUnit.Case, async: false
        setup :set_mox_global
        def write, do: Application.put_env(:widget, :flag, true)
      end
    end

    defmodule OtherTest do
      use ExUnit.Case, async: async?()
      def write, do: Application.put_env(:widget, :flag, true)
    end
    """
    |> run(Check.AsyncGlobalState)
    |> refute_issues()
  end

  test "Mox reports the first unverified expectation for each module" do
    """
    defmodule FirstTest do
      use ExUnit.Case
      import Mox, only: [expect: 3]
      alias Mox, as: Mocking
      test "sets expectations" do
        WidgetMock |> expect(:call, fn -> :ok end)
        Mocking.expect(WidgetMock, :call, 2, fn -> :ok end)
      end
    end

    defmodule SecondTest do
      use ExUnit.Case
      test "sets another expectation", do: Mox.expect(WidgetMock, :call, 3, fn -> :ok end)
    end
    """
    |> run(Check.UnverifiedMoxExpect)
    |> assert_issues_match([%{line_no: 6, trigger: "expect"}, %{line_no: 13, trigger: "expect"}])
  end

  test "Mox allows registered verification in the module or matching describe" do
    for setup <- [
          "import Mox\nsetup :verify_on_exit!",
          "setup do\n  Mox.verify_on_exit!()\nend",
          "setup [{Mox, :verify_on_exit!}]"
        ] do
      """
      defmodule WidgetTest do
        use ExUnit.Case

        describe "verified" do
          #{setup}
          test "sets an expectation", do: Mox.expect(WidgetMock, :call, fn -> :ok end)
        end
      end
      """
      |> run(Check.UnverifiedMoxExpect)
      |> refute_issues()
    end
  end

  test "Mox keeps describe setup local and ignores unrelated expect functions" do
    """
    defmodule WidgetTest do
      use ExUnit.Case
      import Mox, except: [expect: 3, expect: 4]

      describe "verified" do
        setup :verify_on_exit!
        test "configured", do: Mox.expect(WidgetMock, :call, fn -> :ok end)
      end

      describe "missing" do
        test "unconfigured", do: Mox.expect(WidgetMock, :call, fn -> :ok end)
      end

      test "unrelated" do
        Expectation.expect(WidgetMock, :call, fn -> :ok end)
        expect(WidgetMock, :call, fn -> :ok end)
      end
    end
    """
    |> run(Check.UnverifiedMoxExpect)
    |> assert_issue(%{line_no: 11})
  end

  test "Mox trusts configured case templates, including alias uses" do
    source = """
    defmodule WidgetTest do
      alias Widget.VerifiedCase, as: Case
      use Case
      test "sets an expectation", do: Mox.expect(WidgetMock, :call, fn -> :ok end)
    end
    """

    assert_issue(run(source, Check.UnverifiedMoxExpect))

    source
    |> run(Check.UnverifiedMoxExpect, @test_file,
      verifying_case_templates: [Widget.VerifiedCase, Widget.UnusedCase]
    )
    |> refute_issues()
  end

  test "receive timeout uses the timeout slot of each supported signature" do
    """
    assert_receive :ready, 10
    assert_receive :ready, 20, "missing ready"
    assert_push "ready", 1, 30
    assert_broadcast "ready", 1, 40
    assert_reply ref, :ok, 1, 50
    assert_patch view, "/widget", 60
    assert_patch view, 70
    assert_redirect view, "/widget", 80
    assert_redirect view, 90
    view |> Phoenix.LiveViewTest.render_async(100)
    """
    |> run(Check.ShortReceiveTimeout)
    |> assert_issues(10)
    |> assert_issue_matches(%{line_no: 10, trigger: "render_async"})
  end

  test "receive timeout allows refutes, implicit and computed waits, and integer payloads" do
    """
    refute_receive :ready, 10
    refute_push "ready", %{}, 10
    assert_receive :ready
    assert_receive :ready, @timeout
    assert_receive :ready, to_timeout(second: 1)
    assert_receive :ready, 500
    assert_push "ready", 1
    assert_broadcast "ready", 1
    assert_reply ref, :ok, 1
    assert_patch view, "/widget"
    """
    |> run(Check.ShortReceiveTimeout)
    |> refute_issues()
  end

  test "receive timeout honors min_timeout and macros, with refute forms always exempt" do
    """
    assert_receive :ready, 100
    wait_for_widget(:ready, 90)
    wait_for_widget(:ready, 100)
    refute_widget(:ready, 10)
    """
    |> run(Check.ShortReceiveTimeout, @test_file,
      macros: [:wait_for_widget, :refute_widget],
      min_timeout: 100
    )
    |> assert_issue(%{line_no: 2, message: ~r/100 ms/})
  end

  test "receive timeout only requires the suite default when opted in" do
    opts = [require_configured_default: true]
    helper = "test/test_helper.exs"
    check = Check.ShortReceiveTimeout

    refute_issues(run("ExUnit.start()", check, helper))

    "ExUnit.start()"
    |> run(check, helper, opts)
    |> assert_issue(%{line_no: 1, trigger: "start", message: ~r/assert_receive_timeout/})

    for source <- [
          "ExUnit.start(assert_receive_timeout: 1_000)",
          "ExUnit.configure(assert_receive_timeout: timeout)\nExUnit.start()"
        ] do
      refute_issues(run(source, check, helper, opts))
    end
  end

  test "sleep reports both spellings under test paths and honors exclusions" do
    check = Check.ProcessSleepInTest
    source = "Process.sleep(10)\n10 |> :timer.sleep()"
    support = "test/support/stub.ex"

    for path <- [@test_file, "apps/widgets/test/widget_test.exs", "test/supporting/stub.exs"] do
      source
      |> run(check, path)
      |> assert_issues(2)
      |> assert_issue_matches(%{
        line_no: 1,
        message: ~r/poll with a deadline.*include the reason/
      })
    end

    refute_issues(run(source, check, support))
    refute_issues(run(source, check, "lib/widget.ex"))
    assert_issues(run(source, check, support, excluded_paths: []), 2)
    refute_issues(run(source, check, @test_file, excluded_paths: [@test_file]))
  end

  test "trivial assertions include comparisons of literals and identical AST" do
    """
    assert true
    assert value == value
    assert result.total === result.total
    assert is_atom(Widget.Client)
    assert {:ok, 5} != {:error, 3}
    refute 1 > 2
    """
    |> run(Check.TrivialAssertion)
    |> assert_issues(6)

    """
    assert result.total == 42
    assert value == expected
    assert is_atom(result)
    assert is_atom(Widget.status())
    refute value == value
    assert ready?()
    """
    |> run(Check.TrivialAssertion)
    |> refute_issues()
  end

  test "named process checks pinpoint named starts and linked starts" do
    """
    Widget.Server.start_link(name: Widget)
    Widget.Server.start([], name: Widget)
    GenServer.start_link(Widget, [], name: Widget)
    Agent.start_link(fn -> nil end, name: Widget)
    Supervisor.start_link([], strategy: :one_for_one, name: Widget)
    __MODULE__.start_link(name: Widget)
    """
    |> run(Check.NamedProcessOutsideSupervision)
    |> assert_issues(6)
  end

  test "named process checks allow unnamed, supervised and child entry-point starts" do
    """
    defmodule Child do
      def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    Widget.Server.start_link([])
    Widget.Server.start_link(name: nil)
    GenServer.start_link(Widget, name: :initial_data)
    Agent.start_link(Widget, :initial, [name: :input])
    Task.start_link(Widget, :run, [name: :input])
    Supervisor.start_link(Widget, name: :initial_data)
    start_supervised!({Child, []})
    start_supervised(Widget.Server.start_link(name: Widget))
    ExUnit.Callbacks.start_supervised!(Widget.Server.start_link(name: Widget))
    """
    |> run(Check.NamedProcessOutsideSupervision)
    |> refute_issues()
  end

  test "each check honors Credo's disable-for-next-line directive" do
    violations = [
      {Check.NondeterministicConfig, "config/test.exs", "", "System.os_time()", "", []},
      {Check.AsyncGlobalState, @test_file,
       "defmodule WidgetTest do\nuse ExUnit.Case, async: true\n",
       "Application.put_env(:widget, :key, 1)", "end\n", []},
      {Check.UnverifiedMoxExpect, @test_file, "defmodule WidgetTest do\nuse ExUnit.Case\n",
       "Mox.expect(WidgetMock, :call, fn -> :ok end)", "end\n", []},
      {Check.ShortReceiveTimeout, @test_file, "", "assert_receive :ready, 10", "", []},
      {Check.ShortReceiveTimeout, "test/test_helper.exs", "", "ExUnit.start()", "",
       [require_configured_default: true]},
      {Check.ProcessSleepInTest, @test_file, "", "Process.sleep(10)", "", []},
      {Check.TrivialAssertion, @test_file, "", "assert true", "", []},
      {Check.NamedProcessOutsideSupervision, @test_file, "", "Widget.start_link(name: Widget)",
       "", []}
    ]

    for {check, path, prefix, call, suffix, params} <- violations do
      comment =
        "# The test intentionally exercises this case.\n# credo:disable-for-next-line #{inspect(check)}\n"

      source = to_source_file(prefix <> comment <> call <> "\n" <> suffix, path)

      issues =
        source
        |> run_check(check, Keyword.put(params, :exit_status, 8))
        |> assert_issue(%{exit_status: 8})

      config_comments = [source] |> ConfigCommentFinder.run() |> Map.new()

      issues
      |> Filter.valid_issues(%{config_comment_map: config_comments})
      |> refute_issues()
    end
  end

  defp run(source, check, path \\ @test_file, params \\ []) do
    source |> to_source_file(path) |> run_check(check, params)
  end
end
