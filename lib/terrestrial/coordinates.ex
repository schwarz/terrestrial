defmodule Terrestrial.Coordinates do
  @typedoc "used to translate cartesian coordinates into SVG ones and back"
  @type plane :: %{x: axis(), y: axis()}

  @typedoc """
  - *data_min* is the lowest value of your data
  - *data_max* is the highest value of your data
  - *min* is the lowest value of your axis
  - *max* is the highest value of your axis
  """
  @type axis :: %{
          length: float(),
          data_min: float(),
          data_max: float(),
          min: float(),
          max: float()
        }
  @type point :: %{x: float(), y: float()}
  @type position :: %{x1: float(), x2: float(), y1: float(), y2: float()}
  @type anchor :: :start | :middle | :end

  @type tickConfig :: %{color: String.t(), length: integer(), width: float(), attrs: any()}

  def x_tick(plane, tickConfig, point), do: tick(plane, tickConfig, true, point)
  def y_tick(plane, tickConfig, point), do: tick(plane, tickConfig, false, point)

  @spec tick(plane(), tickConfig(), boolean(), point()) :: map()
  def tick(plane, config, is_x, point) do
    # line
    %{
      stroke: config.color,
      stroke_width: to_string(config.width()),
      x1: point.x |> to_svg_x(plane) |> to_string(),
      x2: (point.x + if(is_x, do: 0, else: -config.length)) |> to_svg_x(plane) |> to_string(),
      y1: point.y |> to_svg_y(plane) |> to_string(),
      y2: (point.y + if(is_x, do: config.length, else: 0)) |> to_svg_y(plane) |> to_string()
    }
  end

  def scale_svg_x(plane, value) do
    value * (inner_width(plane) / range(plane.x))
  end

  def scale_svg_y(plane, value) do
    value * (inner_height(plane) / range(plane.y))
  end

  @spec to_svg_x(float(), plane()) :: float()
  def to_svg_x(value, plane) do
    scale_svg_x(plane, value - plane.x.min + plane.x.margin_min)
  end

  @spec to_svg_y(float(), plane()) :: float()
  def to_svg_y(value, plane) do
    scale_svg_y(plane, plane.y.max - value + plane.y.margin_min)
  end

  def scale_cartesian_x(plane, value) do
    value * range(plane.x) / inner_width(plane)
  end

  def scale_cartesian_y(plane, value) do
    value * range(plane.y) / inner_height(plane)
  end

  defp range(axis) do
    diff = axis.max - axis.min
    if diff > 0, do: diff, else: 1
  end

  defp inner_width(plane) do
    inner_length(plane.x)
  end

  defp inner_height(plane) do
    inner_length(plane.y)
  end

  defp inner_length(axis) do
    max(1, axis.length - axis.margin_min - axis.margin_max)
  end

  def fold_position(data, func) do
    fold = fn datum, pos_or_nil ->
      case pos_or_nil do
        nil ->
          func.(datum)

        pos ->
          p = func.(datum)

          %{
            x1: min(p.x1, pos.x1),
            x2: max(p.x2, pos.x2),
            y1: min(p.y1, pos.y1),
            y2: max(p.y2, pos.y2)
          }
      end
    end

    pos = Enum.reduce(data, nil, fold)
    if pos, do: pos, else: %{x1: 0, x2: 0, y1: 0, y2: 0}
  end
end
