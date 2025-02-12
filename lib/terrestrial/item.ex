defmodule Terrestrial.Item do
  @moduledoc false
  defstruct render: nil,
            limits: nil,
            to_position: nil,
            presentation: nil,
            color: "",
            datum: nil,
            x1: 0.0,
            x2: 0.0,
            y: 0.0,
            identification: %{
              property_index: 0,
              dot_item_index: 0
            }

  def render_item(%__MODULE__{} = item, plane) do
    item.render.(plane, item.to_position.(plane))
  end

  defmodule Identification do
    @moduledoc """
    * stack_index: Index of the stack.
    * series_index: Index of the series within a stack.
    * absolute_index: Index of series within the total set of series.
    * data_index: Index of data point within data.
    * element_index: Index of element within chart.
    """
    defstruct stack_index: -1,
              series_index: -1,
              absolute_index: -1,
              data_index: -1,
              element_index: -1

    @type t :: %__MODULE__{
            stack_index: integer(),
            series_index: integer(),
            absolute_index: integer(),
            data_index: integer(),
            element_index: integer()
          }
  end
end
