%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["config/**/*.{ex,exs}", "lib/**/*.{ex,exs}", "test/**/*.{ex,exs}", "mix.exs"]
      },
      checks: %{
        extra: [
          {Shampoo.Check.NondeterministicConfig, []},
          {Shampoo.Check.AsyncGlobalState, []},
          {Shampoo.Check.UnverifiedMoxExpect, []},
          {Shampoo.Check.ShortReceiveTimeout, []},
          {Shampoo.Check.ProcessSleepInTest, []},
          {Shampoo.Check.TrivialAssertion, []},
          {Shampoo.Check.NamedProcessOutsideSupervision, []}
        ]
      }
    }
  ]
}
