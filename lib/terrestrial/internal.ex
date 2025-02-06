defmodule Terrestrial.Internal do
  @moduledoc false
  def apply_edits(map, edits) do
    Enum.reduce(edits, map, & &1.(&2))
  end

  @doc """
  Returns the list with each element wrapped in a tuple alongside its previous and next element.
  Previous and next will be nil if at the start or end of list.

  TODO Could be made much more performant.
  """
  def with_surround(list, nil_element \\ nil) when is_list(list) do
    count = length(list)

    Enum.zip([
      [nil_element | Enum.take(list, count - 1)],
      list,
      Enum.drop(list, 1) ++ [nil_element]
    ])
  end

  def clamp(n, min, max) do
    n |> max(min) |> min(max)
  end
end
