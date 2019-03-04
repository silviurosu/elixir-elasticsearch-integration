defmodule ElixirElasticsearch.RestaurantConfiguration do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [:accept_pickup, :accept_delivery, :accept_curbside, :accept_dinein]
end

defmodule ElixirElasticsearch.RestaurantLocation do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [:city, :country, :street, :zip, :lat, :lng]
end

defmodule ElixirElasticsearch.Restaurant do
  @moduledoc """
  Base document to index in ES
  """

  alias ElixirElasticsearch.RestaurantConfiguration
  alias ElixirElasticsearch.RestaurantLocation

  @derive Jason.Encoder
  defstruct [
    :id,
    :permalink,
    :name,
    :locale,
    :published,
    :paused,
    :channels,
    :created_at,
    :updated_at,
    :configuration,
    :cuisines,
    :amenities,
    :locations
  ]

  @type t :: %__MODULE__{
          id: integer,
          permalink: String.t(),
          name: String.t(),
          locale: String.t(),
          published: boolean,
          paused: boolean,
          channels: [String.t()],
          created_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t(),
          configuration: RestaurantConfiguration.t(),
          cuisines: [String.t()],
          amenities: [String.t()],
          locations: [RestaurantLocation.t()]
        }
end

defimpl Elasticsearch.Document, for: ElixirElasticsearch.Restaurant do
  def id(i), do: i.id
  def routing(_), do: false

  def encode(i), do: i
end
