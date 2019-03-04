defmodule ElixirElasticsearch.ElasticsearchStore do
  @moduledoc """
  Store implementation for ES. It emits a stream to be used by ES library
  """
  @behaviour Elasticsearch.Store

  require Logger

  alias __MODULE__, as: M
  alias ElixirElasticsearch.RestaurantsSearchParams
  alias ElixirElasticsearch.DbMockService

  defstruct [:total, :page, :data]

  @per_page 200

  @params %RestaurantsSearchParams{
    per_page: @per_page
  }

  def base_params, do: @params

  @impl true
  def stream(%RestaurantsSearchParams{} = params) do
    params = %RestaurantsSearchParams{params | per_page: @per_page}
    do_stream(params)
  end

  def stream(_schema) do
    do_stream(@params)
  end

  defp do_stream(params) do
    Stream.resource(
      fn ->
        total = DbMockService.count_restaurants_for_index(params)
        Logger.info(fn -> "Found #{Integer.to_string(total)} restaurants." end)

        Logger.info(fn ->
          per_page = Integer.to_string(params.per_page)
          total_pages = Integer.to_string(Integer.floor_div(total - 1, params.per_page) + 1)
          "Loading #{per_page} restaurants from database. Page 1/#{total_pages}"
        end)

        params = %RestaurantsSearchParams{params | page: 1}

        data = load_restaurants(params)
        %M{total: total, page: 1, data: data}
      end,
      fn acc ->
        {elem, acc} = extract_next_element(acc, params)

        if is_nil(elem) do
          {:halt, acc}
        else
          {[elem], acc}
        end
      end,
      fn _ -> nil end
    )
  end

  @impl true
  def transaction(fun) do
    fun.()
  end

  defp extract_next_element(%M{data: [elem | tail]} = acc, _params) do
    {elem, %M{acc | data: tail}}
  end

  defp extract_next_element(%M{data: []} = acc, params) do
    %M{total: total, page: page} = acc

    if page * params.per_page >= total do
      {nil, acc}
    else
      next_page = page + 1

      Logger.info(fn ->
        per_page_str = Integer.to_string(params.per_page)
        next_page_str = Integer.to_string(next_page)
        total_pages = Integer.to_string(Integer.floor_div(total - 1, params.per_page) + 1)

        "Loading #{per_page_str} restaurants from DB. Page #{next_page_str}/#{total_pages}"
      end)

      params = %RestaurantsSearchParams{params | page: next_page}

      data = load_restaurants(params)
      [head | tail] = data
      acc = %M{total: total, page: next_page, data: tail}
      {head, acc}
    end
  end

  defp load_restaurants(params) do
    DbMockService.restaurants_for_index(params)
  end
end
