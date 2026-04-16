defmodule TestCritic.RuleParserTest do
  use ExUnit.Case

  alias TestCritic.RuleParser

  describe "parse/2" do
    test "extracts YAML frontmatter and body" do
      content = """
      ---
      id: ETC-CORE-001
      title: "Test rule"
      category: core
      severity: warning
      ---

      # Test Rule

      Some body content.
      """

      assert {:ok, %{frontmatter: fm, body: body}} = RuleParser.parse(content, "test")
      assert fm["id"] == "ETC-CORE-001"
      assert fm["title"] == "Test rule"
      assert fm["category"] == "core"
      assert fm["severity"] == "warning"
      assert body =~ "Test Rule"
      assert body =~ "Some body content."
    end

    test "returns error when no frontmatter present" do
      content = "# No frontmatter here"
      assert {:error, _} = RuleParser.parse(content, "test")
    end
  end

  describe "discover_rules/1" do
    @tag :tmp_dir
    test "returns empty list for empty directory", %{tmp_dir: tmp_dir} do
      assert RuleParser.discover_rules(tmp_dir) == []
    end
  end

  describe "category_order/1" do
    test "core comes first" do
      assert RuleParser.category_order("core") == 0
    end

    test "organization comes last" do
      assert RuleParser.category_order("organization") == 10
    end

    test "unknown categories sort to end" do
      assert RuleParser.category_order("unknown") == 999
    end
  end
end
