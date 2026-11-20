defmodule TestCritic.Credo.Options do
  @moduledoc false

  alias Credo.Check.Params
  alias Credo.Execution.ExecutionIssues
  alias Credo.IssueMeta
  alias Credo.SourceFile
  alias __MODULE__

  defmacro __using__(schema) do
    quote do
      @option_schema unquote(schema)

      @impl Credo.Check
      def run(source_file, params) do
        case Options.validate(params, __MODULE__, @option_schema) do
          {:ok, options} ->
            analyze(source_file, params, options)

          {:error, message} ->
            Options.issues(source_file, params, __MODULE__, message)
        end
      end

      @impl Credo.Check
      def run_on_all_source_files(exec, source_files, params) do
        case Options.validate(params, __MODULE__, @option_schema) do
          {:ok, _options} ->
            super(exec, source_files, params)

          {:error, message} ->
            Options.append_error(exec, source_files, params, __MODULE__, message)
        end
      end
    end
  end

  def validate(params, check, schema) do
    Enum.reduce_while(schema, {:ok, %{}}, fn {key, type}, {:ok, options} ->
      value =
        if Keyword.has_key?(params, key), do: params[key], else: Params.get(params, key, check)

      if valid?(value, type) do
        {:cont, {:ok, Map.put(options, key, value)}}
      else
        message =
          "Invalid Credo configuration for #{inspect(check)}. " <>
            "#{inspect(key)} must be #{describe(type)}, got #{inspect(value)}."

        {:halt, {:error, message}}
      end
    end)
  end

  def append_error(exec, source_files, params, check, message) do
    source = Enum.min_by(source_files, & &1.filename, fn -> nil end)
    ExecutionIssues.append(exec, issues(source, params, check, message))
  end

  def issues(%SourceFile{status: :valid} = source, params, check, message) do
    [check.format_issue(IssueMeta.for(source, params), message: message, line_no: 1)]
  end

  def issues(_source, _params, _check, _message), do: []

  defp valid?(value, :boolean), do: is_boolean(value)
  defp valid?(value, :nonnegative_integer), do: is_integer(value) and value >= 0
  defp valid?(value, :atom), do: is_atom(value)

  defp valid?(value, :path),
    do: is_binary(value) and byte_size(value) > 0 and String.valid?(value)

  defp valid?(value, :module) when is_atom(value),
    do: String.starts_with?(Atom.to_string(value), "Elixir.")

  defp valid?(value, {:list, type}), do: is_list(value) and Enum.all?(value, &valid?(&1, type))
  defp valid?(value, {:one_of, choices}), do: value in choices
  defp valid?(_value, _type), do: false

  defp describe(:boolean), do: "true or false"
  defp describe(:nonnegative_integer), do: "a nonnegative integer"
  defp describe({:list, :atom}), do: "a list of function-name atoms"
  defp describe({:list, :module}), do: "a list of Elixir module names"
  defp describe({:list, :path}), do: "a list of nonempty path strings"
  defp describe({:one_of, choices}), do: Enum.map_join(choices, " or ", &inspect/1)
end
