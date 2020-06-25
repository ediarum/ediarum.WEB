# API

## List

Returns a list of all items of an object type or relation type as JSON.

`/api/<object-relation-type>`

- `object-relation-type` the ID of the object definition or the relation definition in the `appconf.xml`

### GET-Parameters

The following parameters are only for object lists not for relation lists:

- For defined properties GET-parameter can be added. E.g. if `city` is a defined property it is possible to filter the list by adding `city=Berlin`.
- `from` defines which is the first item to be shown. To be used with `range`.
- `order` by which the list should be ordered
- `page` defines which page of list results should be returned. To be used with `range`.
- `range` how many items should be return. To be used with `page` or `from`.
- `show` Possible values 
  - `all` show all objects
  - `compact` show all objects but in compact form, i.e. without properties
  - `filter` show the filter definitions
  - `list` show objects matching the filter criteria