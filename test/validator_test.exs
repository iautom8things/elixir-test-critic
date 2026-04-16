defmodule TestCritic.ValidatorTest do
  use ExUnit.Case

  alias TestCritic.Validator

  @fixture_dir "test/fixtures/validator"

  setup do
    File.rm_rf!(@fixture_dir)
    File.mkdir_p!(@fixture_dir)
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "validate_all/1" do
    test "returns :ok for empty rules directory" do
      assert :ok = Validator.validate_all(@fixture_dir)
    end

    test "catches missing good_test.exs" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      File.write!(Path.join(rule_dir, "RULE.md"), """
      ---
      id: ETC-CORE-001
      title: "Test rule"
      category: core
      severity: warning
      summary: "A test rule"
      principles:
        - async-default
      applies_when:
        - "always"
      ---

      # Test rule
      """)

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "missing good_test.exs"))
    end

    test "catches invalid EXPECTED comment in bad_test.exs" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      write_valid_rule!(rule_dir, "core")
      File.write!(Path.join(rule_dir, "good_test.exs"), "# good")
      File.write!(Path.join(rule_dir, "bad_test.exs"), "# no expected comment\nIO.puts(:hi)")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "EXPECTED"))
    end

    test "catches unexpected files" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      write_valid_rule!(rule_dir, "core")
      File.write!(Path.join(rule_dir, "good_test.exs"), "# good")
      File.write!(Path.join(rule_dir, "random.txt"), "unexpected")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "unexpected file: random.txt"))
    end

    test "catches category mismatch" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      File.write!(Path.join(rule_dir, "RULE.md"), """
      ---
      id: ETC-OTP-001
      title: "Wrong category"
      category: otp
      severity: warning
      summary: "Misplaced rule"
      principles:
        - async-default
      applies_when:
        - "always"
      ---

      # Wrong category
      """)

      File.write!(Path.join(rule_dir, "good_test.exs"), "# good")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "category 'otp' does not match directory 'core'"))
    end

    test "catches critical severity without does_not_apply_when" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      File.write!(Path.join(rule_dir, "RULE.md"), """
      ---
      id: ETC-CORE-001
      title: "Critical rule"
      category: core
      severity: critical
      summary: "A critical rule"
      principles:
        - async-default
      applies_when:
        - "always"
      ---

      # Critical rule
      """)

      File.write!(Path.join(rule_dir, "good_test.exs"), "# good")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "does_not_apply_when"))
    end

    test "passes valid rule" do
      rule_dir = Path.join([@fixture_dir, "core", "test-rule"])
      File.mkdir_p!(rule_dir)

      write_valid_rule!(rule_dir, "core")
      File.write!(Path.join(rule_dir, "good_test.exs"), "# good")
      File.write!(Path.join(rule_dir, "bad_test.exs"), "# EXPECTED: passes\n# BAD")

      assert :ok = Validator.validate_all(@fixture_dir)
    end

    test "catches duplicate rule IDs across rules" do
      write_rule!("core", "rule-one", id: "ETC-CORE-001")
      write_rule!("core", "rule-two", id: "ETC-CORE-001")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "Duplicate rule ID: ETC-CORE-001"))
    end

    test "catches non-bidirectional related_rules" do
      write_rule!("core", "rule-a", id: "ETC-CORE-001", related_rules: ["ETC-CORE-002"])
      write_rule!("core", "rule-b", id: "ETC-CORE-002")

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "ETC-CORE-001 lists ETC-CORE-002"))
    end

    test "accepts bidirectional related_rules" do
      write_rule!("core", "rule-a", id: "ETC-CORE-001", related_rules: ["ETC-CORE-002"])
      write_rule!("core", "rule-b", id: "ETC-CORE-002", related_rules: ["ETC-CORE-001"])

      assert :ok = Validator.validate_all(@fixture_dir)
    end

    test "catches conflicts_with references to non-existent rules" do
      write_rule!("core", "rule-a", id: "ETC-CORE-001", conflicts_with: ["ETC-CORE-999"])

      assert {:error, errors} = Validator.validate_all(@fixture_dir)
      assert Enum.any?(errors, &String.contains?(&1, "conflicts_with references non-existent rule: ETC-CORE-999"))
    end
  end

  defp write_rule!(category, slug, opts) do
    rule_dir = Path.join([@fixture_dir, category, slug])
    File.mkdir_p!(rule_dir)

    id = Keyword.fetch!(opts, :id)
    related = Keyword.get(opts, :related_rules, [])
    conflicts = Keyword.get(opts, :conflicts_with, [])

    related_yaml =
      case related do
        [] -> ""
        ids -> "related_rules:\n" <> Enum.map_join(ids, "\n", &"  - #{&1}") <> "\n"
      end

    conflicts_yaml =
      case conflicts do
        [] -> ""
        ids -> "conflicts_with:\n" <> Enum.map_join(ids, "\n", &"  - #{&1}") <> "\n"
      end

    File.write!(Path.join(rule_dir, "RULE.md"), """
    ---
    id: #{id}
    title: "#{slug}"
    category: #{category}
    severity: warning
    summary: "Test rule #{slug}"
    principles:
      - async-default
    applies_when:
      - "always"
    #{related_yaml}#{conflicts_yaml}---

    # #{slug}
    """)

    File.write!(Path.join(rule_dir, "good_test.exs"), "# good")
  end

  defp write_valid_rule!(dir, category) do
    File.write!(Path.join(dir, "RULE.md"), """
    ---
    id: ETC-CORE-001
    title: "Test rule"
    category: #{category}
    severity: warning
    summary: "A test rule"
    principles:
      - async-default
    applies_when:
      - "always"
    ---

    # Test rule
    """)
  end
end
