defmodule Terrestrial.Svg do
  @moduledoc false
  use Phoenix.Component

  import Terrestrial.Internal, only: [apply_edits: 2, clamp: 3]

  alias Terrestrial.Coordinates, as: Coords

  defmodule Line do
    @moduledoc false
    defstruct x1: nil,
              x2: nil,
              y1: nil,
              y2: nil,
              tick_length: 0,
              tick_direction: -90,
              x_off: 0,
              y_off: 0,
              color: "rgb(210, 210, 210)",
              width: 1,
              opacity: 1,
              hide_overflow: false
  end

  def line(plane, edits) do
    config = apply_edits(%Line{}, edits)

    {x1, x2, y1, y2} =
      case {config.x1, config.x2, config.y1, config.y2} do
        # currently only supports axes and arbitrary line, and grid
        # only x1, x grid
        {x1, nil, nil, nil} -> {x1, x1, plane.y.min, plane.y.max}
        # only y1, y grid
        {nil, nil, y1, nil} -> {plane.x.min, plane.x.max, y1, y1}
        # x axis
        {x1, x2, y1, nil} -> {x1, x2, y1, y1}
        # y axis
        {x1, nil, y1, y2} -> {x1, x1, y1, y2}
        # arbitrary
        {x1, x2, y1, y2} -> {x1, x2, y1, y2}
      end

    cmds = [{:move, x1, y1}, {:line, x2, y2}]

    fn _ignored_assigns ->
      assigns =
        %{
          config: config,
          d: Terrestrial.Commands.description(plane, cmds)
        }

      ~H"""
      <path
        class=""
        fill="transparent"
        stroke={@config.color}
        stroke-width={@config.width}
        stroke-opacity={@config.opacity}
        d={@d}
      />
      """
    end
  end

  defp empty_component(assigns) do
    ~H"""
    """
  end

  def dot(plane, to_x, to_y, config, datum) do
    actual_x = to_x.(datum)
    actual_y = to_y.(datum)
    scaled_x = Coords.to_svg_x(actual_x, plane)
    scaled_y = Coords.to_svg_y(actual_y, plane)
    area = 2 * :math.pi() * config.size

    highlight_color =
      case config.highlight_color do
        "" -> config.color
        color -> color
      end

    # TODO
    _show_dot = true

    stroke =
      case config.border do
        "" -> config.color
        color -> color
      end

    # TODO clippath if hideOverflow
    attrs_style = [
      stroke: stroke,
      "stroke-width": config.border_width,
      "fill-opacity": config.opacity,
      fill: config.color,
      class: "dot"
    ]

    _attrs_highlight = [
      stroke: highlight_color,
      "stroke-width": config.highlight_width,
      "stroke-opacity": config.highlight,
      fill: "transparent",
      class: "dot-highlight"
    ]

    fn _ignored_assigns ->
      assigns =
        %{
          x: Float.to_string(scaled_x),
          y: Float.to_string(scaled_y),
          radius: :math.sqrt(area / :math.pi()),
          dot_config: attrs_style
        }

      # TODO Highlights
      ~H"""
      <g class="dot-container">
        <circle cx={@x} cy={@y} r={@radius} {@dot_config} />
      </g>
      """
    end
  end

  def container(_plane, config, _before_elems, chart_elems, _after_elems) do
    fn _assigns ->
      assigns = %{
        config: config,
        chart_elems: chart_elems,
        id: random_id()
      }

      ~H"""
      <div id={@id} class="trz-container w-100% h-100%">
        <svg
          version="1.1"
          viewBox={"0 0 #{@config.width} #{@config.height}"}
          width={@config.width}
          height={@config.height}
          xmlns="http://www.w3.org/2000/svg"
          style="overflow: visible;"
        >
          <%= for elem <- @chart_elems do %>
            {Phoenix.LiveView.TagEngine.component(
              elem,
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </svg>
      </div>
      """
    end
  end

  defmodule Arrow do
    @moduledoc false
    defstruct x_off: 0.0,
              y_off: 0.0,
              color: "rgb(210, 210, 210)",
              width: 4.0,
              length: 7.0,
              rotate: 0.0,
              attrs: []
  end

  def arrow(plane, edits, point) do
    config = apply_edits(%Arrow{}, edits)
    points = "0,0 #{config.length},#{config.width} 0,#{config.width * 2}"
    commands = "rotate(#{config.rotate}) translate(0 #{-1 * config.width})"

    fn _assigns ->
      assigns = %{config: config, points: points, commands: commands, plane: plane, point: point}

      ~H"""
      <g
        class="arrow"
        transform={position_transform(@plane, 0, @point.x, @point.y, @config.x_off, @config.y_off)}
      >
        <polygon fill={@config.color} points={@points} transform={@commands} {@config.attrs} />
      </g>
      """
    end
  end

  def tick(plane, config, is_x, point) do
    fn _assigns ->
      assigns = %{plane: plane, config: config, point: point, is_x: is_x}

      ~H"""
      <line
        stroke={@config.color}
        stroke-width={@config.width}
        x1={Coords.to_svg_x(@point.x, @plane)}
        x2={Coords.to_svg_x(@point.x, @plane) + if(@is_x, do: 0, else: -1 * @config.length)}
        y1={Coords.to_svg_y(@point.y, @plane)}
        y2={Coords.to_svg_y(@point.y, @plane) + if(@is_x, do: @config.length, else: 0)}
      />
      """
    end
  end

  defp position_transform(plane, rotation, x, y, x_off, y_off) do
    "translate(#{Coords.to_svg_x(x, plane) + x_off},#{Coords.to_svg_y(y, plane) + y_off}) rotate(#{rotation})"
  end

  def label(plane, config, inner, point) do
    # TODO We ignore config.ellipsis for now
    font_style =
      case config.font_size do
        nil -> ""
        size -> "font-size: #{size}px;"
      end

    anchor_style =
      case config.anchor do
        nil -> "text-anchor: middle;"
        anchor when anchor in [:end, :start, :middle] -> "text-anchor: #{anchor};"
      end

    uppercase_style =
      if config.uppercase, do: "text-transform: uppercase;", else: ""

    # TODO hide_oveflow

    fn _assigns ->
      assigns = %{
        config: config,
        style: Enum.join([font_style, anchor_style, uppercase_style], " "),
        inner: inner,
        point: point,
        plane: plane
      }

      ~H"""
      <text
        class="label"
        stroke={@config.border}
        stroke-width={"#{@config.border_width}"}
        fill={@config.color}
        style={@style}
        transform={
          position_transform(
            @plane,
            -@config.rotate,
            @point.x,
            @point.y,
            @config.x_off,
            @config.y_off
          )
        }
      >
        <tspan>{@inner}</tspan>
      </text>
      """
    end
  end

  def interpolation(plane, config) do
    fn first, cmds, _ ->
      fn _ignored_assigns ->
        assigns = %{config: config, cmds: cmds, plane: plane, first: first}

        ~H"""
        <path
          class="interpolation-section"
          fill="transparent"
          stroke={@config.color}
          stroke-dasharray={Enum.join(@config.dashed, " ")}
          stroke-width={@config.width}
          d={Terrestrial.Commands.description(@plane, [{:move, @first.x, @first.y}] ++ @cmds)}
        >
        </path>
        """
      end
    end
  end

  def bar(plane, config, point) do
    highlight_color =
      case config.highlight_color do
        "" -> config.color
        color -> color
      end

    border_width_cartesian_x = Coords.scale_cartesian_x(plane, config.border_width / 2)
    border_width_cartesian_y = Coords.scale_cartesian_y(plane, config.border_width / 2)

    pos = %{
      x1: min(point.x1, point.x2) + border_width_cartesian_x,
      x2: max(point.x1, point.x2) - border_width_cartesian_x,
      y1: min(point.y1, point.y2) + border_width_cartesian_y,
      y2: max(point.y1, point.y2) - border_width_cartesian_y
    }

    highlight_width_cartesian_x =
      border_width_cartesian_x +
        Coords.scale_cartesian_x(plane, config.highlight_width / 2)

    highlight_width_cartesian_y =
      border_width_cartesian_y +
        Coords.scale_cartesian_y(plane, config.highlight_width / 2)

    highlight_pos = %{
      x1: pos.x1 - highlight_width_cartesian_x,
      x2: pos.x2 + highlight_width_cartesian_x,
      y1: pos.y1 - highlight_width_cartesian_y,
      y2: pos.y2 + highlight_width_cartesian_y
    }

    width = abs(pos.x2 - pos.x1)

    rounding_top =
      Coords.scale_svg_x(plane, width) * 0.5 * clamp(config.round_top, 0, 1)

    rounding_bottom =
      Coords.scale_svg_x(plane, width) * 0.5 * clamp(config.round_bottom, 0, 1)

    radius_top_x = Coords.scale_cartesian_x(plane, rounding_top)
    radius_top_y = Coords.scale_cartesian_y(plane, rounding_top)
    radius_bottom_x = Coords.scale_cartesian_x(plane, rounding_bottom)
    radius_bottom_y = Coords.scale_cartesian_y(plane, rounding_bottom)

    height = abs(pos.y2 - pos.y1)

    {round_top, round_bottom} =
      if(
        height - radius_top_y * 0.8 - radius_bottom_y * 0.8 <= 0 ||
          width - radius_top_x * 0.8 - radius_bottom_x * 0.8 <= 0
      ) do
        {0, 0}
      else
        {config.round_top, config.round_bottom}
      end

    {commands, highlight_commands} =
      if pos.y1 == pos.y2 do
        {[], []}
      else
        case {round_top > 0.0, round_bottom > 0.0} do
          {false, false} ->
            {[
               {:move, pos.x1, pos.y1},
               {:line, pos.x1, pos.y2},
               {:line, pos.x2, pos.y2},
               {:line, pos.x2, pos.y1},
               {:line, pos.x1, pos.y1}
             ],
             [
               {:move, highlight_pos.x1, pos.y1},
               {:line, highlight_pos.x1, highlight_pos.y2},
               {:line, highlight_pos.x2, highlight_pos.y2},
               {:line, highlight_pos.x2, pos.y1},
               # ^ outer
               {:line, pos.x2, pos.y1},
               {:line, pos.x2, pos.y2},
               {:line, pos.x1, pos.y2},
               {:line, pos.x1, pos.y1}
             ]}

          {true, false} ->
            # TODO Rounded top L973
            raise "roundness not supported yet"
            {[], []}

          {false, true} ->
            # TODO Rounded bottom L998
            raise "roundness not supported yet"
            {[], []}

          {true, true} ->
            # TODO Rounded top and bottom L1024
            raise "roundness not supported yet"
            {[], []}
        end
      end

    view_bar = fn assigns ->
      assigns =
        assign(assigns,
          path_attrs: config.attrs,
          plane: plane
        )

      ~H"""
      <path
        {@path_attrs}
        class="bar"
        fill={@fill}
        fill-opacity={@fill_opacity}
        stroke={@border}
        stroke-width={@border_width}
        stroke-opacity={@stroke_opacity}
        d={Terrestrial.Commands.description(@plane, @cmds)}
      />
      """
    end

    view_aura_bar = fn fill ->
      fn _ignored_assigns ->
        assigns =
          %{
            fill: fill,
            fill_opacity: config.opacity,
            border: config.border,
            border_width: config.border_width,
            commands: commands,
            highlight_color: highlight_color,
            highlight_commands: highlight_commands,
            highlight_opacity: config.highlight,
            view_bar: view_bar
          }

        if config.highlight == 0 do
          ~H"""
          {Phoenix.LiveView.TagEngine.component(
            @view_bar,
            [
              fill: @highlight_color,
              fill_opacity: @fill_opacity,
              border: @border,
              border_width: @border_width,
              stroke_opacity: 1,
              cmds: @commands
            ],
            {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
          )}
          """
        else
          ~H"""
          <g class="bar-with-highlight">
            {Phoenix.LiveView.TagEngine.component(
              @view_bar,
              [
                fill: @highlight_color,
                fill_opacity: @highlight_opacity,
                border: "transparent",
                border_width: 0,
                stroke_opacity: 0,
                cmds: @highlight_commands
              ],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}

            {Phoenix.LiveView.TagEngine.component(
              @view_bar,
              [
                fill: @fill,
                fill_opacity: @fill_opacity,
                border: @border,
                border_width: @border_width,
                stroke_opacity: 1,
                cmds: @commands
              ],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          </g>
          """
        end
      end
    end

    # TODO config.design L1079
    view_aura_bar.(config.color)
  end

  # Returns a random ID with valid DOM tokens
  defp random_id do
    random_b64 =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64()

    "trz-"
    |> Kernel.<>(random_b64)
    |> String.replace(["/", "+"], "-")
  end
end
