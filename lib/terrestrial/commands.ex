defmodule Terrestrial.Commands do
  @moduledoc """
  Helpers for working with SVG paths.
  """
  import Terrestrial.Coordinates, only: [to_svg_x: 2, to_svg_y: 2]

  @doc "Generate the d attribute of a path elment"
  @spec description(term(), term()) :: String.t()
  def description(plane, cmds) do
    cmds
    |> Enum.map(fn c -> translate(c, plane) end)
    |> Enum.map_join(" ", fn c -> string_command(c) end)
  end

  @spec translate(term(), Terrestrial.Coordinates.plane()) :: term()
  def translate(cmd, plane) do
    case cmd do
      {:move, x, y} ->
        {:move, to_svg_x(x, plane), to_svg_y(y, plane)}

      {:line, x, y} ->
        {:line, to_svg_x(x, plane), to_svg_y(y, plane)}

      {:arc, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y} ->
        {:arc, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, to_svg_x(x, plane),
         to_svg_y(y, plane)}
    end
  end

  @spec string_command(term()) :: String.t()
  def string_command(cmd) do
    case cmd do
      {:move, x, y} ->
        "M" <> point_to_string(x, y)

      {:line, x, y} ->
        "L" <> point_to_string(x, y)

      {:arc, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y} ->
        "A " <>
          Enum.join(
            [
              point_to_string(rx, ry),
              to_string(x_axis_rotation),
              boolean_to_integer_string(large_arc_flag),
              boolean_to_integer_string(sweep_flag),
              point_to_string(x, y)
            ],
            " "
          )

      _ ->
        raise "command not yet implemented"
    end
  end

  @spec point_to_string(float(), float()) :: String.t()
  defp point_to_string(x, y) do
    "#{x} #{y}"
  end

  # @spec points_to_string(list({float(), float()})) :: String.t()
  # defp points_to_string(points) do
  #  points
  #  |> Enum.map(fn {x, y} -> point_to_string(x, y) end)
  #  |> Enum.join(",")
  # end

  # defp boolean_to_string(bool), do: if(bool, do: "True", else: "False")
  defp boolean_to_integer_string(bool), do: if(bool, do: "1", else: "0")
end
