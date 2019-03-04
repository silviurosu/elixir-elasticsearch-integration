defmodule ElixirElasticsearch.SearchGateway do
  @moduledoc """
  Helper to communicate with Elasticsearch.
  It converts to query, sends the request and extracts the response.
  """

  require Logger

  alias ElixirElasticsearch.QueryConvertor
  alias Restaurants.Service.ElasticsearchCluster

  def search(params) do
    params |> QueryConvertor.convert() |> do_search
  end

  defp do_search(query) do
    Logger.debug("Searching in ES with query:")
    Logger.debug(fn -> inspect(query) end)

    resp = Elasticsearch.post(ElasticsearchCluster, search_path(), query)

    Logger.debug("Response from ES:")
    Logger.debug(fn -> inspect(resp) end)

    {:ok,
     %{
       "hits" => %{
         "hits" => results,
         "total" => total
       }
     }} = resp

    data = %{
      results: Enum.map(results, &extract_data/1),
      total: total,
      per_page: query["size"],
      page: compute_page(query["from"], query["size"])
    }

    {:ok, data}
  end

  defp extract_data(result) do
    result |> Map.get("_id")
  end

  defp compute_page(0, _), do: 1

  defp compute_page(from, size) when from > 0 do
    div(from, size) + 1
  end

  defp search_path do
    elastic_env = Application.get_env(:elixir_elasticsearch, :ELASTICSEARCH_ENV)
    "/restaurants_demo_#{elastic_env}/_doc/_search"
  end
end
