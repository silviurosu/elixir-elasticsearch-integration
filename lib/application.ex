defmodule ElixirElasticsearch.Application do
  @moduledoc false

  use Application

  alias ElixirElasticsearch.ElasticsearchCluster
  alias ElixirElasticsearch.IndexerSupervisor

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      ElasticsearchCluster,
      IndexerSupervisor
    ]

    update_elasticsearch_config()

    opts = [strategy: :one_for_one, name: ElixirElasticsearch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp update_elasticsearch_config do
    cfg = System.get_env("ELASTICSEARCH_ENV")

    if cfg do
      Application.put_env(:elixir_elasticsearch, :ELASTICSEARCH_ENV, cfg)
    end

    elastic_env = Application.get_env(:elixir_elasticsearch, :ELASTICSEARCH_ENV)
    cluster_key = String.to_atom("elasticsearch_settings_#{elastic_env}")
    elastic_settings = Application.get_env(:elixir_elasticsearch, cluster_key)
    elastic_settings = update_settings_file_path(elastic_settings, elastic_env)

    Application.put_env(
      :elixir_elasticsearch,
      ElixirElasticsearch.ElasticsearchCluster,
      elastic_settings
    )
  end

  defp update_settings_file_path(conf, elastic_env) do
    path = Path.join(:code.priv_dir(:elixir_elasticsearch), "/elasticsearch/restaurant.json")

    put_in(conf, [:indexes, String.to_atom("restaurants_demo_#{elastic_env}"), :settings], path)
  end
end
