defmodule Terrestrial.Interpolation do
  @moduledoc false
  @type method() :: :linear | :monotone | :stepped

  defstruct method: nil,
            color: Terrestrial.Colors.pink(),
            width: 1.0,
            opacity: 0.0,
            # TODO Design currently not suppported
            design: nil,
            dashed: [],
            attrs: []

  @type t :: %__MODULE__{
          method: method() | nil,
          color: String.t(),
          width: float(),
          opacity: float(),
          design: any(),
          dashed: list(),
          attrs: list()
        }

  @doc """
  Doesn't support sections yets, pretends every point is consecutive.
  """
  @spec linear(list(list())) :: list(list())
  def linear(points) do
    points
    |> List.flatten()
    |> Enum.map(fn %{x: x, y: y} -> {:line, x, y} end)
  end
end
