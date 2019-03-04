defmodule ElixirElasticsearch.RestaurantsSearchParams do
  @moduledoc """
    Params used to filter the integrations.
  """

  defstruct [
    :restaurant_id,
    :restaurant_permalink,
    :channel_id,
    :channel_permalink,
    :page,
    :per_page
  ]

  @type t :: %__MODULE__{
          restaurant_id: integer,
          restaurant_permalink: String.t(),
          channel_id: integer,
          channel_permalink: String.t(),
          page: pos_integer,
          per_page: pos_integer
        }
end
