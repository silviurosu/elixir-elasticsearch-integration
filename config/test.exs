use Mix.Config

config :elixir_elasticsearch, ELASTICSEARCH_ENV: "test"

config :elixir_elasticsearch, :elasticsearch_settings_test,
  username: "username",
  password: "password",
  json_library: Jason,
  url: "https://server:port",
  api: Elasticsearch.API.HTTP,
  # default_options: [ssl: [{:versions, [:'tlsv1.2']}],
  indexes: %{
    restaurants_demo_test: %{
      settings: "/priv/elasticsearch/restaurant.json",
      store: ElixirElasticsearch.ElasticsearchStore,
      sources: [ElixirElasticsearch.Restaurant],
      bulk_page_size: 100,
      bulk_wait_interval: 3000
    }
  },
  default_options: [
    timeout: 10_000,
    recv_timeout: 5_000,
    hackney: [pool: :elasticsearh_pool]
  ]
