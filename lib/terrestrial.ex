defmodule Terrestrial do
  @moduledoc ~S'''
  Documentation for `Terrestrial`.


  ## Examples

      defmodule MyAppWeb.DemoLive do
        use MyAppWeb, :live_view
        alias Terrestrial, as: C

        def render(assigns) do
          assigns = assign(assigns, data: data())

          ~H"""
            <C.chart elements={[C.axis_x()]}
          """
        end

        def data() do
          [
            %{x: 1, y: 2},
            %{x: 2, y: 3},
            %{x: 3, y: 4},
            %{x: 4, y: 3},
            %{x: 5, y: 2},
            %{x: 6, y: 4},
            %{x: 7, y: 5}
          ]
        end
      end
  '''

  use Phoenix.Component

  import Terrestrial.Internal, only: [apply_edits: 2]

  alias Terrestrial.Attributes, as: CA
  alias Terrestrial.Coordinates, as: Coords

  attr :id, :string, default: nil
  attr :elements, :list, default: []
  attr :edits, :list, default: []

  @doc """
  """
  def chart(assigns) do
    config =
      apply_edits(
        %{
          width: 300,
          height: 300,
          margin: %{top: 0, bottom: 0, left: 0, right: 0},
          padding: %{top: 0, bottom: 0, left: 0, right: 0},
          range: [],
          domain: []
        },
        assigns.edits
      )

    # Elements tagged with :index need to be called with a serial index so individual chart items can get unique IDs
    {indexed_elements, _index} =
      Enum.reduce(assigns.elements, {[], 0}, fn el, {acc, index} ->
        case el do
          {:indexed, to_el_and_index} ->
            {new_el, new_index} = to_el_and_index.(index)
            {[new_el | acc], new_index}

          _ ->
            {[el | acc], index}
        end
      end)

    has_grid =
      Enum.any?(indexed_elements, fn el ->
        case el do
          {:grid_element, _} -> true
          _ -> false
        end
      end)

    elements = if has_grid, do: indexed_elements, else: indexed_elements ++ [grid([])]
    plane = define_plane(config, elements)
    items = get_items(plane, elements)
    legends_ = get_legends(elements)
    tick_values = get_tick_values(plane, items, elements)

    {before_elems, chart_elems, after_elems} =
      view_elements(config, plane, tick_values, items, legends_, elements)

    Phoenix.LiveView.TagEngine.component(
      Terrestrial.Svg.container(plane, config, before_elems, chart_elems, after_elems),
      [],
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  # TODO Test this
  def line(edits) do
    {:svg_element,
     fn plane ->
       Terrestrial.Svg.line(plane, edits)
     end}
  end

  def axis_x(edits \\ []) do
    defaults = %{pinned: &CA.zero/1, color: "", arrow: true, width: 1, limits: []}
    config = apply_edits(defaults, edits)

    add_tick_values = fn plane, ts ->
      Map.put(ts, :axis_y, [config.pinned.(plane.y)] ++ ts.axis_y)
    end

    view = fn plane ->
      limit_x = Terrestrial.Internal.apply_edits(plane.x, config.limits)

      line_edits = [
        CA.color(config.color),
        CA.width(config.width),
        CA.y1(config.pinned.(plane.y)),
        CA.x1(max(plane.x.min, limit_x.min)),
        CA.x2(min(plane.x.max, limit_x.max))
      ]

      fn _ignored_assigns ->
        assigns = %{plane: plane, config: config, line_edits: line_edits, limit_x: limit_x}

        ~H"""
        <g class="x-axis">
          {Phoenix.LiveView.TagEngine.component(
            Terrestrial.Svg.line(@plane, @line_edits),
            [],
            {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
          )}
          <%= if @config.arrow do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.arrow(
                @plane,
                [CA.color(@config.color)],
                %{x: @limit_x.max, y: @config.pinned.(@plane.y)}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:axis_element, add_tick_values, view}
  end

  def axis_y(edits \\ []) do
    defaults = %{pinned: &CA.zero/1, color: "", arrow: true, width: 1, limits: []}

    config = apply_edits(defaults, edits)

    add_tick_values = fn plane, ts ->
      Map.put(ts, :axis_x, [config.pinned.(plane.x)] ++ ts.axis_x)
    end

    view = fn plane ->
      limit_y = Terrestrial.Internal.apply_edits(plane.y, config.limits)

      line_edits = [
        CA.color(config.color),
        CA.width(config.width),
        CA.x1(config.pinned.(plane.x)),
        CA.y1(max(plane.y.min, limit_y.min)),
        CA.y2(min(plane.y.max, limit_y.max))
      ]

      fn _ignored_assigns ->
        assigns = %{plane: plane, config: config, line_edits: line_edits, limit_y: limit_y}

        ~H"""
        <g class="y-axis">
          {Phoenix.LiveView.TagEngine.component(
            Terrestrial.Svg.line(@plane, @line_edits),
            [],
            {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
          )}
          <%= if @config.arrow do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.arrow(
                @plane,
                [CA.color(@config.color), CA.rotate(-90.0)],
                %{x: @config.pinned.(@plane.x), y: @limit_y.max}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:axis_element, add_tick_values, view}
  end

  defmodule Grid do
    @moduledoc false
    defstruct color: "", width: 0, dot_grid: false, dashed: []
  end

  def grid(edits \\ []) do
    # TODO Chart:1409
    config = apply_edits(%Grid{}, edits)

    color =
      case config.color do
        "" ->
          if config.dot_grid,
            do: Terrestrial.Colors.dark_gray(),
            else: Terrestrial.Colors.gray()

        c ->
          c
      end

    width =
      case config.width do
        0 -> if config.dot_grid, do: 0.5, else: 1.0
        w -> w
      end

    to_x_grid = fn tick_values, plane, v ->
      if Enum.member?(tick_values.axis_x, v) do
        # Don't re-draw the axis
        []
      else
        [
          Terrestrial.Svg.line(plane, [
            CA.color(color),
            CA.width(width),
            CA.x1(v),
            CA.dashed(config.dashed)
          ])
        ]
      end
    end

    to_y_grid = fn tick_values, plane, v ->
      if Enum.member?(tick_values.axis_y, v) do
        # Don't re-draw the axis
        []
      else
        [
          Terrestrial.Svg.line(plane, [
            CA.color(color),
            CA.width(width),
            CA.y1(v),
            CA.dashed(config.dashed)
          ])
        ]
      end
    end

    _to_dot = fn tick_values, plane, x, y ->
      if Enum.member?(tick_values.axis_x, x) or Enum.member?(tick_values.axis_y, y) do
        []
      else
        [
          Terrestrial.Svg.dot(
            plane,
            & &1.x,
            & &1.y,
            [
              CA.color(color),
              CA.size(width),
              CA.circle()
            ],
            %{x: x, y: y}
          )
        ]
      end
    end

    view = fn plane, tick_values ->
      grid_lines_x = Enum.flat_map(tick_values.xs, fn x -> to_x_grid.(tick_values, plane, x) end)
      grid_lines_y = Enum.flat_map(tick_values.ys, fn y -> to_y_grid.(tick_values, plane, y) end)

      fn _assigns ->
        assigns =
          %{
            config: config,
            plane: plane,
            tick_values: tick_values,
            grid_lines_x: grid_lines_x,
            grid_lines_y: grid_lines_y
          }

        ~H"""
        <g class="grid">
          <%= if @config.dot_grid do %>
            {raise "TODO dot_grid is not supported yet"}
          <% else %>
            <g class="x-grid">
              <%= for line_func <- @grid_lines_x do %>
                {Phoenix.LiveView.TagEngine.component(
                  line_func,
                  [],
                  {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                )}
              <% end %>
            </g>

            <g class="y-grid">
              <%= for line_func <- @grid_lines_y do %>
                {Phoenix.LiveView.TagEngine.component(
                  line_func,
                  [],
                  {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                )}
              <% end %>
            </g>
          <% end %>
        </g>
        """
      end
    end

    {:grid_element, view}
  end

  defmodule Property do
    @moduledoc false
    def default_to_y_sum(datum), do: datum.y

    defstruct stacked: false,
              to_y: &Function.identity/1,
              to_y_sum: &Terrestrial.Property.default_to_y_sum/1,
              # Edits for each dot or bar
              presentation_edits: [],
              # Edits for how we connect dots (series only)
              interpolation_edits: []

    @type t :: %{
            stacked: false,
            to_y: function(),
            to_y_sum: function(),
            presentation_edits: list(),
            interpolation_edits: list()
          }
  end

  @doc """
  Stack bars or lines.
  """
  def stacked(properties) when is_list(properties) do
    {:stacked, properties}
  end

  def stacked(property) do
    # Why would you want this?
    {:stacked, [property]}
  end

  @doc """
  Render a dot for each datapoint.
  """
  @spec scatter((any() -> float()), list()) :: Property.t()
  def scatter(to_y, dot_edits) when is_function(to_y, 1) do
    %Property{
      stacked: false,
      to_y: to_y,
      interpolation_edits: [],
      presentation_edits: dot_edits
    }
  end

  @doc """
  Like scatter/2 but connects the dots.
  """
  @spec interpolated((any() -> float()), list(), list()) :: Property.t()
  def interpolated(to_y, dot_edits, interpolation_edits) when is_function(to_y, 1) do
    %Property{
      stacked: false,
      to_y: to_y,
      interpolation_edits: [CA.linear() | interpolation_edits],
      presentation_edits: dot_edits
    }
  end

  @doc """
  Add a line series to your chart.
  """
  @spec series((any() -> float()), [Property.t()], list()) :: {:indexed, function()}
  def series(func_x, properties, data) when is_list(data) do
    with_index = fn index ->
      {{limits, legends, view}, new_index} =
        Terrestrial.Series.series(func_x, properties, data, index)

      {{:series_element, limits, legends, view}, new_index}
    end

    {:indexed, with_index}
  end

  @doc """
  Add a bar series to your chart.
  """
  @spec bars(function(), [Property.t()], list()) :: {:indexed, function()}
  def bars(edits, properties, data) do
    with_index = fn index ->
      {{limits, legends, ticks, view}, new_index} =
        Terrestrial.Bars.bars(edits, properties, data, index)

      {{:bars_element, limits, legends, ticks, view}, new_index}
    end

    {:indexed, with_index}
  end

  def bar(y, edits) do
    %Property{
      to_y: y,
      presentation_edits: edits
    }
  end

  defmodule Dot do
    @moduledoc false
    @type shape :: :circle | :triangle | :square | :diamond | :cross | :plus

    defstruct color: Terrestrial.Colors.pink(),
              opacity: 1.0,
              size: 6.0,
              border: "",
              border_width: 0,
              highlight: "",
              highlight_width: 5.0,
              highlight_color: "",
              shape: nil,
              hide_overflow: false

    @type t :: %__MODULE__{
            color: String.t(),
            opacity: float(),
            size: float(),
            border: String.t(),
            border_width: float(),
            highlight: String.t(),
            highlight_width: float(),
            highlight_color: String.t(),
            shape: shape(),
            hide_overflow: boolean()
          }
  end

  defmodule Tick do
    @moduledoc false
    defstruct length: 5.0, color: "rgb(210, 210, 210)", width: 1.0, attrs: []
  end

  def x_ticks(edits \\ []) do
    config =
      apply_edits(
        %{
          color: "",
          limits: [],
          pinned: &CA.zero/1,
          amount: 5,
          generate: :float,
          height: 5.0,
          flip: false,
          grid: true,
          width: 1.0
        },
        edits
      )

    to_ticks = fn plane ->
      axis = apply_edits(plane.x, config.limits)

      config.amount
      |> generate_values(:float, axis)
      |> Enum.map(& &1.value)
    end

    add_tick_values = fn p, ts ->
      if config.grid do
        Map.put(ts, :xs, ts.xs ++ to_ticks.(p))
      else
        ts
      end
    end

    view = fn plane ->
      fn _assigns ->
        assigns = %{plane: plane, config: config, ticks: to_ticks.(plane)}

        ~H"""
        <g class="x-ticks">
          <%= for x <- @ticks do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.tick(
                @plane,
                apply_edits(
                  %Tick{},
                  [
                    CA.color(@config.color),
                    CA.length(if @config.flip, do: -@config.height, else: @config.height),
                    CA.width(@config.width)
                  ]
                ),
                true,
                %{x: x, y: @config.pinned.(@plane.y)}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:ticks_element, add_tick_values, view}
  end

  def y_ticks(edits \\ []) do
    config =
      apply_edits(
        %{
          color: "",
          limits: [],
          pinned: &CA.zero/1,
          amount: 5,
          generate: :float,
          height: 5.0,
          flip: false,
          grid: true,
          width: 1.0
        },
        edits
      )

    to_ticks = fn plane ->
      axis = apply_edits(plane.y, config.limits)

      config.amount
      |> generate_values(:float, axis)
      |> Enum.map(& &1.value)
    end

    add_tick_values = fn p, ts ->
      if config.grid, do: Map.put(ts, :ys, ts.ys ++ to_ticks.(p)), else: ts
    end

    view = fn plane ->
      fn _assigns ->
        assigns = %{plane: plane, config: config, ticks: to_ticks.(plane)}

        ~H"""
        <g class="y-ticks">
          <%= for y <- @ticks do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.tick(
                @plane,
                apply_edits(
                  %Tick{},
                  [
                    CA.color(@config.color),
                    CA.length(if @config.flip, do: -@config.height, else: @config.height),
                    CA.width(@config.width)
                  ]
                ),
                false,
                %{x: @config.pinned.(@plane.x), y: y}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:ticks_element, add_tick_values, view}
  end

  defmodule Label do
    @moduledoc false
    defstruct x_off: 0.0,
              y_off: 0.0,
              border: "white",
              border_width: "0",
              font_size: nil,
              color: Terrestrial.Colors.label_gray(),
              anchor: nil,
              rotate: 0,
              uppercase: false,
              hide_overflow: false,
              attrs: [],
              ellipsis: nil
  end

  @doc """
  Add a label at a specific coordinate.
  """
  def label(edits, inner, point) do
    config = apply_edits(%Label{}, edits)

    view = fn plane ->
      fn _assigns ->
        assigns = %{plane: plane, config: config, point: point, inner: inner}

        ~H"""
        {Phoenix.LiveView.TagEngine.component(
          Terrestrial.Svg.label(@plane, @config, @inner, @point),
          [],
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )}
        """
      end
    end

    {:svg_element, view}
  end

  @doc """
  Add a label relative to your axes.
  """
  def label_at(to_x, to_y, edits, inner) do
    config = apply_edits(%Label{}, edits)

    view = fn plane ->
      point = %{x: to_x.(plane.x), y: to_y.(plane.y)}

      fn _assigns ->
        assigns = %{plane: plane, config: config, point: point, inner: inner}

        ~H"""
        {Phoenix.LiveView.TagEngine.component(
          Terrestrial.Svg.label(@plane, @config, @inner, @point),
          [],
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )}
        """
      end
    end

    {:svg_element, view}
  end

  def x_labels(edits \\ []) when is_list(edits) do
    to_config = fn _p ->
      apply_edits(
        %{
          color: Terrestrial.Colors.label_gray(),
          limits: [],
          pinned: &CA.zero/1,
          amount: 5,
          generate: :integer,
          anchor: nil,
          flip: false,
          x_off: 0.0,
          y_off: 18.0,
          grid: false,
          format: nil,
          uppercase: false,
          rotate: 0.0,
          font_size: nil,
          attrs: [],
          hide_overflow: false,
          ellipsis: nil
        },
        edits
      )
    end

    to_ticks = fn plane, config ->
      axis_config = apply_edits(plane.x, config.limits)
      generate_values(config.amount, config.generate, axis_config, config.format)
    end

    to_tick_values = fn plane, config, tick_values ->
      if config.grid do
        Map.put(
          tick_values,
          :xs,
          tick_values.xs ++ Enum.map(to_ticks.(plane, config), & &1.value)
        )
      else
        tick_values
      end
    end

    view = fn plane, config ->
      fn _assigns ->
        assigns = %{plane: plane, config: config, ticks: to_ticks.(plane, config)}

        ~H"""
        <g class="x-labels">
          <%= for item <- @ticks do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.label(
                @plane,
                %Label{
                  x_off: @config.x_off,
                  y_off: if(@config.flip, do: -@config.y_off + 10, else: @config.y_off),
                  color: @config.color,
                  anchor: @config.anchor,
                  font_size: @config.font_size,
                  uppercase: @config.uppercase,
                  rotate: @config.rotate,
                  attrs: @config.attrs,
                  hide_overflow: @config.hide_overflow,
                  ellipsis: @config.ellipsis
                },
                item.label,
                %{x: item.value, y: @config.pinned.(@plane.y)}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:labels_element, to_config, to_tick_values, view}
  end

  def y_labels(edits \\ []) when is_list(edits) do
    to_config = fn _p ->
      apply_edits(
        %{
          color: Terrestrial.Colors.label_gray(),
          limits: [],
          pinned: &CA.zero/1,
          amount: 5,
          generate: :integer,
          anchor: nil,
          flip: false,
          x_off: -10.0,
          y_off: 3.0,
          grid: false,
          format: nil,
          uppercase: false,
          rotate: 0.0,
          font_size: nil,
          attrs: [],
          hide_overflow: false,
          ellipsis: nil
        },
        edits
      )
    end

    to_ticks = fn plane, config ->
      axis_config = apply_edits(plane.y, config.limits)
      generate_values(config.amount, config.generate, axis_config, config.format)
    end

    to_tick_values = fn plane, config, tick_values ->
      if config.grid do
        Map.put(
          tick_values,
          :xs,
          tick_values.ys ++ Enum.map(to_ticks.(plane, config), & &1.value)
        )
      else
        tick_values
      end
    end

    view = fn plane, config ->
      fn _assigns ->
        assigns = %{plane: plane, config: config, ticks: to_ticks.(plane, config)}

        ~H"""
        <g class="y-labels">
          <%= for item <- @ticks do %>
            {Phoenix.LiveView.TagEngine.component(
              Terrestrial.Svg.label(
                @plane,
                %Label{
                  x_off: if(@config.flip, do: -@config.x_off, else: @config.x_off),
                  y_off: @config.y_off,
                  color: @config.color,
                  font_size: @config.font_size,
                  uppercase: @config.uppercase,
                  rotate: @config.rotate,
                  attrs: @config.attrs,
                  hide_overflow: @config.hide_overflow,
                  ellipsis: @config.ellipsis,
                  anchor:
                    if(@config.anchor, do: @config.anchor, else: if(@config.flip, do: :start, else: :end))
                },
                item.label,
                %{x: @config.pinned.(@plane.x), y: item.value}
              ),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {:labels_element, to_config, to_tick_values, view}
  end

  @spec generate_values(
          integer(),
          :integer | :float | :datetime,
          Terrestrial.Coordinates.axis(),
          (float() -> String.t()) | nil
        ) ::
          list()
  defp generate_values(amount, tick, axis, func_format \\ nil) do
    to_tick_values = fn to_value, to_string_ ->
      fn i ->
        %{
          value: to_value.(i),
          label:
            case func_format do
              nil ->
                to_string_.(i)

              formatter ->
                formatter.(to_value.(i))
            end
        }
      end
    end

    case tick do
      :integer ->
        amount
        |> Terrestrial.Intervals.gen_ints(axis, false)
        |> Enum.map(
          to_tick_values.(&round(&1), fn raw ->
            Integer.to_string(round(raw))
          end)
        )

      :float ->
        amount
        |> Terrestrial.Intervals.gen_floats(axis, false)
        |> Enum.map(to_tick_values.(& &1, &Float.to_string/1))

      :datetime ->
        []
    end
  end

  # container config
  # returns the plane we need
  @spec define_plane(map(), list()) :: Coords.plane()
  defp define_plane(config, elements) do
    collect_limits = fn elem, acc ->
      case elem do
        {:indexed, _} -> acc
        {:series_element, lims, _, _} -> acc ++ lims
        {:bars_element, lims, _, _, _} -> acc ++ lims
        {:svg_element, _} -> acc
        {:axis_element, _, _} -> acc
        {:grid_element, _} -> acc
        {:ticks_element, _, _} -> acc
        {:labels_element, _, _, _} -> acc
        _ -> raise "unhandled element"
      end
    end

    width = max(1, config.width - config.padding.left - config.padding.right)
    height = max(1, config.height - config.padding.bottom - config.padding.top)

    to_limit = fn length, margin_min, margin_max, min, max ->
      %{
        length: length,
        margin_min: margin_min,
        margin_max: margin_max,
        min: min,
        max: max,
        data_min: min,
        data_max: max
      }
    end

    fix_singles = fn bs ->
      if bs.min == bs.max, do: Map.put(bs, :max, bs.min + 10), else: bs
    end

    limits_ =
      elements
      |> Enum.reduce([], collect_limits)
      |> Terrestrial.Coordinates.fold_position(&Function.identity/1)
      |> then(fn pos ->
        %{
          x: to_limit.(width, config.margin.left, config.margin.right, pos.x1, pos.x2),
          y: to_limit.(height, config.margin.top, config.margin.bottom, pos.y1, pos.y2)
        }
      end)
      |> then(fn %{x: x, y: y} -> %{x: fix_singles.(x), y: fix_singles.(y)} end)

    calc_range =
      case config.range do
        [] -> limits_.x
        some_edits -> apply_edits(limits_.x, some_edits)
      end

    calc_domain =
      case config.domain do
        [] -> apply_edits(limits_.y, [CA.lowest(0, &CA.or_lower/3)])
        some_edits -> apply_edits(limits_.y, some_edits)
      end

    unpadded = %{x: calc_range, y: calc_domain}
    x_min = calc_range.min - Coords.scale_cartesian_x(unpadded, config.padding.left)
    x_max = calc_range.max + Coords.scale_cartesian_x(unpadded, config.padding.right)

    y_min = calc_domain.min - Coords.scale_cartesian_y(unpadded, config.padding.bottom)
    y_max = calc_domain.max + Coords.scale_cartesian_y(unpadded, config.padding.top)

    %{
      x: %{
        calc_range
        | length: config.width,
          min: min(x_min, x_max),
          max: max(x_min, x_max)
      },
      y: %{
        calc_domain
        | length: config.height,
          min: min(y_min, y_max),
          max: max(y_min, y_max)
      }
    }
  end

  defp get_items(_plane, elements) do
    to_items = fn elem, acc ->
      case elem do
        {:svg_element, _} -> acc
        {:axis_element, _, _} -> acc
        # TODO we return no items atm
        {:series_element, _, _, _} -> acc ++ []
        {:bars_element, _, _, _, _} -> acc ++ []
        {:grid_element, _} -> acc
        {:ticks_element, _, _} -> acc
        {:labels_element, _, _, _} -> acc
        _ -> raise "unhandled element"
      end
    end

    Enum.reduce(elements, [], to_items)
  end

  defp get_legends(elements) do
    to_legend = fn elem, acc ->
      case elem do
        {:svg_element, _} -> acc
        {:axis_element, _, _} -> acc
        {:series_element, _, legends, _} -> acc ++ legends
        {:bars_element, _, legends, _, _} -> acc ++ legends
        {:grid_element, _} -> acc
        {:ticks_element, _, _} -> acc
        {:labels_element, _, _, _} -> acc
        _ -> raise "unhandled element"
      end
    end

    Enum.reduce(elements, [], to_legend)
  end

  defmodule TickValues do
    @moduledoc false
    defstruct axis_x: [], axis_y: [], xs: [], ys: []
  end

  defp get_tick_values(plane, _items, elements) do
    to_values = fn elem, acc ->
      case elem do
        {:svg_element, _} -> acc
        {:axis_element, func, _} -> func.(plane, acc)
        {:series_element, _, _, _} -> acc
        {:bars_element, _, _, func, _} -> func.(plane, acc)
        {:grid_element, _} -> acc
        {:ticks_element, func, _} -> func.(plane, acc)
        {:labels_element, to_c, func, _} -> func.(plane, to_c.(plane), acc)
        _ -> raise "unhandled element"
      end
    end

    Enum.reduce(elements, %TickValues{}, to_values)
  end

  defp view_elements(_config, plane, tick_values, _all_items, _all_legends, elements) do
    # TODO all_items is currently unused, it's used for elements we don't support
    view_one = fn elem, {before, chart_, after_} ->
      case elem do
        {:series_element, _, _, view} ->
          {before, [view.(plane)] ++ chart_, after_}

        {:bars_element, _, _, _, view} ->
          {before, [view.(plane)] ++ chart_, after_}

        {:axis_element, _, view} ->
          {before, [view.(plane)] ++ chart_, after_}

        {:svg_element, view} ->
          {before, [view.(plane)] ++ chart_, after_}

        {:grid_element, view} ->
          {before, [view.(plane, tick_values)] ++ chart_, after_}

        {:ticks_element, _, view} ->
          {before, [view.(plane)] ++ chart_, after_}

        {:labels_element, to_c, _, view} ->
          {before, [view.(plane, to_c.(plane))] ++ chart_, after_}

        _ ->
          raise "unhandled element"
      end
    end

    Enum.reduce(elements, {[], [], []}, view_one)
  end
end
