defmodule ElixirElasticsearch.DbMockService do
  @moduledoc """
  Mock implementation for Database access.
  TODO - Implement your own ecto implementation here
  """
  alias ElixirElasticsearch.RestaurantsSearchParams
  alias ElixirElasticsearch.Restaurant
  alias ElixirElasticsearch.RestaurantConfiguration
  alias ElixirElasticsearch.RestaurantLocation

  @count 1000

  def count_restaurants_for_index(_params), do: @count

  def restaurants_for_index(%RestaurantsSearchParams{per_page: per_page, page: page}) do
    current_index = (page - 1) * per_page

    if current_index > @count do
      []
    else
      for i <- 1..per_page do
        restaurant(current_index + i)
      end
    end
  end

  defp restaurant(i) do
    name = :crypto.strong_rand_bytes(10) |> Base.url_encode64(padding: false)

    %Restaurant{
      id: i,
      permalink: String.downcase(name),
      name: name,
      locale: "en",
      published: true,
      paused: false,
      channels: ["demo", "test", "facebook"],
      created_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now(),
      configuration: %RestaurantConfiguration{
        accept_pickup: true,
        accept_delivery: true,
        accept_curbside: true,
        accept_dinein: true
      },
      cuisines: ["american", "pizza"],
      amenities: ["bar", "online reservation"],
      locations: [
        %RestaurantLocation{
          city: "Chicago",
          country: "US",
          street: "Random Street",
          zip: "60000",
          lat: 34.565,
          lng: -86.4433
        },
        %RestaurantLocation{
          city: "Los Angeles",
          country: "US",
          street: "Random Street",
          zip: "60000",
          lat: 34.565,
          lng: -86.4433
        }
      ]
    }
  end
end
