# Pull request reviews

The repo is also a GitHub Action. It reviews the ExUnit test lines a pull
request changes and reports a score from 1 to 5. It is advisory. The check it
posts never fails, so it cannot block a merge.

## What a pull request gets

- **A check run** named `Elixir Test Critic`, titled with the score, such as
  `4/5 · 2 warnings`. It holds the full report: every finding with the reason
  and a fix, lower severities folded away, and what the tests do well.
- **Annotations** on the changed lines in the Files changed tab. They are not
  review comments, so they add nothing to the conversation.
- **One comment**, only when there is a critical or warning finding. It lists
  at most six of them, one line each, and links to the full report. Later runs
  edit that comment. A clean review posts no comment.
- **`result.json`** as a workflow artifact, for tools and agents.

Agents can read the score without the artifact. The comment and the report
both end with a line like:

```
<!-- elixir-test-critic:score=4 critical=0 warning=2 recommendation=1 style=0 -->
```

## Score

| Score | Meaning |
| --- | --- |
| 5 | No critical or warning finding |
| 4 | One or two warnings |
| 3 | Three or more warnings |
| 2 | One critical finding |
| 1 | Two or more critical findings |

Recommendations and style notes never change the score. The action computes
the score from the findings. The model does not set it.

## What is checked before anything is reported

The model proposes findings. `TestCritic.PrReport` then:

- takes each finding's severity from the rule's front matter,
- drops a finding that cites a rule ID that does not exist,
- drops a finding on a file or line the pull request did not add (three lines
  of slack, for cases like the `use ... async: false` line above a new test),
- applies the project's `.test_critic.yml` (see [CONFIG.md](CONFIG.md)).

Dropped findings are listed at the bottom of the full report with the reason.

The action reads the pull request through the GitHub API. It never checks out
or runs the pull request's code, and the model gets read-only file tools.

## Setup

Copy [`examples/caller.yaml`](../examples/caller.yaml) to
`.github/workflows/elixir_test_critic.yaml` and pin the action to a commit
SHA. The rules ship inside the action, so the pin also fixes which rules run.
Nothing is vendored into the repo.

Inputs:

| Input | Default | |
| --- | --- | --- |
| `engine` | `copilot` | `copilot` (GitHub Copilot CLI) or `claude` (Claude Code) |
| `model` | `claude-sonnet-5` | Passed to the engine |
| `token` | | Copilot: a token of a user with a Copilot license. Claude: an Anthropic API key |
| `requested` | `false` | `true` when a person asked: skips the cache and always answers |

The workflow runs when a pull request opens, leaves draft, or gets a push. A
push that leaves the test diff unchanged reuses the cached review and costs
nothing. A pull request that touches no test file exits before the model runs.

## Asking for a review

Comment `@test-critic` on a pull request. The workflow reacts with 👀, runs a
fresh review and always answers. To make a repo answer mentions only, remove
the `pull_request` trigger from the workflow.

## Cost

Measured on 19 real pull requests in five Phoenix apps, November 2026, with
the rules read on demand:

| Model | Typical | Largest (15 test files, 4,200 added lines) | Time |
| --- | --- | --- | --- |
| Claude Sonnet 5 | $0.09 to $0.15 | $0.29 | 10 to 50 s |
| Claude Haiku 5.5 | $0.01 to $0.02 | $0.16 | 20 to 150 s |

Sonnet found more of the warnings a human reviewer confirmed, and ran faster.

## Testing the publish path

Add the `publish-selftest` label to a pull request in this repo. The
`Publish self-test` workflow runs the action with a saved model reply
(`test/fixtures/selftest_review.json`), so it needs no model credential.
