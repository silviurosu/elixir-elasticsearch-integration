defmodule ElixirElasticsearch.QueryConvertorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias ElixirElasticsearch.QueryConvertor

  test "generate query from input basic query" do
    input = %{
      "channel_id" => "demorestaurant",
      "conditions" => [
        %{
          "field" => "name",
          "op" => "equals",
          "value" => "Pizzeria Aroma"
        },
        %{
          "field" => "name",
          "op" => "starts_with",
          "value" => "Pizz"
        },
        %{
          "field" => "locale",
          "op" => "equals",
          "value" => "en"
        },
        %{
          "field" => "services",
          "op" => "all_of",
          "value" => ["pickup", "delivery"]
        },
        %{
          "field" => "cuisines",
          "op" => "all_of",
          "value" => ["Pizza", "Salads ", "Pasta"]
        },
        %{
          "field" => "amenities",
          "op" => "any_of",
          "value" => ["online orders", "Delivery", "outdoor seeting"]
        },
        %{
          "field" => "location",
          "op" => "less_than",
          "value" => %{
            "distance" => "50mi",
            "position" => %{
              "lat" => 39.7589478,
              "lng" => -84.19160690000001
            }
          }
        },
        %{
          "field" => "location",
          "op" => "equals",
          "value" => %{
            "city" => "Conshohocken",
            "zip" => "32502",
            "position" => %{
              "lat" => 30.41033,
              "lng" => 87.214
            }
          }
        }
      ],
      "sort" => [
        %{
          "type" => "distance",
          "value" => %{
            "lat" => 39.7589478,
            "lng" => -84.19160690000001
          },
          "order" => "asc"
        },
        %{
          "type" => "term",
          "value" => "name",
          "order" => "asc"
        }
      ],
      "page" => 1,
      "per_page" => 50
    }

    expected_result = %{
      "_source" => false,
      "query" => %{
        "bool" => %{
          "must" => [
            %{
              "bool" => %{
                "should" => [
                  %{
                    "geo_distance" => %{
                      "distance" => "100m",
                      "locations.position" => %{
                        "lat" => 30.41033,
                        "lon" => 87.214
                      }
                    }
                  },
                  %{"term" => %{"locations.zip" => "32502"}},
                  %{"term" => %{"locations.city" => "conshohocken"}}
                ],
                "minimum_should_match" => 1
              }
            },
            %{
              "bool" => %{
                "should" => [
                  %{"term" => %{"amenities" => "online orders"}},
                  %{"term" => %{"amenities" => "delivery"}},
                  %{"term" => %{"amenities" => "outdoor seeting"}}
                ],
                "minimum_should_match" => 1
              }
            },
            %{"term" => %{"cuisines" => "pasta"}},
            %{"term" => %{"cuisines" => "salads"}},
            %{"term" => %{"cuisines" => "pizza"}},
            %{"term" => %{"configuration.accept_delivery" => true}},
            %{"term" => %{"configuration.accept_pickup" => true}},
            %{"term" => %{"locale" => "en"}},
            %{
              "bool" => %{
                "should" => [
                  %{"wildcard" => %{"name" => %{"value" => "*pizz*", "boost" => 2}}},
                  %{"prefix" => %{"name" => %{"value" => "pizz", "boost" => 3}}},
                  %{"prefix" => %{"name" => %{"value" => "pizz ", "boost" => 4}}}
                ],
                "minimum_should_match" => 1
              }
            },
            %{"term" => %{"name" => "pizzeria aroma"}}
          ],
          "filter" => [
            %{
              "geo_distance" => %{
                "distance" => "50mi",
                "locations.position" => %{
                  "lat" => 39.7589478,
                  "lon" => -84.19160690000001
                }
              }
            },
            %{"term" => %{"channels" => "demorestaurant"}},
            %{"term" => %{"published" => true}},
            %{"term" => %{"paused" => false}}
          ]
        }
      },
      "sort" => [
        %{
          "_geo_distance" => %{
            "unit" => "mi",
            "order" => "asc",
            "locations.position" => [-84.19160690000001, 39.7589478]
          }
        },
        %{"name_str" => "asc"}
      ],
      "from" => 0,
      "size" => 50
    }

    result = QueryConvertor.convert(input)
    assert result == expected_result
  end
end
