defmodule Terrestrial.Internal do
  def apply_edits(map, edits) do
    Enum.reduce(edits, map, & &1.(&2))
  end
end
