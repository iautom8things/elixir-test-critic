alias TestCritic.Credo.Check

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["config/**/*.{ex,exs}", "lib/**/*.{ex,exs}", "test/**/*.{ex,exs}", "mix.exs"]
      },
      checks: %{
        extra: [
          {Check.NondeterministicConfig, []},
          {Check.AsyncGlobalState, []},
          {Check.UnverifiedMoxExpect, []},
          {Check.ShortReceiveTimeout, []},
          {Check.ProcessSleepInTest, []},
          {Check.TrivialAssertion, []},
          {Check.NamedProcessOutsideSupervision, []}
        ]
      }
    }
  ]
}
