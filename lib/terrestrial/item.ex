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
end
