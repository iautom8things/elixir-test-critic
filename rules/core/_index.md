# Core — ExUnit Fundamentals

## Scope

Rules in this category cover the foundational practices of writing ExUnit tests in
Elixir. They apply to any Elixir project using ExUnit and do not require Ecto, Phoenix,
or other frameworks. These rules establish the baseline of correct, readable, and
reliable test code.

Core rules address: async execution, test organisation (describe/test naming),
setup patterns, synchronisation primitives (`assert_receive`, `Process.sleep`),
process lifecycle management, file I/O isolation, and doctest boundaries.

## Rules

| ID | Slug | Title | Severity |
|----|------|-------|----------|
| ETC-CORE-001 | async-by-default | Use async: true by default | warning |
| ETC-CORE-002 | describe-per-function | One describe block per public function | style |
| ETC-CORE-003 | setup-composition | Compose setup with named functions, not nesting | recommendation |
| ETC-CORE-004 | assert-receive-vs-received | Use assert_receive for async, assert_received for sync | critical |
| ETC-CORE-005 | no-process-sleep | Never use Process.sleep for synchronization | critical |
| ETC-CORE-006 | start-supervised | Use start_supervised for process cleanup | critical |
| ETC-CORE-007 | test-naming | Name tests with precondition and outcome | style |
| ETC-CORE-008 | capture-log-async | Use pattern matching with capture_log in async tests | warning |
| ETC-CORE-009 | use-tmp-dir | Use @tag :tmp_dir for file I/O tests | recommendation |
| ETC-CORE-010 | doctest-boundaries | Limit doctests to pure functions | recommendation |
