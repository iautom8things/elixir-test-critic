# EXPECTED: passes
Mix.install([])

# Demonstrates: using stable selectors (IDs, data-role attributes) vs. fragile
# CSS class selectors in LiveView tests.
#
# In a real Phoenix LiveView test:
#
#   # GOOD: ID selector — stable across styling changes
#   view |> element("#delete-post-#{post.id}") |> render_click()
#
#   # GOOD: data-role attribute — semantic, survives CSS refactors
#   view |> element("[data-role='delete-post'][data-id='#{post.id}']") |> render_click()
#
#   # GOOD: data-testid for test-only targeting
#   view |> element("[data-testid='submit-button']") |> render_click()

ExUnit.start(autorun: true)

defmodule ResilientSelectorsGoodTest do
  use ExUnit.Case, async: true

  defp find_element(html, selector) do
    cond do
      String.starts_with?(selector, "#") ->
        id = String.trim_leading(selector, "#")
        if String.contains?(html, ~s(id="#{id}")), do: :found, else: :not_found

      String.starts_with?(selector, "[") ->
        # Simplified attribute selector check
        attr = selector |> String.trim("[") |> String.trim("]")
        if String.contains?(html, attr), do: :found, else: :not_found

      true ->
        :not_found
    end
  end

  test "ID selector finds element regardless of CSS classes present" do
    # CSS classes can change freely — the ID is stable
    html_v1 = ~s(<button id="delete-btn" class="btn-danger">Delete</button>)
    html_v2 = ~s(<button id="delete-btn" class="button--destructive tw-text-red-500">Delete</button>)

    assert find_element(html_v1, "#delete-btn") == :found
    assert find_element(html_v2, "#delete-btn") == :found  # still found after CSS change
  end

  test "data-role selector survives styling refactor" do
    html_before = ~s(<button data-role="delete-post" data-id="42" class="btn-danger">X</button>)
    html_after = ~s(<button data-role="delete-post" data-id="42" class="icon-btn text-red">X</button>)

    assert find_element(html_before, ~s([data-role="delete-post"])) == :found
    assert find_element(html_after, ~s([data-role="delete-post"])) == :found
  end

  test "data-testid convention isolates test concerns from application CSS" do
    html = ~s(<input data-testid="email-input" class="form-control" type="email"/>)

    # data-testid is purely for tests — designers never touch it
    assert find_element(html, ~s([data-testid="email-input"])) == :found
  end
end
