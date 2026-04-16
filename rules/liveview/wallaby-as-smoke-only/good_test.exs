# EXPECTED: passes
Mix.install([])

# Demonstrates: choosing LiveViewTest over Wallaby for standard LiveView interactions.
#
# GOOD — LiveViewTest handles all standard LiveView behaviour:
#
#   defmodule MyAppWeb.PostLiveTest do
#     use MyAppWeb.ConnCase, async: true
#
#     test "creates a post", %{conn: conn} do
#       {:ok, view, _html} = live(conn, ~p"/posts/new")
#       view |> form("#post-form", post: %{title: "Hello"}) |> render_submit()
#       assert render(view) =~ "Post created"
#     end
#
#     test "filters posts", %{conn: conn} do
#       {:ok, view, _html} = live(conn, ~p"/posts")
#       view |> element("[data-role='filter-active']") |> render_click()
#       assert_patch(view, ~p"/posts?status=active")
#     end
#   end
#
# GOOD — Wallaby only when JS is genuinely required:
#
#   defmodule MyAppWeb.RichTextEditorSmokeTest do
#     use MyAppWeb.FeatureCase, async: false
#
#     # Third-party JS widget — cannot be tested without a real browser
#     test "editor formats bold text", session do
#       session
#       |> visit("/posts/new")
#       |> click(Query.css("[data-testid='bold-button']"))
#       |> assert_has(Query.css(".ProseMirror strong"))
#     end
#   end

ExUnit.start(autorun: true)

defmodule WallabyChoiceGoodTest do
  use ExUnit.Case, async: true

  defp requires_js?(feature) do
    js_features = [:rich_text_editor, :file_upload_drag_drop, :google_maps, :clipboard_api]
    feature in js_features
  end

  defp test_tool_for(feature) do
    if requires_js?(feature), do: :wallaby, else: :liveview_test
  end

  test "standard CRUD form uses LiveViewTest" do
    assert test_tool_for(:create_post_form) == :liveview_test
  end

  test "filter/search interaction uses LiveViewTest" do
    assert test_tool_for(:filter_by_status) == :liveview_test
  end

  test "pagination uses LiveViewTest" do
    assert test_tool_for(:paginate_results) == :liveview_test
  end

  test "rich text editor uses Wallaby (JS widget)" do
    assert test_tool_for(:rich_text_editor) == :wallaby
  end

  test "drag-and-drop file upload uses Wallaby (JS required)" do
    assert test_tool_for(:file_upload_drag_drop) == :wallaby
  end

  test "LiveViewTest is always async-safe, Wallaby typically is not" do
    # LiveViewTest: async: true works fine
    # Wallaby: async: false required because it manages a browser session
    liveview_test_async = true
    wallaby_default_async = false

    assert liveview_test_async == true
    assert wallaby_default_async == false
  end
end
