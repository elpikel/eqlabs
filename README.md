# Eqlabs

Naive implementation of a periodic self-rehydrating cache. The cache register 0-arity functions (each under a new key) that recompute periodically and store their results in the cache for fast-access instead of being called every time the values are needed.

## Architecture

Main entry to cache is `Eqlabs.Cache` it exposes two functions: 

- `register_function` - creates `Eqlabs.Cache.Item` using `Eqlabs.Cache.ItemsSupervisor`
- `get` - gets data from `Eqlabs.Cache.Item`, when cache is expired it removes it from `Registry`

Each cache item is encapsulated in `Eqlabs.Cache.Item` Genserver which periodically runs passed function. It stops doing that when cache expires which means that we were not able to succesfully run function in given `ttl`. For each function run we create `Task` to not block `Eqlabs.Cache.Item` in that way we can serve previous calculated value to clients while running function in background.

Each cache item is registered in `Registry` because of this when cache item fails it is removed from it. Cache item is also removed from registry when cache expires.
For now cache item do not signal when cache expires, it is discovered when cache tries to get it. Stopping cache item Genserver and sending signal to cache that it is down can lead to concurrency issues. This can be solved using periodicall cleanup in cache genserver.

## Further improvements

Cached values should be stored in ETS table.
Provide limit on how many values cache can keep.
Discard cache items periodically.
