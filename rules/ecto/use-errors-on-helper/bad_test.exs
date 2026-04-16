# EXPECTED: passes
# BAD PRACTICE: Directly pattern matches against Ecto's internal error tuple format.
# This is verbose, fragile, and harder to read than using an errors_on/1 helper.
Mix.install([:ecto])

ExUnit.start(autorun: true)

defmodule ErrorsOnBad.User do
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

defmodule UseErrorsOnHelperBadTest do
  use ExUnit.Case, async: true

  alias ErrorsOnBad.User

  # BAD: reaching into Ecto's internal keyword list structure with tuple patterns
  test "email is required" do
    cs = User.changeset(%User{}, %{name: "Alice"})
    # Fragile — tied to Ecto's exact tuple format {message, opts}
    assert {:email, {"can't be blank", [validation: :required]}} in cs.errors
  end

  # BAD: using List.keyfind and then matching the inner tuple
  test "name is required" do
    cs = User.changeset(%User{}, %{email: "a@b.com"})
    {_field, {msg, _opts}} = List.keyfind(cs.errors, :name, 0)
    assert msg == "can't be blank"
  end

  # BAD: Keyword.get returns the tuple, requiring another match step
  test "email format is validated" do
    cs = User.changeset(%User{}, %{name: "Alice", email: "bad"})
    {msg, _opts} = Keyword.get(cs.errors, :email)
    assert msg =~ "invalid"
  end
end
