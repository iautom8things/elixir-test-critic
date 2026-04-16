---
id: ETC-ERR-003
title: "Test every non-match branch in with statements"
category: errors
severity: warning
summary: >
  Every clause in a `with` expression that can fail has an implicit error path.
  Write dedicated tests for each clause's failure case, not just the happy path
  that reaches the `do` block.
principles:
  - boundary-testing
  - public-interface
applies_when:
  - "Functions that use `with` to chain multiple operations"
  - "When each clause in a `with` can return a value that doesn't match the pattern"
---

# Test every non-match branch in with statements

A `with` expression chains pattern matches. When any clause doesn't match, `with`
short-circuits and falls through to the `else` block (or returns the non-matching
value directly if there's no `else`). Each clause's failure is an observable
behavior that should be tested.

## Problem

`with` expressions are particularly prone to under-testing because the happy path
(all clauses match, `do` block executes) is the obvious test case. The failure paths
are implicit — they're hidden in the `else` block or in the fact that non-matching
values propagate out.

A function like:

```elixir
def process_order(order_id) do
  with {:ok, order} <- fetch_order(order_id),
       {:ok, user}  <- fetch_user(order.user_id),
       {:ok, _}     <- charge_card(user, order.total) do
    {:ok, :processed}
  end
end
```

has four observable behaviors: the success path, and three failure paths (order not
found, user not found, charge failed). Testing only `{:ok, :processed}` leaves 75%
of the function's behavior untested.

## Detection

- Functions with `with` expressions tested only for the success case
- `with` expressions with 3+ clauses and only 1 test in the describe block
- `else` blocks in `with` that are never exercised by any test
- Functions that use `with` to chain Ecto operations with only a happy-path test

## Bad

```elixir
describe "process_order/1" do
  test "processes a valid order" do
    # Tests only the {:ok, :processed} path
    assert {:ok, :processed} = process_order(valid_order_id)
  end
  # Missing: test for order not found
  # Missing: test for user not found
  # Missing: test for charge failed
end
```

## Good

```elixir
describe "process_order/1" do
  test "returns {:ok, :processed} when all steps succeed" do
    assert {:ok, :processed} = process_order(valid_order_id)
  end

  test "returns {:error, :order_not_found} when order does not exist" do
    assert {:error, :order_not_found} = process_order(nonexistent_id)
  end

  test "returns {:error, :user_not_found} when order's user is missing" do
    order = insert!(:order, user_id: nonexistent_user_id)
    assert {:error, :user_not_found} = process_order(order.id)
  end

  test "returns {:error, :payment_failed} when card charge fails" do
    order = insert!(:order, user: insert!(:user, card: invalid_card()))
    assert {:error, :payment_failed} = process_order(order.id)
  end
end
```

## When This Applies

- Functions using `with` to chain 2+ fallible operations
- Public functions whose callers need to handle specific error reasons
- Any `with` expression with an `else` block — the `else` clauses are code paths
  that must be tested

## When This Does Not Apply

- `with` used for purely internal data transformation where no clause can fail
  (e.g., all patterns are irrefutable)
- Private functions where the `with` error paths are tested indirectly through
  the public function that calls them

## Further Reading

- [Elixir — `with` special form](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#with/1)
- [Saša Jurić — "Error handling in Elixir"](https://medium.com/very-big-things/towards-maintainable-elixir-testing-part-3-of-4-7aa45d8e1cf9)
