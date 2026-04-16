# EXPECTED: passes
# BAD PRACTICE: Using CSS class selectors in LiveView tests. These break when
# the design system changes, Tailwind replaces Bootstrap, or a designer renames
# a CSS utility class — even though no application logic changed.
Mix.install([])

ExUnit.start(autorun: true)

defmodule CssClassSelectorsBadTest do
  use ExUnit.Case, async: true

  defp find_by_class(html, class) do
    if String.contains?(html, ~s(class="#{class}")) or
       String.contains?(html, ~s( #{class} )) or
       String.contains?(html, ~s( #{class}")),
      do: :found,
      else: :not_found
  end

  test "bad: CSS class selector breaks after Bootstrap → Tailwind migration" do
    # Before migration
    html_bootstrap = ~s(<button class="btn btn-danger" phx-click="delete">Delete</button>)
    assert find_by_class(html_bootstrap, "btn-danger") == :found

    # After migration to Tailwind — same button, same behaviour, different classes
    html_tailwind = ~s(<button class="bg-red-600 text-white px-4 py-2" phx-click="delete">Delete</button>)

    # Test now fails! But nothing functional changed.
    assert find_by_class(html_tailwind, "btn-danger") == :not_found
    # In a real LiveView test: element(view, ".btn-danger") would raise
    # "element not found" after the CSS refactor.
  end

  test "bad: CSS class selector breaks when designer renames utility class" do
    html_v1 = ~s(<span class="badge badge-success">Active</span>)
    html_v2 = ~s(<span class="status-badge status-badge--active">Active</span>)

    assert find_by_class(html_v1, "badge-success") == :found
    # After rename — test fails, badge is still visible and functionally identical
    assert find_by_class(html_v2, "badge-success") == :not_found
  end

  test "demonstrates: the correct selector survives the same styling change" do
    html_bootstrap = ~s(<button data-role="delete" class="btn btn-danger">Delete</button>)
    html_tailwind = ~s(<button data-role="delete" class="bg-red-600 text-white">Delete</button>)

    # data-role selector finds the element in both versions
    assert String.contains?(html_bootstrap, ~s(data-role="delete"))
    assert String.contains?(html_tailwind, ~s(data-role="delete"))
  end
end
