# EXPECTED: passes
# BAD PRACTICE: Attempts to test a unique_constraint without performing any DB insert.
# The changeset.errors list will always be empty because the database constraint
# never fires. The "assert" below is deliberately commented out — if uncommented
# it would always fail, proving the test is meaningless in the bad form.
Mix.install([:ecto])

ExUnit.start(autorun: false)

defmodule ConstraintBad.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "constraint_bad_users" do
    field :email, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end

defmodule ConstraintNeedsDbBadTest do
  use ExUnit.Case, async: true

  test "unique_constraint annotation does NOT produce errors without a DB insert" do
    # BAD: no Repo.insert — the constraint is just metadata on the changeset struct
    changeset = ConstraintBad.User.changeset(%ConstraintBad.User{}, %{email: "dup@test.com"})

    # This shows the constraint is annotated but errors are empty — no DB, no error
    assert changeset.valid? == true
    assert changeset.errors == []

    # If a developer incorrectly writes:
    #   assert changeset.errors[:email] != nil
    # …it will ALWAYS fail because no insert happened.
    # The constraint annotation alone changes nothing about validity.
    assert length(changeset.constraints) == 1
    assert hd(changeset.constraints).field == :email
  end
end

ExUnit.run()
