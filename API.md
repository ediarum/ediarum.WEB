# API

- [1. APPCONF](#1-appconf)
- [2. List of all IDs](#2-list-of-all-ids)
  - [2.1 GET-Parameters](#21-get-parameters)
- [3. List of objects or relations](#3-list-of-objects-or-relations)
  - [3.1 GET-Parameters](#31-get-parameters)
  - [3.2 Results](#32-results)
    - [Default `/api/<relation-type>`](#default-apirelation-type)
  - [3.3 Examples](#33-examples)
- [4. Get object](#4-get-object)
- [5. Get part of an object](#5-get-part-of-an-object)
- [6. Searching](#6-searching)
  - [6.1 GET-Parameters](#61-get-parameters)
  - [6.2 Result](#62-result)
    - [JSON output: `/api/search/<search-id>?q=<query>`](#json-output-apisearchsearch-idqquery)
  - [6.3 Examples](#63-examples)
- [7. Caching](#7-caching)

## 1. APPCONF

Returns the definition of the `appconf.xml`.

`/api`

## 2. List of all IDs

Returns a JSON list with all object IDs to identify by ID which object type a speficied object has.

`/api?id=all`

### 2.1 GET-Parameters

- `id` is the same as the parameter `id-type`.
- `id-type` possible values are:
  - `all` get the ids of all objects
  - `complete` get the ids and properties of all objects
  - other values: to filter only objects which have a id property of this type, e.g. `id-type=gnd`.
- optional `limit` defines how many objects of each type are retrieved,

## 3. List of objects or relations

Returns a list of all items of an object type or relation type as JSON.

For the list of objects see the newer [OPENAPI documentation](openapi.yml).

*Attention: Because of performance issues only 10'000 entries are returned.
If more are requested please use the `limit` parameter.*

`/api/<object-relation-type>`

- `object-relation-type` the ID of the object definition or the relation definition in the `appconf.xml`

### 3.1 GET-Parameters

The following parameters are for relation lists:

- `limit` optional parameter. Defines how many (unordered) entries are retrieved (default value is 10'000). For relations it defines how many object entries are used for searching the relations.
- `object` defines the object ID the items to be filtered by. To be used with `show=list`.
- `subject` defines the subject ID the items to be filtered by. To be used with `show=list`
- `show` possible values are:
  - `list` show relation items matching filter criteria
  - empty show all relation items

### 3.2 Results

#### Default `/api/<relation-type>`

- `?date-time` stamp of caching
- `?list` of relations
- `?list?(#position)` contains the following values:
  - `?absolute-resource-id` of relation xml
  - `?internal-node-id` of relation xml
  - `?object` ID of relation
  - `?predicate` value of relation
  - `?subject` ID of relation
  - `?xml` of relation
- `?name` of relation
- `?object-type` of relation
- `?results-found` number of relations
- `?results-shown` number of relations in `list`. Equals to `results-found` if equal or lower then the `limit`parameter.
- `?subject-type` of relation
- `?type` equals "relations"

### 3.3 Examples

- show list of person-manuscript relations: `/api/person-manuscript`

## 4. Get object

Returns a information of a single object.

For retrieving an object see the newer [OPENAPI documentation](openapi.xml).

`/api/<object-type>/<object-id>`

## 5. Get part of an object

Returns a part of a single object as xml.

For retrieving a part of an object see the newer [OPENAPI documentation](openapi.xml).

`/api/<object-type>/<object-id>/<object-part>`

## 6. Searching

Uses the the defined search routines and shows the results ordered by score:

`/api/search/<search-id>`

### 6.1 GET-Parameters

- `q` the query string to be searched for
- optional `kwic-width` parameter defines the range of characters showed the kwic (key word in context) results.
- optional `limit` defines how many objects for searching are retrieved, see above [List of objects](#2-list-of-objects-or-relations).
- optional `type` the type of query. Possible values are:
  - `regex` for a query using regular expressions
  - `phrase` for a query of multiple words combined by `AND`
  - `lucene` for a lucene query, see <https://lucene.apache.org/core/2_9_4/queryparsersyntax.html>
- optional `slop` the distance between words in a phrase. Used with `type=phrase`

### 6.2 Result

#### JSON output: `/api/search/<search-id>?q=<query>`

- `?date-time` stamp of the search
- `?type` equals "search"
- `?id` of search
- `?query` contains the query string
- `?kwic-width` contains the kwic-width used. Default is 30.
- `?list` contains maps of the objects with hits, see above.

### 6.3 Examples

- Search for a word in all indexes (persons, places, etc.): `/api/search/all-indexes?q=Berlin`
- Search for a text in manuscipt descriptions:
  `/api/search/manuscript-descr?q=Berlin`
  results in:

  ```json
  ```

## 7. Caching

Due to performance some of the API calls are cached. So calls like `/api/<object-type>`
result in a cache for all entities of `<object-type>` and their properties.

If data is changed and the cache can be rebuild by adding a GET parameter
to the above API calls:

- `cache`. Possible values are:
  - `no` cache is rebuild if newer data exists
  - `reset` cache is always rebuild (exception: cache is not rebuild if it is newer than 1 minute)
