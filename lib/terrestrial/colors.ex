defmodule Terrestrial.Colors do
  # TODO Replace these with the closest Tailwind colors
  @moduledoc false
  def pink, do: "#ea60df"
  def purple, do: "#7b4dff"
  def blue, do: "#12a5ed"
  def moss, do: "#92b42c"
  def green, do: "#71c614"
  def orange, do: "#ff8400"
  def turquoise, do: "#22d2ba"
  def red, do: "#F5325B"
  def dark_yellow, do: "#eabd39"
  def dark_blue, do: "#7345f6"
  def coral, do: "#ea7369"
  def magenta, do: "#db4cb2"
  def brown, do: "#871c1c"
  def mint, do: "#6df0d2"
  def yellow, do: "#ffca00"
  def academy_yellow, do: "#fed40a"
  def gray, do: "#eff2fa"
  def dark_gray, do: "rgb(200 200 200)"
  def label_gray, do: "#808bab"

  @doc """
  Return a color based on index for things like bars and lines in series.
  """
  def to_default_color(index) do
    to_default(
      pink(),
      [
        purple(),
        pink(),
        blue(),
        green(),
        red(),
        yellow(),
        turquoise(),
        orange(),
        moss(),
        brown()
      ],
      index
    )
  end

  defp to_default(default, _colors, nil), do: default

  defp to_default(_default, colors, index) do
    Enum.at(colors, Integer.mod(index, length(colors)))
  end
end
