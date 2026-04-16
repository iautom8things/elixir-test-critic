# EXPECTED: passes
# BAD PRACTICE: Each test passes one nil field and verifies it's invalid.
# This tests Ecto's validate_required implementation, not your changeset's contract.
# If you add a new required field, there is no test that catches the omission
# unless you also add a new per-field test.
Mix.install([:ecto])

ExUnit.start(autorun: true)

defmodule DontTestEctoBad.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
  end
end

defmodule DontTestEctoItselfBadTest do
  use ExUnit.Case, async: true

  alias DontTestEctoBad.User

  # BAD: tests Ecto's behaviour on nil, not your changeset's required fields list
  test "rejects nil email" do
    cs = User.changeset(%User{}, %{name: "Alice", email: nil})
    refute cs.valid?
  end

  # BAD: same — this would pass even if :name was absent from validate_required,
  # because validate_required would simply not flag name and the test doesn't check
  # what fields have errors
  test "rejects nil name" do
    cs = User.changeset(%User{}, %{email: "a@b.com", name: nil})
    refute cs.valid?
  end

  # BAD: tests Ecto's format validation, not that you applied it to :email specifically
  test "validates email format" do
    cs = User.changeset(%User{}, %{name: "Alice", email: "bad"})
    refute cs.valid?
  end
end
