# API

- [API](#api)
  - [1. List of objects or relations](#1-list-of-objects-or-relations)
    - [1.1 GET-Parameters](#11-get-parameters)
    - [1.2 Examples](#12-examples)
    - [1.3 Results](#13-results)
      - [Default `/api/<object-type>`](#default-apiobject-type)
  - [2. Get object](#2-get-object)
    - [2.1 GET-Parameters](#21-get-parameters)
    - [2.2 Examples](#22-examples)
    - [2.3 Results](#23-results)
      - [JSON output: `/api/<object-type>/<object-id>`](#json-output-apiobject-typeobject-id)
  - [3. Searching](#3-searching)
    - [3.1 GET-Parameters](#31-get-parameters)
    - [3.2 Examples](#32-examples)
    - [3.3 Result](#33-result)
      - [JSON output: `/api/search/<search-id>?q=<query>`](#json-output-apisearchsearch-idqquery)

## 1. List of objects or relations

Returns a list of all items of an object type or relation type as JSON.

`/api/<object-relation-type>`

- `object-relation-type` the ID of the object definition or the relation definition in the `appconf.xml`

### 1.1 GET-Parameters

The following parameters are only for object lists not for relation lists:

- For defined properties GET-parameter can be added. E.g. if `city` is a defined property it is possible to filter the list by adding `city=Berlin`.
- `from` defines which is the first item to be shown. To be used with `range`.
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

### 1.2 Examples

- manuscript list filtered by repository: `/api/ms?show=list&city=Berlin&repository=Staatsbibliothek`
- first twenty entries of persons: `/api/persons?show=list&order=label&range=20&page=1`
- show list of person-manuscript relations: `/api/person-manuscript`
- show letters from berlin containing the word 'Wetter': `/api/letters?show=list&place=Berlin&search=Wetter`

### 1.3 Results

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
- `?type` equals "object"
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

## 2. Get object

Returns a information of a single object.

`/api/<object-type>/<object-id>`

### 2.1 GET-Parameters

- `output` possible values are:
  - `xml` the XML representation of the object is retrieved. Can be used with `view`.
  - `html` a HTML serialization of the object is retrieved. To be used with `view`.
  - `text` a text serialization of the object is retrieved. To be used with `view`.
  - of not set some object information is retrieved as JSON
- `view` defines which view (see [APPCONF.md](APPCONF.md)) is used to transform the object. The result is retrieved. To be used with `output`.

### 2.2 Examples

- XML representation: `/api/persons/p123456?output=xml`
- XML output with special view: `/api/letters/l123456?output=xml&view=my_view`

### 2.3 Results

#### JSON output: `/api/<object-type>/<object-id>`

- `?absolute-resource-id` eXist-db specific id of the ressource containing the object 
- `?label` of object
- `?id` of object
- `?views` contains the defined views for the object
- `?views?("view-id")?xslt` relative path to view xslt
- `?views?("view-id")?params` defined parameters for the view
- `?views?("view-id")?label` of view
- `?views?("view-id")?id` of view

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

## 3. Searching

Uses the the defined search routines and shows the results ordered by score:

`/api/search/<search-id>`

### 3.1 GET-Parameters

- `q` the query string to be searched for
- optional `kwic-width` parameter defines the range of characters showed the kwic (key word in context) results.
- optional `type` the type of query. Possible values are:
  - `regex` for a query using regular expressions
  - `phrase` for a query of multiple words combined by `AND`
  - `lucene` for a lucene query, see <https://lucene.apache.org/core/2_9_4/queryparsersyntax.html>
- optional `slop` the distance between words in a phrase. Used with `type=phrase`

### 3.2 Examples

- Search for a word in all indexes (persons, places, etc.): `/api/search/all-indexes?q=Berlin`

### 3.3 Result

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