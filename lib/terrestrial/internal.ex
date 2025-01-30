defmodule Terrestrial.Internal do
  @moduledoc false
  def apply_edits(map, edits) do
    Enum.reduce(edits, map, & &1.(&2))
  end
end
