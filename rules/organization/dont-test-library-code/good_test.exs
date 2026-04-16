# EXPECTED: passes
# Demonstrates: testing YOUR logic on top of libraries, not the libraries themselves.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated Ecto-like changeset (no actual Ecto needed for this demo)
defmodule MyApp.DontTestLibGoodTest.Changeset do
  defstruct [:data, :changes, :errors, :valid?]

  def cast(schema, attrs, fields) do
    changes = Map.take(attrs, fields)
    %__MODULE__{data: schema, changes: changes, errors: [], valid?: true}
  end

  def validate_required(%__MODULE__{changes: changes} = cs, fields) do
    errors =
      Enum.flat_map(fields, fn field ->
        if Map.get(changes, field) in [nil, ""],
          do: [{field, "can't be blank"}],
          else: []
      end)

    %{cs | errors: cs.errors ++ errors, valid?: cs.valid? and errors == []}
  end

  def validate_format(%__MODULE__{changes: changes} = cs, field, regex) do
    value = Map.get(changes, field, "")

    if is_binary(value) and Regex.match?(regex, value) do
      cs
    else
      error = {field, "has invalid format"}
      %{cs | errors: cs.errors ++ [error], valid?: false}
    end
  end

  def errors_on(%__MODULE__{errors: errors}) do
    Enum.group_by(errors, &elem(&1, 0), &elem(&1, 1))
  end
end

defmodule MyApp.DontTestLibGoodTest.User do
  alias MyApp.DontTestLibGoodTest.Changeset

  defstruct [:id, :email, :password_hash]

  def changeset(user, attrs) do
    user
    |> Changeset.cast(attrs, [:email])
    |> Changeset.validate_required([:email])
    |> Changeset.validate_format(:email, ~r/@/)
  end

  def format_for_api(%__MODULE__{id: id, email: email}) do
    # Custom logic: only expose public fields
    %{id: id, email: email}
  end
end

defmodule MyApp.DontTestLibGoodTest do
  use ExUnit.Case, async: true

  alias MyApp.DontTestLibGoodTest.{User, Changeset}

  # GOOD: Testing YOUR validation rule — email is required
  test "user changeset is invalid without email" do
    cs = User.changeset(%User{}, %{})
    refute cs.valid?
    assert "can't be blank" in Changeset.errors_on(cs)[:email]
  end

  # GOOD: Testing YOUR custom format rule
  test "user changeset rejects email without @ symbol" do
    cs = User.changeset(%User{}, %{email: "notanemail"})
    refute cs.valid?
    assert "has invalid format" in Changeset.errors_on(cs)[:email]
  end

  test "user changeset is valid with a proper email" do
    cs = User.changeset(%User{}, %{email: "alice@example.com"})
    assert cs.valid?
  end

  # GOOD: Testing YOUR format_for_api logic — password_hash is excluded
  test "format_for_api/1 excludes sensitive fields" do
    user = %User{id: 1, email: "alice@example.com", password_hash: "secret_hash"}
    result = User.format_for_api(user)
    refute Map.has_key?(result, :password_hash)
    assert result.email == "alice@example.com"
    assert result.id == 1
  end
end
