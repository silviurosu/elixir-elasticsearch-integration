# ElixirElasticsearch

Sketch application for integrating Elixir and Elasticsearch using the [elasticsearch](https://github.com/danielberkompas/elasticsearch-elixir) library.

Some of the features implemented here:

 -  a singe Genserver to take care of the ES index. We do not want to overload the cluster to get out of Java Heap Space
 -  a stream implementation to load all the documents to be sent to index
 -  a search DSL to do not expose the Elasticserach query syntax. It's easier to use and easier to upgrade to later versions of Elasticsearch in case changes are made.

## Indexing

Indexing can be done either by hot swap-ing the whole cluster:

```elixir
ElixirElasticsearch.IndexerGenserver.hot_swap()
```

either by sending a list of documents to index:

```elixir
ElixirElasticsearch.IndexerGenserver.index_restaurant("demorestaurant")
```

## Searching


Searching can be done by calling the search wrapper module:

```elixir
ElixirElasticsearch.SearchGateway.search(query)
```
