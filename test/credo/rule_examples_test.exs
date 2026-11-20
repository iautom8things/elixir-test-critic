defmodule TestCritic.Credo.RuleExamplesTest do
  use Credo.Test.Case

  alias TestCritic.Credo.Check

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "each check agrees with its linked runnable examples" do
    for {check, rule} <- [
          {Check.NondeterministicConfig, "organization/deterministic-build-config"},
          {Check.AsyncGlobalState, "isolation/no-app-put-env-async"},
          {Check.AsyncGlobalState, "isolation/no-shared-ets-async"},
          {Check.UnverifiedMoxExpect, "mocking/verify-on-exit"},
          {Check.ShortReceiveTimeout, "core/receive-timeout-budget"},
          {Check.ProcessSleepInTest, "core/no-process-sleep"},
          {Check.TrivialAssertion, "core/assert-observable-results"},
          {Check.NamedProcessOutsideSupervision, "core/start-supervised"}
        ] do
      bad_issues = rule |> example("bad", check) |> run_check(check)
      assert bad_issues != [], "expected #{inspect(check)} to report #{rule}/bad_test.exs"
      rule |> example("good", check) |> run_check(check) |> refute_issues()
    end
  end

  defp example(rule, kind, check) do
    filename = "#{rule}/#{kind}_test.exs"
    source = File.read!("rules/#{filename}")

    if check == Check.NondeterministicConfig do
      [_, config] = Regex.run(~r/config = """\n(.*?)\n\s+"""/s, source)
      to_source_file(config, "config/test.exs")
    else
      to_source_file(source, "test/#{filename}")
    end
  end
end
