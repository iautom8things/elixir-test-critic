# EXPECTED: passes
Mix.install([])

# Demonstrates: passing form values through element/form helpers vs. direct dispatch.
#
# In a real Phoenix LiveView test:
#
#   # GOOD: form/3 helper — reads phx-submit from the form, encodes data correctly
#   view
#   |> form("#user-form", user: %{name: "Ada", email: "ada@example.com"})
#   |> render_submit()
#
#   # GOOD: element-scoped render_submit with data
#   view
#   |> element("#user-form")
#   |> render_submit(%{user: %{name: "Ada", email: "ada@example.com"}})
#
# Benefits:
#   - Verifies the form element exists in the rendered HTML
#   - Reads phx-submit event name from the element (no hardcoding)
#   - Encodes nested field params the same way a browser would
#   - Catches mismatches between the form's phx-submit and the handler

ExUnit.start(autorun: true)

defmodule FormHelperGoodTest do
  use ExUnit.Case, async: true

  # Simulate finding a form and submitting with data through the element
  defp find_form(html, "#" <> id = selector) do
    if String.contains?(html, ~s(id="#{id}")) do
      # Extract the phx-submit attribute from the form
      case Regex.run(~r/phx-submit="([^"]+)"/, html) do
        [_, event] -> {:ok, %{selector: selector, event: event}}
        nil -> {:error, "no phx-submit attribute found on #{selector}"}
      end
    else
      {:error, "form #{selector} not found"}
    end
  end

  defp render_submit({:ok, form}, data) do
    {:ok, %{event: form.event, data: data, submitted: true}}
  end
  defp render_submit({:error, reason}, _data), do: {:error, reason}

  test "form helper finds the form and reads its phx-submit event" do
    html = ~s(<form id="user-form" phx-submit="save"><input name="name"/></form>)

    result =
      html
      |> find_form("#user-form")
      |> render_submit(%{user: %{name: "Ada", email: "ada@example.com"}})

    assert {:ok, submission} = result
    assert submission.event == "save"
    assert submission.data.user.name == "Ada"
    assert submission.submitted == true
  end

  test "form helper fails fast when the form does not exist" do
    html = ~s(<p>No form here</p>)

    result =
      html
      |> find_form("#user-form")
      |> render_submit(%{user: %{name: "Ada"}})

    assert {:error, reason} = result
    assert reason =~ "not found"
  end

  test "nested form data is preserved as-is through the element chain" do
    html = ~s(<form id="registration-form" phx-submit="register"></form>)

    {:ok, submission} =
      html
      |> find_form("#registration-form")
      |> render_submit(%{user: %{name: "Ada", role: "admin", settings: %{theme: "dark"}}})

    assert submission.data.user.name == "Ada"
    assert submission.data.user.settings.theme == "dark"
  end
end
