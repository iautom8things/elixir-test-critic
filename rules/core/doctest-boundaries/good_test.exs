# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule DoctestBoundariesPure do
  @moduledoc """
  Pure functions are ideal doctest candidates.
  """

  @doc """
  Checks if a string is a valid email address format.

      iex> DoctestBoundariesPure.valid_email?("alice@example.com")
      true

      iex> DoctestBoundariesPure.valid_email?("not-an-email")
      false
  """
  def valid_email?(email), do: Regex.match?(~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/, email)

  @doc """
  Formats a name as "Last, First".

      iex> DoctestBoundariesPure.format_name("Alice", "Smith")
      "Smith, Alice"
  """
  def format_name(first, last), do: "#{last}, #{first}"
end

defmodule DoctestBoundariesGoodTest do
  use ExUnit.Case, async: true

  # In a standalone script, doctest/1 cannot access beam files.
  # In a real Mix project you would write: doctest DoctestBoundariesPure
  # Here we test the same pure functions as regular assertions.

  describe "valid_email?/1" do
    test "returns true for valid email format" do
      assert DoctestBoundariesPure.valid_email?("alice@example.com")
    end

    test "returns false for string without @ symbol" do
      refute DoctestBoundariesPure.valid_email?("not-an-email")
    end
  end

  describe "format_name/2" do
    test "formats first and last name as Last, First" do
      assert DoctestBoundariesPure.format_name("Alice", "Smith") == "Smith, Alice"
    end
  end
end
