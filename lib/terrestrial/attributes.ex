defmodule Terrestrial.Attributes do
  @moduledoc """
  This module defines ways for editing elements.

  ## How it works

  All the functions return an anonymous function that takes and returns a config map.
  This function is later applied by the library.
  """

  defmodule Axis do
    @moduledoc false
    defstruct arrow: true, color: "", width: 1
  end

  @spec format(function()) :: (map() -> map())
  def format(func) do
    fn %{format: _} = config -> Map.put(config, :format, func) end
  end

  @spec color(String.t()) :: (map() -> map())
  def color(c) do
    fn %{color: _} = config ->
      if c == "" do
        config
      else
        Map.put(config, :color, c)
      end
    end
  end

  @spec border(String.t()) :: (map() -> map())
  def border(v) do
    fn %{border: _} = config -> Map.put(config, :border, v) end
  end

  @spec border_width(float()) :: (map() -> map())
  def border_width(v) do
    fn %{border_width: _} = config -> Map.put(config, :border_width, v) end
  end

  @spec opacity(float()) :: (map() -> map())
  def opacity(v) do
    fn %{opacity: _} = config -> Map.put(config, :opacity, v) end
  end

  @spec pinned(float()) :: (map() -> map())
  def pinned(v) do
    fn %{pinned: _} = config -> Map.put(config, :pinned, v) end
  end

  @spec height(float()) :: (map() -> map())
  def height(v) do
    fn %{height: _} = config -> Map.put(config, :height, v) end
  end

  @spec width(float()) :: (map() -> map())
  def width(v) do
    fn %{width: _} = config -> Map.put(config, :width, v) end
  end

  @spec length(float()) :: (map() -> map())
  def length(v) do
    fn %{length: _} = config -> Map.put(config, :length, v) end
  end

  # TODO Whats in a value
  @spec dashed(any()) :: (map() -> map())
  def dashed(value) do
    fn config -> Map.put(config, :dashed, value) end
  end

  @spec no_change() :: (map() -> map())
  def no_change do
    fn config -> config end
  end

  @spec no_arrow() :: (map() -> map())
  def no_arrow() do
    fn %{arrow: _} = config -> Map.put(config, :arrow, false) end
  end

  @spec move_left(float()) :: (map() -> map())
  def move_left(v) do
    fn %{x_off: _} = config -> Map.put(config, :x_off, config.x_off - v) end
  end

  @spec move_right(float()) :: (map() -> map())
  def move_right(v) do
    fn %{x_off: _} = config -> Map.put(config, :x_off, config.x_off + v) end
  end

  @spec move_up(float()) :: (map() -> map())
  def move_up(v) do
    fn %{y_off: _} = config -> Map.put(config, :y_off, config.y_off - v) end
  end

  @spec move_down(float()) :: (map() -> map())
  def move_down(v) do
    fn %{y_off: _} = config -> Map.put(config, :y_off, config.y_off + v) end
  end

  @spec hide_overflow() :: (map() -> map())
  def hide_overflow do
    fn %{hide_overflow: _} = config -> Map.put(config, :hide_overflow, true) end
  end

  @spec no_grid() :: (map() -> map())
  def no_grid do
    fn %{grid: _} = config -> Map.put(config, :grid, false) end
  end

  @spec with_grid() :: (map() -> map())
  def with_grid do
    fn %{grid: _} = config -> Map.put(config, :grid, true) end
  end

  @spec dot_grid() :: (map() -> map())
  def dot_grid do
    fn %{dot_grid: _} = config -> Map.put(config, :dot_grid, true) end
  end

  @spec x1(float()) :: (map() -> map())
  def x1(v) do
    fn %{x1: _} = config -> Map.put(config, :x1, v) end
  end

  @spec x2(float()) :: (map() -> map())
  def x2(v) do
    fn %{x2: _} = config -> Map.put(config, :x2, v) end
  end

  @spec y1(float()) :: (map() -> map())
  def y1(v) do
    fn %{y1: _} = config -> Map.put(config, :y1, v) end
  end

  @spec y2(float()) :: (map() -> map())
  def y2(v) do
    fn %{y2: _} = config -> Map.put(config, :y2, v) end
  end

  @spec rotate(float()) :: (map() -> map())
  def rotate(v) do
    fn %{rotate: _} = config -> Map.put(config, :rotate, config.rotate + v) end
  end

  # Doesn't return a config

  @doc """
  Given an axis, find the value closer to zero.
  """
  @spec zero(Terrestrial.Coordinates.axis()) :: float()
  def zero(%{min: _, max: _} = a) do
    # clamp
    0 |> max(a.min) |> min(a.max)
  end

  @doc """
  Given an axis, find a value in the middle
  """
  @spec middle(Terrestrial.Coordinates.axis()) :: float()
  def middle(%{min: _, max: _} = a) do
    a.min + (a.max - a.min) / 2
  end

  @doc """
  Given an axis, find a value at the given percentage
  """
  @spec percent(Terrestrial.Coordinates.axis(), float()) :: float()
  def percent(%{min: _, max: _} = a, per) do
    a.min + (a.max - a.min) * per
  end

  @doc """
  Change the lower bound of an axis.
  """
  def lowest(v, edit) do
    fn b ->
      Map.put(b, :min, edit.(v, b.min, b.data_min))
    end
  end

  @doc """
  Like lowest/2 but for upper bound.
  """
  def highest(v, edit) do
    fn b ->
      Map.put(b, :max, edit.(v, b.max, b.dataMax))
    end
  end

  def or_lower(least, original, _) do
    min(least, original)
  end

  def or_higher(most, original, _) do
    max(most, original)
  end

  def exactly(exact, _, _) do
    exact
  end

  def less(v, original, _) do
    original - v
  end

  def more(v, original, _) do
    original + v
  end

  @spec size(float()) :: (map() -> map())
  def size(v) do
    fn %{size: _} = config -> Map.put(config, :size, v) end
  end

  @spec linear() :: (map() -> map())
  def linear() do
    fn %{method: _} = config -> Map.put(config, :method, :linear) end
  end

  @spec monotone() :: (map() -> map())
  def monotone() do
    # TODO
    raise "monotone interpolation is not yet supported"
    fn %{method: _} = config -> Map.put(config, :method, :monotone) end
  end

  @spec circle() :: (map() -> map())
  def circle() do
    fn %{shape: _} = config -> Map.put(config, :shape, :circle) end
  end

  @spec triangle() :: (map() -> map())
  def triangle() do
    fn %{shape: _} = config -> Map.put(config, :shape, :triangle) end
  end

  @spec square() :: (map() -> map())
  def square() do
    fn %{shape: _} = config -> Map.put(config, :shape, :square) end
  end

  @spec diamond() :: (map() -> map())
  def diamond() do
    fn %{shape: _} = config -> Map.put(config, :shape, :diamond) end
  end

  @spec cross() :: (map() -> map())
  def cross() do
    fn %{shape: _} = config -> Map.put(config, :shape, :cross) end
  end

  @spec plus() :: (map() -> map())
  def plus() do
    fn %{shape: _} = config -> Map.put(config, :shape, :plus) end
  end

  @doc """
  Add arbitrary attributes to an element using a Keyword list.
  """
  @spec attrs(keyword()) :: (map() -> map())
  def attrs(v) do
    fn %{attrs: _} = config ->
      Map.put(config, :attrs, v)
    end
  end

  # COLORS

  def pink(), do: Terrestrial.Colors.pink()
  def purple(), do: Terrestrial.Colors.purple()
  def blue(), do: Terrestrial.Colors.blue()
  def green(), do: Terrestrial.Colors.green()
  def turquoise(), do: Terrestrial.Colors.turquoise()
  def red(), do: Terrestrial.Colors.red()
  def dark_yellow(), do: Terrestrial.Colors.dark_yellow()
  def dark_blue(), do: Terrestrial.Colors.dark_blue()
  def magenta(), do: Terrestrial.Colors.magenta()
  def brown(), do: Terrestrial.Colors.brown()
  def mint(), do: Terrestrial.Colors.mint()
  def yellow(), do: Terrestrial.Colors.yellow()
  def gray(), do: Terrestrial.Colors.gray()
  def dark_gray(), do: Terrestrial.Colors.dark_gray()
  def label_gray(), do: Terrestrial.Colors.label_gray()
end
