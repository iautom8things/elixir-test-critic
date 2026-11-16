# EXPECTED: passes
# BAD PRACTICE: two tests that pass while the application's changeset is wrong.
# User.changeset/2 below forgot to require :name. Neither test notices, because
# one never calls User.changeset/2 and the other asserts only `refute valid?`.
Mix.install([:ecto])

ExUnit.start(autorun: true)

defmodule DontTestEctoBad.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
  end

  # The bug: :name is missing from validate_required.
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:email])
  end
end

defmodule DontTestEctoItselfBadTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias DontTestEctoBad.User

  # BAD: builds its own changeset. This checks that Ecto's validate_required
  # works. It says nothing about what User.changeset/2 requires.
  test "name is required" do
    changeset =
      %User{}
      |> cast(%{email: "alice@example.com"}, [:name, :email])
      |> validate_required([:name])

    assert {:name, _} = List.keyfind(changeset.errors, :name, 0)
  end

  # BAD: calls the real function but only refutes valid?. The changeset is
  # invalid because :email is missing, not because of :name.
  test "rejects nil name" do
    changeset = User.changeset(%User{}, %{name: nil})

    refute changeset.valid?
  end
end
