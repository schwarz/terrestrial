defmodule TerrestrialTest do
  use ExUnit.Case
  doctest Terrestrial

  test "greets the world" do
    assert Terrestrial.hello() == :world
  end
end
