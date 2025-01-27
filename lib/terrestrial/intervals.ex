defmodule Terrestrial.Intervals do
  @moduledoc """
  Helpers to create "nice" numbers for axis labels.
  """

  # Produce a list of "nice" integers.
  def gen_ints(amount, axis, is_exact) do
    values(false, is_exact, amount, axis.min, axis.max)
    |> Enum.map(&Float.round/1)
  end

  # Produce a list of "nice" floats.
  def gen_floats(amount, axis, is_exact) do
    values(true, is_exact, amount, axis.min, axis.max)
    |> Enum.map(&Float.round(&1))
  end

  defp values(allow_decimals, is_exact, amount_rough_unsafe, min, max) do
    amount_rough = if amount_rough_unsafe == 0, do: 1, else: amount_rough_unsafe
    interval_rough = (max - min) / amount_rough
    interval_unsafe = get_interval(interval_rough, allow_decimals, is_exact)
    interval = if interval_unsafe == 0, do: 1, else: interval_unsafe
    beginning = get_beginning(min, interval)
    positions(min, max, beginning, interval, 0, [])
  end

  defp get_interval(interval_raw, allow_decimals, has_tick_amount) do
    magnitude = :math.pow(10, Float.floor(:math.log(interval_raw) / :math.log(10)))
    normalized = interval_raw / magnitude
    multiples = get_multiples(magnitude, allow_decimals, has_tick_amount)

    multiple =
      if has_tick_amount do
        find_multiple_exact(multiples, normalized, magnitude, interval_raw)
      else
        find_multiple(multiples, normalized)
      end

    precision = get_precision(magnitude) + get_precision(multiple)
    Float.round(multiple * magnitude, precision)
  end

  def get_multiples(magnitude, allow_decimals, has_tick_amount) do
    defaults =
      if has_tick_amount do
        [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
      else
        [1, 2, 2.5, 5, 10]
      end

    cond do
      allow_decimals ->
        defaults

      magnitude == 1 ->
        Enum.filter(defaults, fn n ->
          round(n) == n
        end)

      magnitude <= 1 ->
        [1.0 / magnitude]

      true ->
        defaults
    end
  end

  def find_multiple(multiples, normalized) do
    case multiples do
      [m1, m2 | rest] ->
        if normalized <= (m1 + m2) / 2, do: m1, else: find_multiple([m2] ++ rest, normalized)

      [m1 | rest] ->
        if normalized <= m1, do: m1, else: find_multiple(rest, normalized)

      [] ->
        []
    end
  end

  def find_multiple_exact(multiples, normalized, magnitude, interval_raw) do
    case multiples do
      [m1 | rest] ->
        if m1 * magnitude >= interval_raw do
          m1
        else
          find_multiple_exact(rest, normalized, magnitude, interval_raw)
        end

      [] ->
        1
    end
  end

  def get_precision(num) do
    # nb: Simplified a bit by always converting to scientific notation
    scientific = :erlang.float_to_binary(1.0 * num, [{:scientific, 3}])

    case String.split(scientific, "e") do
      [_before_, after_] ->
        abs(String.to_integer(after_))

      _ ->
        0
    end
  end

  def get_beginning(min, interval) do
    multiple = min / interval

    if multiple == Float.round(multiple) do
      min
    else
      ceil_to(interval, min)
    end
  end

  # This might be borked
  defp ceil_to(precision, num), do: precision * Float.ceil(num / precision)

  def positions(min, max, beginning, interval, m, acc) do
    next_position = Float.round(beginning + m * interval, get_precision(interval))

    if next_position > max do
      acc
    else
      positions(min, max, beginning, interval, m + 1, acc ++ [next_position])
    end
  end
end
