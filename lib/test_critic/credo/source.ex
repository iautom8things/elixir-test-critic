defmodule TestCritic.Credo.Source do
  @moduledoc false

  alias Credo.SourceFile

  def path_parts(%SourceFile{filename: filename}) do
    filename
    |> Path.relative_to_cwd()
    |> Path.split()
    |> project_path()
  end

  defp project_path(["." | rest]), do: project_path(rest)
  defp project_path(["apps", _app | rest]), do: rest
  defp project_path(parts), do: parts

  def expressions({:__block__, _, expressions}), do: expressions
  def expressions(expression), do: [expression]

  def reduce(%SourceFile{} = source, acc, visit) do
    reduce(SourceFile.ast(source), %{aliases: %{}, imports: %{}}, acc, visit)
  end

  def reduce(ast, scope, acc, visit) do
    {_scope, acc} = walk(ast, scope, acc, visit)
    acc
  end

  def module_name({:__aliases__, _, [:"Elixir" | parts]}, _scope), do: parts

  def module_name({:__aliases__, _, [first | rest]}, scope) when is_atom(first) do
    Map.get(scope.aliases, first, [first]) ++ rest
  end

  def module_name({:__MODULE__, _, _}, _scope), do: :__MODULE__
  def module_name(module, _scope) when is_atom(module), do: module
  def module_name(_ast, _scope), do: nil

  def imported?(scope, module, name, arity) do
    case Map.fetch(scope.imports, module) do
      {:ok, [only: functions]} when is_list(functions) -> {name, arity} in functions
      {:ok, [except: functions]} when is_list(functions) -> {name, arity} not in functions
      {:ok, [only: :macros]} -> false
      {:ok, _opts} -> true
      :error -> false
    end
  end

  def call({{:., _, [receiver, name]}, meta, args}, scope)
      when is_atom(name) and is_list(args) do
    {module_name(receiver, scope), name, meta, args}
  end

  def call({name, meta, args}, _scope) when is_atom(name) and is_list(args) do
    {:local, name, meta, args}
  end

  def call(_ast, _scope), do: nil

  defp walk({:quote, _, _}, scope, acc, _visit), do: {scope, acc}

  defp walk({:&, _, [{:/, _, [_function, arity]}]}, scope, acc, _visit) when is_integer(arity),
    do: {scope, acc}

  defp walk({:__block__, _, expressions}, scope, acc, visit) do
    Enum.reduce(expressions, {scope, acc}, fn expression, {scope, acc} ->
      walk(expression, scope, acc, visit)
    end)
  end

  defp walk({kind, _, args} = node, scope, acc, visit) when kind in [:alias, :import] do
    {update_scope(kind, args, scope), visit_node(node, scope, acc, visit)}
  end

  defp walk({:|>, _, [left, {form, meta, args}]}, scope, acc, visit) when is_list(args) do
    walk_node({form, meta, [left | args]}, [form, left, args], scope, acc, visit)
  end

  defp walk({form, meta, args} = node, scope, acc, visit) when is_list(meta),
    do: walk_node(node, [form, args], scope, acc, visit)

  defp walk({left, right}, scope, acc, visit) do
    {scope, walk_children([left, right], scope, acc, visit)}
  end

  defp walk(nodes, scope, acc, visit) when is_list(nodes) do
    {scope, walk_children(nodes, scope, acc, visit)}
  end

  defp walk(_literal, scope, acc, _visit), do: {scope, acc}

  defp walk_node(node, children, scope, acc, visit) do
    acc =
      case visit.(node, scope, acc) do
        {:skip, acc} -> acc
        acc -> walk_children(children, scope, acc, visit)
      end

    {scope, acc}
  end

  defp walk_children(nodes, scope, acc, visit) do
    Enum.reduce(nodes, acc, fn node, acc -> reduce(node, scope, acc, visit) end)
  end

  defp visit_node(node, scope, acc, visit) do
    case visit.(node, scope, acc) do
      {:skip, acc} -> acc
      acc -> acc
    end
  end

  defp update_scope(:alias, [{{:., _, [base, :{}]}, _, children}], scope) do
    case module_name(base, scope) do
      base when is_list(base) ->
        Enum.reduce(children, scope, fn
          {:__aliases__, _, parts}, scope -> put_alias(scope, List.last(parts), base ++ parts)
          _child, scope -> scope
        end)

      _ ->
        scope
    end
  end

  defp update_scope(:alias, [target | options], scope) do
    case module_name(target, scope) do
      parts when is_list(parts) ->
        name =
          case options do
            [[as: {:__aliases__, _, [name]}]] -> name
            _ -> List.last(parts)
          end

        put_alias(scope, name, parts)

      _ ->
        scope
    end
  end

  defp update_scope(:import, [target | options], scope) do
    module = module_name(target, scope)
    %{scope | imports: Map.put(scope.imports, module, List.first(options, []))}
  end

  defp update_scope(_kind, _args, scope), do: scope

  defp put_alias(scope, name, parts) do
    %{scope | aliases: Map.put(scope.aliases, name, parts)}
  end
end
