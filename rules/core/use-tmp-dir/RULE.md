---
id: ETC-CORE-009
title: "Use @tag :tmp_dir for file I/O tests"
category: core
severity: recommendation
summary: >
  Tag tests that perform file I/O with `@tag :tmp_dir` to receive a unique
  temporary directory per test. This prevents file conflicts between concurrent
  tests and eliminates manual cleanup code.
principles:
  - async-default
applies_when:
  - "Any test that reads from or writes to the filesystem"
  - "Tests that create, modify, or delete files as part of testing"
---

# Use @tag :tmp_dir for file I/O tests

ExUnit provides the `:tmp_dir` tag built-in (available since Elixir 1.11). When you
tag a test with `@tag :tmp_dir`, ExUnit creates a fresh temporary directory before
the test runs and injects its path as `context.tmp_dir`. The directory is automatically
deleted after the test.

## Problem

Tests that write to hardcoded paths (e.g., `/tmp/test_output.csv`) conflict when run
concurrently — two tests writing to the same file race with each other. Tests that
create files and don't clean up on failure leave artefacts that can affect later test
runs. Both problems vanish when each test gets its own isolated temporary directory.

Manual cleanup with `on_exit` works but is boilerplate that developers forget to add.
`@tag :tmp_dir` is the zero-boilerplate solution.

## Detection

- File operations (`File.write`, `File.read`, `File.mkdir_p`) using hardcoded `/tmp` paths
- `on_exit` callbacks that delete files
- Tests that create files in the project directory (e.g., `"test/fixtures/output.txt"`)
- `System.tmp_dir!()` followed by manual path construction in tests

## Bad

```elixir
test "exports data to CSV" do
  path = "/tmp/my_export.csv"
  MyApp.export(path)
  assert File.exists?(path)
  # If the test fails, the file is never cleaned up
  File.rm!(path)
end
```

## Good

```elixir
@tag :tmp_dir
test "exports data to CSV", %{tmp_dir: dir} do
  path = Path.join(dir, "export.csv")
  MyApp.export(path)
  assert File.exists?(path)
  # No cleanup needed — ExUnit removes the tmp_dir after the test
end
```

## When This Applies

- Any test that creates, modifies, or reads files that should not persist after the test
- Any test using file-based caches, logs, exports, or uploads

## When This Does Not Apply

- Tests that read existing test fixtures from `test/fixtures/` — these are read-only
  and don't need a tmp dir
- Tests that rely on specific absolute paths as part of the behavior under test
  (in that case, use `@tag :tmp_dir` and `Path.join(tmp_dir, "specific_name")`)

## Further Reading

- [ExUnit.Case — :tmp_dir tag](https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-tmp_dir)
- [Elixir 1.11 release notes](https://elixir-lang.org/blog/2020/10/06/elixir-v1-11-0-released/)
