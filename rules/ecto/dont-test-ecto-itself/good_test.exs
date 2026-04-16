# EXPECTED: passes
Mix.install([:ecto])

ExUnit.start(autorun: true)

defmodule DontTestEcto.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
    field :bio, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :bio])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:bio, max: 200)
  end
end

defmodule DontTestEctoItselfGoodTest do
  use ExUnit.Case, async: true

  alias DontTestEcto.User

  defp changeset(attrs), do: User.changeset(%User{}, attrs)

  # Good: one test covers all required fields simultaneously
  # If :name is removed from validate_required, this test fails immediately
  test "all required fields must be present" do
    cs = changeset(%{})
    error_fields = Keyword.keys(cs.errors)
    assert :name in error_fields
    assert :email in error_fields
    refute :bio in error_fields  # bio is optional
  end

  test "accepts fully valid data" do
    cs = changeset(%{name: "Alice", email: "alice@example.com", bio: "Short bio"})
    assert cs.valid?
  end

  # Good: tests YOUR rule about email format, not that validate_format works
  test "email must contain @" do
    cs = changeset(%{name: "Alice", email: "notanemail"})
    refute cs.valid?
    assert cs.errors[:email] != nil
  end

  # Good: tests YOUR rule about bio length limit
  test "bio is limited to 200 characters" do
    long_bio = String.duplicate("x", 201)
    cs = changeset(%{name: "Alice", email: "alice@example.com", bio: long_bio})
    refute cs.valid?
    assert cs.errors[:bio] != nil
  end
end
