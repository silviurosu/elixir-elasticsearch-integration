defmodule ElixirElasticsearch.ElasticsearchUtils do
  @moduledoc """
    Utility methods to work with Elasticsearch index. Wraps ES library methods.
  """

  alias Elasticsearch.Cluster.Config
  alias Elasticsearch.Index
  alias ElixirElasticsearch.ElasticsearchCluster

  def delete_index(index_name \\ default_index_name()) do
    Index.clean_starting_with(ElasticsearchCluster, index_name, 1)
  end

  def create_index(index_name \\ default_index_name()) do
    config =
      ElasticsearchCluster
      |> Config.get()
      |> Map.get(:indexes)
      |> Map.get(String.to_existing_atom(index_name))

    Index.create_from_file(ElasticsearchCluster, index_name, Map.get(config, :settings))
  end

  def recreate_index(index_name \\ default_index_name()) do
    delete_index(index_name)
    create_index(index_name)
  end

  def hot_swap(index_name \\ default_index_name()) do
    Index.hot_swap(ElasticsearchCluster, index_name)
  end

  def index_restaurant(restaurant) do
    Elasticsearch.put_document(ElasticsearchCluster, restaurant, default_index_name())
  end

  defp default_index_name do
    elastic_env = Application.get_env(:elixir_elasticsearch, :ELASTICSEARCH_ENV)
    "restaurants_demo_#{elastic_env}"
  end
end
