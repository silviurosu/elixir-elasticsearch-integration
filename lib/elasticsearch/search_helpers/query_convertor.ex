defmodule ElixirElasticsearch.QueryConvertor do
  @moduledoc """
    Convertor helper to convert between UI query params and ES query syntax
  """

  @default_size 20
  @max_page_size 100

  @base_query %{
    "_source" => false,
    "query" => %{
      "bool" => %{
        "must" => [],
        "filter" => [
          %{"term" => %{"published" => true}},
          %{"term" => %{"paused" => false}}
        ]
      }
    },
    "from" => 0,
    "size" => @default_size
  }

  @doc """
  Converts from params received from UI to ES query syntax
  """
  def convert(params) do
    @base_query
    |> add_channel_filter(params)
    |> add_pagination(params)
    |> add_all_conditions(params)
    |> add_sorting(params)
  end

  defp add_channel_filter(query, %{"channel_id" => channel_id}) do
    update_in(query, ["query", "bool", "filter"], fn existing ->
      new_filter = %{"term" => %{"channels" => clear_value(channel_id)}}
      [new_filter | existing]
    end)
  end

  defp add_pagination(query, %{"page" => page, "per_page" => per_page})
       when is_integer(page) and is_integer(per_page) do
    page_size = min(per_page, @max_page_size)
    from = (page - 1) * page_size
    query |> Map.put("from", from) |> Map.put("size", page_size)
  end

  defp add_pagination(query, _), do: query

  defp add_all_conditions(query, %{"conditions" => conditions})
       when is_list(conditions) and conditions != [] do
    Enum.reduce(conditions, query, &append_condition/2)
  end

  defp add_all_conditions(query, _), do: query

  defp append_condition(%{"field" => "name", "op" => "equals", "value" => value}, acc)
       when is_binary(value) do
    update_in(acc, ["query", "bool", "must"], fn existing ->
      new_filter = %{"term" => %{"name" => clear_value(value)}}
      [new_filter | existing]
    end)
  end

  defp append_condition(%{"field" => "name", "op" => "starts_with", "value" => value}, acc)
       when is_binary(value) do
    update_in(acc, ["query", "bool", "must"], fn existing ->
      value = clear_value(value)

      should = %{
        "bool" => %{
          "should" => [
            %{"wildcard" => %{"name" => %{"value" => "*#{value}*", "boost" => 2}}},
            %{"prefix" => %{"name" => %{"value" => value, "boost" => 3}}},
            %{"prefix" => %{"name" => %{"value" => "#{value} ", "boost" => 4}}}
          ],
          "minimum_should_match" => 1
        }
      }

      [should | existing]
    end)
  end

  defp append_condition(%{"field" => "services", "op" => "all_of", "value" => values}, acc)
       when is_list(values) do
    Enum.reduce(values, acc, fn val, acc1 ->
      update_in(acc1, ["query", "bool", "must"], fn existing ->
        key = clear_value(val)
        new_filter = %{"term" => %{"configuration.accept_#{key}" => true}}
        [new_filter | existing]
      end)
    end)
  end

  defp append_condition(%{"field" => field, "op" => "all_of", "value" => values}, acc)
       when is_list(values) do
    Enum.reduce(values, acc, fn val, acc1 ->
      update_in(acc1, ["query", "bool", "must"], fn existing ->
        new_filter = %{"term" => %{field => clear_value(val)}}
        [new_filter | existing]
      end)
    end)
  end

  defp append_condition(%{"field" => "services", "op" => "any_of", "value" => values}, acc)
       when is_list(values) do
    conditions =
      Enum.map(values, fn val ->
        key = clear_value(val)
        %{"term" => %{"configuration.accept_#{key}" => true}}
      end)

    update_in(acc, ["query", "bool", "must"], fn existing ->
      new_filter = %{"bool" => %{"should" => conditions, "minimum_should_match" => 1}}
      [new_filter | existing]
    end)
  end

  defp append_condition(%{"field" => field, "op" => "any_of", "value" => values}, acc)
       when is_list(values) do
    conditions = Enum.map(values, fn val -> %{"term" => %{field => clear_value(val)}} end)

    update_in(acc, ["query", "bool", "must"], fn existing ->
      new_filter = %{"bool" => %{"should" => conditions, "minimum_should_match" => 1}}
      [new_filter | existing]
    end)
  end

  defp append_condition(
         %{
           "field" => "location",
           "op" => "less_than",
           "value" => %{"distance" => distance, "position" => %{"lat" => lat, "lng" => lng}}
         },
         acc
       )
       when is_binary(distance) and is_float(lat) and is_float(lng) do
    update_in(acc, ["query", "bool", "filter"], fn existing ->
      new_filter = %{
        "geo_distance" => %{
          "distance" => distance,
          "locations.position" => %{"lat" => lat, "lon" => lng}
        }
      }

      [new_filter | existing]
    end)
  end

  defp append_condition(%{"field" => "location", "op" => "equals", "value" => value}, acc) do
    new_filter =
      %{"bool" => %{"should" => [], "minimum_should_match" => 1}}
      |> append_location_city_condition(value)
      |> append_location_zip_condition(value)
      |> append_location_position_condition(value)

    update_in(acc, ["query", "bool", "must"], fn existing -> [new_filter | existing] end)
  end

  defp append_condition(%{"op" => "equals"} = c, acc) do
    %{"field" => field, "value" => value} = c

    update_in(acc, ["query", "bool", "must"], fn existing ->
      new_filter = %{"term" => %{field => value}}
      [new_filter | existing]
    end)
  end

  defp append_condition(_, acc), do: acc

  defp add_sorting(query, %{"sort" => sort}) when is_list(sort) and sort != [] do
    sort_query = sort |> Enum.map(&convert_sort/1)
    Map.put_new(query, "sort", sort_query)
  end

  defp add_sorting(query, _), do: query

  defp convert_sort(%{"type" => "term", "value" => "name", "order" => order})
       when is_binary(order) and order in ["asc", "desc"] do
    %{"name_str" => order}
  end

  defp convert_sort(%{"type" => "term", "value" => value, "order" => order})
       when is_binary(value) and is_binary(order) and order in ["asc", "desc"] do
    %{value => order}
  end

  defp convert_sort(%{
         "type" => "distance",
         "value" => %{"lat" => lat, "lng" => lng},
         "order" => order
       })
       when is_binary(order) and order in ["asc", "desc"] and is_float(lat) and is_float(lng) do
    %{
      "_geo_distance" => %{
        "unit" => "mi",
        "order" => order,
        "locations.position" => [lng, lat]
      }
    }
  end

  defp append_location_city_condition(acc, %{"city" => city}) when is_binary(city) do
    update_in(acc, ["bool", "should"], fn existing ->
      new_filter = %{"term" => %{"locations.city" => clear_value(city)}}
      [new_filter | existing]
    end)
  end

  defp append_location_city_condition(acc, _), do: acc

  defp append_location_zip_condition(acc, %{"zip" => zip}) when is_binary(zip) do
    update_in(acc, ["bool", "should"], fn existing ->
      new_filter = %{"term" => %{"locations.zip" => zip}}
      [new_filter | existing]
    end)
  end

  defp append_location_zip_condition(acc, _), do: acc

  defp append_location_position_condition(acc, %{"position" => %{"lat" => lat, "lng" => lng}})
       when is_float(lat) and is_float(lng) do
    update_in(acc, ["bool", "should"], fn existing ->
      new_filter = %{
        "geo_distance" => %{
          "distance" => "100m",
          "locations.position" => %{"lat" => lat, "lon" => lng}
        }
      }

      [new_filter | existing]
    end)
  end

  defp append_location_position_condition(acc, _), do: acc

  defp clear_value(str), do: str |> String.downcase() |> String.trim()
end
