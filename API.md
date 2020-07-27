# API

- [API](#api)
  - [1. List of objects or relations](#1-list-of-objects-or-relations)
    - [1.1 GET-Parameters](#11-get-parameters)
    - [1.2 Examples](#12-examples)
  - [2. Get object](#2-get-object)
    - [2.1 GET-Parameters](#21-get-parameters)
    - [2.2 Examples](#22-examples)

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
- `show` possible values are: 
  - `all` show all objects
  - `compact` show all objects but in compact form, i.e. without properties
  - `filter` show the filter definitions
  - `list` show objects matching the filter criteria

### 1.2 Examples

- manuscript list filtered by repository: `/api/ms?show=list&city=Berlin&repository=Staatsbibliothek`
- first twenty entries of persons: `/api/persons?show=list&order=label&range=20&page=1`
- show list of person-manuscript relations: `/api/person-manuscript`

## 2. Get object

Returns a information of a single object.

`/api/<object-type>/<object-id>`

### 2.1 GET-Parameters

- `output` possible values are:
  - `xml` the XML representation of the object is retrieved
  - `html` the HTML representation of the object is retrieved
  - of not set some object information is retrieved as JSON
- `view` defines which view (see [APPCONF.md](APPCONF.md)) is used to transform the object. The result is retrieved. To be used with `output`.

### 2.2 Examples

- XML representation: `/api/persons/p123456?output=xml`
- XML output with special view: `/api/letters/l123456?output=xml&view=my_view`
- JSON information of a person: `/api/person/p123456`