# EXPECTED: passes
Mix.install([])

# Demonstrates: element-scoped events vs. direct event dispatch in LiveView tests.
#
# In a real Phoenix LiveView test:
#
#   # GOOD: element-scoped — finds the DOM element first
#   view
#   |> element("[data-role='delete-post'][data-id='#{post.id}']")
#   |> render_click()
#
#   # GOOD: element found by ID
#   view |> element("#submit-btn") |> render_submit()
#
#   # GOOD: element with CSS selector for a specific form field
#   view |> element("#user-form") |> render_change(%{name: "Ada"})
#
# Element-scoped events:
#   - Verify the element exists in the rendered HTML
#   - Read the phx-click/phx-submit/phx-change attribute from the element
#   - Include phx-value-* attributes embedded in the element automatically
#   - Fail fast if the element is missing or the event name doesn't match

ExUnit.start(autorun: true)

defmodule ElementScopedEventsGoodTest do
  use ExUnit.Case, async: true

  # Simulate a simplified "find element" operation to show the pattern
  defp find_element(html, "#" <> id = selector) do
    if String.contains?(html, ~s(id="#{id}")) do
      {:ok, %{selector: selector, html: html}}
    else
      {:error, "element #{selector} not found in rendered HTML"}
    end
  end

  defp find_element(html, selector) do
    if String.contains?(html, selector) do
      {:ok, %{selector: selector, html: html}}
    else
      {:error, "element #{selector} not found in rendered HTML"}
    end
  end

  defp render_click({:ok, element}) do
    # In real LiveViewTest: extracts phx-click from the element and fires it
    {:ok, "event fired for #{element.selector}"}
  end

  defp render_click({:error, reason}), do: {:error, reason}

  test "element-scoped click verifies the element exists" do
    html = ~s(<button id="delete-btn" phx-click="delete" phx-value-id="42">Delete</button>)

    result =
      html
      |> find_element("#delete-btn")
      |> render_click()

    assert result == {:ok, "event fired for #delete-btn"}
  end

  test "element-scoped event fails fast when element is missing" do
    html = ~s(<p>No delete button here</p>)

    result =
      html
      |> find_element("#delete-btn")
      |> render_click()

    assert {:error, _reason} = result
  end

  test "data attribute selector targets specific items in a list" do
    post_id = 7
    html = ~s(<button data-role="delete-post" data-id="#{post_id}" phx-click="delete">X</button>)

    result =
      html
      |> find_element("data-role=\"delete-post\"")
      |> render_click()

    assert {:ok, _} = result
  end
end
