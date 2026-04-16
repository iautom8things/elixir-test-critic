# EXPECTED: passes
Mix.install([:ecto])

ExUnit.start(autorun: true)

# A minimal inline schema — no Repo, no database
defmodule EctoNoDB.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
    field :age, :integer
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_number(:age, greater_than: 0)
  end
end

defmodule ChangesetWithoutDbGoodTest do
  use ExUnit.Case, async: true

  defp changeset(attrs), do: EctoNoDB.User.changeset(%EctoNoDB.User{}, attrs)

  test "valid changeset with all required fields" do
    cs = changeset(%{name: "Alice", email: "alice@example.com", age: 30})
    assert cs.valid?
  end

  test "invalid when email is missing" do
    cs = changeset(%{name: "Alice"})
    refute cs.valid?
    assert cs.errors[:email] != nil
  end

  test "invalid when name is missing" do
    cs = changeset(%{email: "alice@example.com"})
    refute cs.valid?
    assert cs.errors[:name] != nil
  end

  test "invalid when email format is wrong" do
    cs = changeset(%{name: "Alice", email: "not-an-email"})
    refute cs.valid?
    assert cs.errors[:email] != nil
  end

  test "invalid when age is zero or negative" do
    cs = changeset(%{name: "Alice", email: "alice@example.com", age: 0})
    refute cs.valid?
    assert cs.errors[:age] != nil
  end
end
