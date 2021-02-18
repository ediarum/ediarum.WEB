# API

- [API](#api)
  - [1. APPCONF](#1-appconf)
  - [2. List of all IDs](#2-list-of-all-ids)
    - [2.1 GET-Parameters](#21-get-parameters)
  - [3. List of objects or relations](#3-list-of-objects-or-relations)
    - [3.1 GET-Parameters](#31-get-parameters)
    - [3.2 Examples](#32-examples)
    - [3.3 Results](#33-results)
      - [Default `/api/<object-type>`](#default-apiobject-type)
      - [Default `/api/<relation-type>`](#default-apirelation-type)
  - [4. Get object](#4-get-object)
    - [4.1 GET-Parameters](#41-get-parameters)
    - [4.2 Examples](#42-examples)
    - [4.3 Results](#43-results)
      - [JSON output: `/api/<object-type>/<object-id>`](#json-output-apiobject-typeobject-id)
  - [5. Searching](#5-searching)
    - [5.1 GET-Parameters](#51-get-parameters)
    - [5.2 Examples](#52-examples)
    - [5.3 Result](#53-result)
      - [JSON output: `/api/search/<search-id>?q=<query>`](#json-output-apisearchsearch-idqquery)
  - [6. Caching](#6-caching)

## 1. APPCONF

Returns the definition of the `appconf.xml`.

`/api`

## 2. List of all IDs

Returns a JSON list with all object IDs to identify by ID which object type a speficied object has.

`/api?id=all`

### 2.1 GET-Parameters

- `id` must be equal to `all`.
- optional `limit` defines how many objects of each type are retrieved, 

## 3. List of objects or relations

Returns a list of all items of an object type or relation type as JSON. 

*Attention: Because of performance issues only 10'000 entries are returned.
If more are requested please use the `limit` parameter.*

`/api/<object-relation-type>`

- `object-relation-type` the ID of the object definition or the relation definition in the `appconf.xml`

### 3.1 GET-Parameters

The following parameters are only for object lists not for relation lists:

- For defined properties GET-parameter can be added. E.g. if `city` is a defined property it is possible to filter the list by adding `city=Berlin`.
- `from` defines which is the first item to be shown. To be used with `range`.
- `limit` optional parameter. Defines how many (unordered) object entries are retrieved (default value is 10'000). For relations it defines how many object entries are used for searching the relations.
- `order` by which the list should be ordered
- `page` defines which page of list results should be returned. To be used with `range`.
- `range` how many items should be return. To be used with `page` or `from`.
- `search` filters the objects by a search. Can be combined with other filters. To be used with `show=(all, compact, list)`.
- `search-type` optional parameter. To be used with `search`. With following values:
  - with empty value the exact matches are found. Multiple words are separated with a space.
  - `regex` for one or more words (separated by space) using regular expressions
  - `phrase` for a query of multiple words. With `slop` the distance can be defined (default is 1).
  - `lucene` for a lucene query, see <https://lucene.apache.org/core/2_9_4/queryparsersyntax.html>
- `show` possible values are: 
  - `all` show all objects
  - `compact` show all objects but in compact form, i.e. without properties
  - `filter` show the filter definitions
  - `list` show objects matching the filter criteria
- `slop` the distance of words in a phrase search. To be used with `search` and `search-type=phrase`.

The following parameters are for relation lists:

- `limit` optional parameter. Defines how many (unordered) entries are retrieved (default value is 10'000). For relations it defines how many object entries are used for searching the relations.
- `object` defines the object ID the items to be filtered by. To be used with `show=list`.
- `subject` defines the subject ID the items to be filtered by. To be used with `show=list`
- `show` possible values are:
  - `list` show relation items matching filter criteria
  - empty show all relation items

### 3.2 Examples

- manuscript list filtered by repository: `/api/ms?show=list&city=Berlin&repository=Staatsbibliothek`
- first twenty entries of persons: `/api/persons?show=list&order=label&range=20&page=1`
- show list of person-manuscript relations: `/api/person-manuscript`
- show letters from berlin containing the word 'Wetter': `/api/letters?show=list&place=Berlin&search=Wetter`

### 3.3 Results

#### Default `/api/<object-type>`

- `?date-time` stamp of caching
- `?filter` list of filters
- `?filter?("filter-id")` contains the follwing values:
  - `?id` of filter
  - `?name` of filter
  - `?depends` on which other filter
  - `?n` order number of filter
  - `?type` of filter
  - `?xpath` to get the raw filter value
  - `?label-function` to get the processed filter value
- `?list` of objects
- `?list?("object-id")` contains the following values:
  - `?absolute-resource-id` object
  - `?id` of object
  - `?object-type` of object
  - `?label` main label of object
  - `?labels` list of labels of object
  - `?label-filter` values if defined
  - `?filter` list of object
  - `?filter?("filter-id")` filter value of object
  - `?search-results` contains an array of hits, if a search was triggered. Each hit containing:
    - `?context-previous` of the found keyword
    - `?keyword` found by search
    - `?context-following` of the found keyword
    - `?score` of this single search hit
  - `?score` of the search if triggered otherwise '0'
- `?type` equals "object"
- `?results-found` number of all objects
- `?results-shown` number of objects in `list`. Equals to `results-found` if equal or lower then the `limit` parameter.

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

## 4. Get object

Returns a information of a single object.

`/api/<object-type>/<object-id>`

### 4.1 GET-Parameters

- `output` possible values are:
  - `xml` the XML representation of the object is retrieved. Can be used with `view`.
  - `html` a HTML serialization of the object is retrieved. To be used with `view`.
  - `text` a text serialization of the object is retrieved. To be used with `view`.
  - `json-xml` some of the object information is retrieved as JSON, including the XML.
  - if not set: some object information is retrieved as JSON
- `view` defines which view (see [APPCONF.md](APPCONF.md)) is used to transform the object. The result is retrieved. To be used with `output`.

### 4.2 Examples

- XML representation: `/api/persons/p123456?output=xml`
- XML output with special view: `/api/letters/l123456?output=xml&view=my_view`

### 4.3 Results

#### JSON output: `/api/<object-type>/<object-id>`

- `?absolute-resource-id` eXist-db specific id of the ressource containing the object 
- `?filter` values of object, see list of objects above.
- `?id` of object
- `?label` of object
- `?labels` of object
- `?label-filter` of object, see list of objects above.
- `?inner-nav` of object
- `?inner-nav?("inner-nav-id")` contains the following values:
  - `?id` where to find the IDs of items (XPath)
  - `?label-function` of items (XQuery function)
  - `?list` of items. The items of the array contain the following values:
    - `?id` of item
    - `?label` of item
  - `?name` of inner-nav
  - `?order-by` how to order the items. Possible values are
    - `label` order by label
    - if not set items are ordered by position in xml
  - `?xpath` where to find the inner-nav items (XPath)
- `?object-type` of object
- `?parts` of object if defined and found
- `?parts?("part-id)` contains the following values:
  - `?depends` on which other part definitions
  - `?id` definition of part id
  - `?path` full path to part
  - `?root` definition of part root
  - `?xmlid` of part
- `?views` contains the defined views for the object
- `?views?("view-id")` contains the following values:
  - `?id` of view
  - `?label` of view
  - `?params` defined parameters for the view
  - `?xslt` relative path to view xslt

**Example**

JSON information of a person:

`/api/person/p123456`

Results in:

```json
{
  "absolute-resource-id" : 2869038157266,
  "label" : "Homer",
  "id" : "person123456",
  "inner-nav" : { },
  "parts" : { },
  "views" : {
    "default" : {
      "xslt" : "resources/xslt/person-details.xsl",
      "params" : "",
      "label" : "Details",
      "id" : "default"
    },
    "metadata" : {
      "xslt" : "resources/xslt/person-metadata.xsl",
      "params" : "",
      "label" : "Metadata",
      "id" : "metadata"
    }
  }
}
```

## 5. Searching

Uses the the defined search routines and shows the results ordered by score:

`/api/search/<search-id>`

### 5.1 GET-Parameters

- `q` the query string to be searched for
- optional `kwic-width` parameter defines the range of characters showed the kwic (key word in context) results.
- optional `limit` defines how many objects for searching are retrieved, see above [List of objects](#2-list-of-objects-or-relations).
- optional `type` the type of query. Possible values are:
  - `regex` for a query using regular expressions
  - `phrase` for a query of multiple words combined by `AND`
  - `lucene` for a lucene query, see <https://lucene.apache.org/core/2_9_4/queryparsersyntax.html>
- optional `slop` the distance between words in a phrase. Used with `type=phrase`

### 5.2 Examples

- Search for a word in all indexes (persons, places, etc.): `/api/search/all-indexes?q=Berlin`

### 5.3 Result

#### JSON output: `/api/search/<search-id>?q=<query>`

- `?date-time` stamp of the search 
- `?type` equals "search"
- `?id` of search
- `?query` contains the query string
- `?kwic-width` contains the kwic-width used. Default is 30.
- `?list` contains maps of the objects with hits, see above.

**Example**

Search for a text in manuscipt descriptions:

`/api/search/manuscript-descr?q=Berlin`

Results in:

```json
```

## 6. Caching

Due to performance some of the API calls are cached. So calls like `/api/<object-type>`
result in a cache for all entities of `<object-type>` and their properties.

If data is changed and the cache can be rebuild by adding a GET parameter
to the above API calls:

- `cache`. Possible values are:
  - `no` cache is rebuild if newer data exists
  - `reset` cache is always rebuild (exception: cache is not rebuild if it is newer than 1 minute)