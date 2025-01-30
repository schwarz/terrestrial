defmodule Terrestrial.Series do
  @moduledoc false
  use Phoenix.Component

  import Terrestrial.Internal

  alias Terrestrial.Attributes, as: CA
  alias Terrestrial.Coordinates, as: Coords

  defmodule Item do
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
  end

  def series(to_x, properties, data, starting_index) do
    # take our data and go over each property, calling to_x and to_y for each, increasing the index for each as well
    # one item per property that has method != nil and one item per each datapoint
    # each property is a line based on the same data and x, but has different to_y
    items =
      for {property, property_index} <- Enum.with_index(properties, 0) do
        interpolation_config =
          apply_edits(
            %Terrestrial.Interpolation{},
            [
              CA.color(Terrestrial.Colors.to_default_color(property_index))
              | property.interpolation_edits
            ]
          )

        dot_items =
          for {datum, dot_item_index} <- Enum.with_index(data) do
            x = to_x.(datum)
            y = property.to_y.(datum)

            dot_config =
              Terrestrial.Internal.apply_edits(
                %Terrestrial.Dot{},
                [
                  CA.color(interpolation_config.color),
                  CA.border(interpolation_config.color),
                  if(interpolation_config.method == nil,
                    do: CA.circle(),
                    else: CA.no_change()
                  )
                ] ++
                  property.presentation_edits
              )

            %Item{
              x1: x,
              x2: x,
              y: y,
              datum: datum,
              color: Terrestrial.Colors.to_default_color(property_index),
              presentation: dot_config,
              identification: %{
                property_index: property_index,
                dot_item_index: dot_item_index
              },
              limits: %{x1: x, x2: x, y1: y, y2: y},
              to_position: fn _plane ->
                # TODO Radius of circle etc
                %{x1: x, x2: x, y1: y, y2: y}
              end,
              # TODO elm-charts has a arity 2 function here
              render: fn plane ->
                fn _ignored_assigns ->
                  assigns = %{
                    plane: plane,
                    datum: %{x: x, y: y},
                    to_x: & &1.x,
                    to_y: & &1.y,
                    dot_config: dot_config
                  }

                  ~H"""
                  <%= if @datum.y != nil do %>
                    {Phoenix.LiveView.TagEngine.component(
                      Terrestrial.Svg.dot(@plane, @to_x, @to_y, @dot_config, @datum),
                      [],
                      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                    )}
                  <% end %>
                  """
                end
              end
            }
          end

        view = fn plane ->
          fn _ignored_assigns ->
            {first, commands, _} =
              to_commands(interpolation_config.method, to_x, property.to_y, data)

            assigns = %{
              plane: plane,
              to_x: to_x,
              to_y: property.to_y,
              config: interpolation_config,
              data: data,
              first: first,
              commands: commands,
              dot_items: dot_items
            }

            ~H"""
            <g class="series">
              <%= if @config.method != nil do %>
                <g class="interpolation-sections">
                  <g class="interpolation-section">
                    {Phoenix.LiveView.TagEngine.component(
                      Terrestrial.Svg.interpolation(@plane, @config).(
                        @first,
                        @commands,
                        :this_arg_is_ignored
                      ),
                      [],
                      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                    )}
                  </g>
                </g>
              <% end %>
              <%= for item <- @dot_items do %>
                <g class="dots">
                  {Phoenix.LiveView.TagEngine.component(
                    item.render.(@plane),
                    [],
                    {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                  )}
                </g>
              <% end %>
            </g>
            """
          end
        end

        %Item{
          render: view,
          limits: Coords.fold_position(dot_items, & &1.limits),
          to_position: fn plane ->
            Coords.fold_position(dot_items, & &1.to_position.(plane))
          end
        }
      end

    legends = []

    to_limits = Enum.map(items, fn item -> item.limits end)

    view = fn plane ->
      fn _ignored_assigns ->
        assigns = %{plane: plane, items: items}

        ~H"""
        <g class="series">
          <%= for item <- @items do %>
            {Phoenix.LiveView.TagEngine.component(
              item.render.(@plane),
              [],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>
        </g>
        """
      end
    end

    {{to_limits, legends, view}, starting_index + length(items)}
  end

  # TODO We don't allow for any missing data atm
  def to_commands(method, to_x, to_y, data) do
    points =
      Enum.map(data, fn datum -> %{x: to_x.(datum), y: to_y.(datum)} end)

    commands =
      case method do
        :linear ->
          Terrestrial.Interpolation.linear(points)

        _ ->
          raise "interpolation method not supported yet"
      end

    {List.first(points), commands, List.last(points)}
  end
end
