defmodule Terrestrial.Bars do
  @moduledoc false
  use Phoenix.Component

  import Terrestrial.Internal

  alias Terrestrial.Attributes, as: CA
  alias Terrestrial.Coordinates, as: Coords
  alias Terrestrial.Item

  defstruct spacing: 0.05,
            margin: 0.1,
            round_top: 0,
            round_bottom: 0,
            grouped: true,
            grid: false,
            x1: nil,
            x2: nil

  @typedoc "Config for Bars"
  @type t() :: %__MODULE__{
          spacing: float(),
          margin: float(),
          round_top: float(),
          round_bottom: float(),
          grouped: boolean(),
          grid: boolean(),
          x1: function() | nil,
          x2: function() | nil
        }

  defmodule Bar do
    @moduledoc false
    defstruct round_top: 0,
              round_bottom: 0,
              border: "white",
              border_width: 0,
              color: Terrestrial.Colors.pink(),
              opacity: 1.0,
              design: nil,
              attrs: [],
              highlight: 0,
              highlight_width: 0,
              highlight_color: ""
  end

  # type alias Identification =
  # { stackIndex : Int      -- Index of the stack.
  # , seriesIndex : Int     -- Index of the series within a stack.
  # , absoluteIndex : Int   -- Index of series within the total set of series.
  # , dataIndex : Int       -- Index of data point within data.
  # , elementIndex : Int    -- Index of element within chart.
  # }

  def bars(edits, properties, data, element_index) do
    view_bar_series = fn plane, items ->
      fn _ignored_assigns ->
        assigns = %{plane: plane, items: items}

        ~H"""
        <g class="series">
          <%= for item <- @items do %>
            {Phoenix.LiveView.TagEngine.component(
              Item.render_item(item, @plane),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    bars_config = apply_edits(%__MODULE__{}, edits)
    # number of side-by-side bars per bin, ungrouped means we overlay them
    number_of_stacks = if bars_config.grouped, do: length(properties), else: 1

    bins =
      data
      |> with_surround()
      |> Enum.with_index()
      |> Enum.map(fn {surrounded_element, index} ->
        to_bin(surrounded_element, bars_config, index)
      end)

    for_each_data_point = fn absolute_index,
                             stack_series_config_index,
                             bar_series_config_index,
                             number_of_bars_in_stack,
                             bar_series_config,
                             data_index,
                             bin ->
      identification = %{
        stack_index: stack_series_config_index,
        series_index: bar_series_config_index,
        absolute_index: absolute_index,
        data_index: data_index,
        element_index: element_index
      }

      start = bin.start
      end_ = bin.end
      y_sum = bar_series_config.to_y_sum.(bin.datum)
      y = bar_series_config.to_y.(bin.datum)

      length = end_ - start
      margin = length * bars_config.margin
      spacing = length * bars_config.spacing
      width = (length - margin * 2 - (number_of_stacks - 1) * spacing) / number_of_stacks

      offset =
        if bars_config.grouped do
          identification.stack_index * width + identification.stack_index * spacing
        else
          0
        end

      x1 = start + margin + offset
      x2 = x1 + width

      min_y = fn x ->
        if number_of_bars_in_stack > 1 do
          max(0, x)
        else
          x
        end
      end

      y1 = min_y.(y_sum - y)
      y2 = min_y.(y_sum)

      is_top = identification.series_index == 0
      is_bottom = identification.series_index == number_of_bars_in_stack - 1
      is_single = number_of_bars_in_stack == 1

      round_top = if(is_single || is_top, do: bars_config.round_top, else: 0)
      round_bottom = if(is_single || is_bottom, do: bars_config.round_bottom, else: 0)

      default_color = Terrestrial.Colors.to_default_color(identification.absolute_index)

      basic_edits = [
        CA.round_top(round_top),
        CA.round_bottom(round_bottom),
        CA.color(default_color),
        CA.border(default_color)
      ]

      # TODO Variation
      bar_presentation_config =
        %Bar{}
        |> apply_edits(basic_edits ++ bar_series_config.presentation_edits)
        |> maybe_update_color_if_gradient(default_color)
        |> maybe_update_border(default_color)

      %Item{
        presentation: bar_presentation_config,
        color: bar_presentation_config.color,
        datum: bin.datum,
        x1: start,
        x2: end_,
        y: y,
        identification: identification,
        limits: %{x1: x1, x2: x2, y1: min(y1, y2), y2: max(y1, y2)},
        to_position: fn _ -> %{x1: x1, x2: x2, y1: y1, y2: y2} end,
        render: fn plane, position ->
          Terrestrial.Svg.bar(plane, bar_presentation_config, position)
        end
      }
    end

    for_each_bar_series_config = fn
      bins,
      absolute_index,
      stack_series_config_index,
      number_of_bars_in_stack,
      bar_series_config_index,
      bar_series_config ->
        absolute_index_new = absolute_index + bar_series_config_index

        items =
          bins
          |> Enum.with_index()
          |> Enum.map(fn {bin, data_index} ->
            for_each_data_point.(
              absolute_index_new,
              stack_series_config_index,
              bar_series_config_index,
              number_of_bars_in_stack,
              bar_series_config,
              data_index,
              bin
            )
          end)

        %Item{
          limits: Coords.fold_position(items, & &1.limits),
          to_position: fn plane -> Coords.fold_position(items, & &1.to_position.(plane)) end,
          render: fn plane, _position ->
            view_bar_series.(plane, items)
          end
        }
    end

    {_, _, items} =
      Enum.reduce(properties, {element_index, 0, []}, fn stack_series_config,
                                                         {absolute_index,
                                                          stack_series_config_index, items} ->
        series_items =
          case stack_series_config do
            {:stacked, bar_series_configs} ->
              # TODO Augment to_y_sum
              number_of_bars_in_stack = length(bar_series_configs)

              bar_series_configs
              |> Enum.with_index()
              |> Enum.map(fn {bar_series_config, bar_series_config_index} ->
                # TODO Inefficient, replace with a reduce
                previous_configs =
                  case bar_series_config_index do
                    0 -> []
                    n -> Enum.take(bar_series_configs, n)
                  end

                to_y_sum = fn datum ->
                  Enum.reduce(previous_configs, 0, fn config, acc ->
                    config.to_y.(datum) + acc
                  end) + bar_series_config.to_y.(datum)
                end

                for_each_bar_series_config.(
                  bins,
                  absolute_index,
                  stack_series_config_index,
                  number_of_bars_in_stack,
                  bar_series_config_index,
                  Map.put(bar_series_config, :to_y_sum, to_y_sum)
                )
              end)

            bar_series_config ->
              [
                for_each_bar_series_config.(
                  bins,
                  absolute_index,
                  stack_series_config_index,
                  1,
                  0,
                  Map.put(bar_series_config, :to_y_sum, bar_series_config.to_y)
                )
              ]
          end

        {absolute_index + length(series_items), stack_series_config_index + 1,
         items ++ series_items}
      end)

    legends = []

    to_limits = Enum.map(items, fn item -> item.limits end)

    view = fn plane ->
      fn _ignored_assigns ->
        assigns = %{plane: plane, items: items}

        ~H"""
        <g class="bar-series">
          <%= for item <- @items do %>
            {Phoenix.LiveView.TagEngine.component(
              Item.render_item(item, @plane),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    to_ticks = fn _plane, acc ->
      # TODO Ticks Chart:2257
      %{acc | xs: acc.xs ++ []}
    end

    {{to_limits, legends, to_ticks, view}, element_index + length(items)}
  end

  def to_bin({prev_or_nil, curr, next_or_nil}, %Terrestrial.Bars{} = config, index) do
    case {config.x1, config.x2} do
      {nil, nil} ->
        %{datum: curr, start: index + 1 - 0.5, end: index + 1 + 0.5}

      {x1, nil} ->
        case {prev_or_nil, next_or_nil} do
          {nil, nil} ->
            %{datum: curr, start: x1.(curr), end: x1.(curr) + 1}

          {prev, nil} ->
            %{datum: curr, start: x1.(curr), end: x1.(curr) + x1.(curr) - x1.(prev)}

          {_, next} ->
            %{datum: curr, start: x1.(curr), end: x1.(next)}
        end

      {nil, x2} ->
        case {prev_or_nil, next_or_nil} do
          {nil, nil} ->
            %{datum: curr, start: x2.(curr) - 1, end: x2.(curr)}

          {nil, next} ->
            %{datum: curr, start: x2.(curr) - x2.(next) - x2.(curr)}

          {prev, _} ->
            %{datum: curr, start: x2.(prev), end: x2.(curr)}
        end

      {x1, x2} ->
        %{datum: curr, start: x1.(curr), end: x2.(curr)}
    end
  end

  def maybe_update_color_if_gradient(product, default_color) do
    # TODO
    product
  end

  def maybe_update_border(product, default_color) do
    if product.border == default_color do
      Map.put(product, :border, product.color)
    else
      product
    end
  end
end
