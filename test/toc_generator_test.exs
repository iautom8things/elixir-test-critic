defmodule TestCritic.TocGeneratorTest do
  use ExUnit.Case

  alias TestCritic.TocGenerator

  @fixture_dir "test/fixtures/toc_gen"
  @template_path "templates/toc_template.md.eex"
  @output_path "test/fixtures/toc_gen/output/RULES_REFERENCE.md"

  setup do
    File.rm_rf!(@fixture_dir)
    rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
    File.mkdir_p!(rule_dir)
    File.mkdir_p!(Path.dirname(@output_path))

    File.write!(Path.join(rule_dir, "RULE.md"), """
    ---
    id: ETC-CORE-001
    title: "Test rule"
    category: core
    severity: warning
    summary: "A test rule for generation"
    principles:
      - async-default
    applies_when:
      - "always"
    ---

    # Test rule
    """)

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  test "generates TOC from fixture rules" do
    assert {:ok, path} = TocGenerator.generate(@fixture_dir, @template_path, @output_path)
    assert File.exists?(path)

    content = File.read!(path)
    assert content =~ "ETC-CORE-001"
    assert content =~ "Test rule"
    assert content =~ "warning"
  end

  test "includes severity sections" do
    assert {:ok, _} = TocGenerator.generate(@fixture_dir, @template_path, @output_path)
    content = File.read!(@output_path)
    assert content =~ "Critical Rules"
    assert content =~ "Warning Rules"
  end
end
