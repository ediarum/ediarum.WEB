# Libraries of ediarum.WEB

## Frontend library `edbweb.xql`

The `edweb.xql` library contains functions which can be used directly in `*.html` files. They make use of the templating module of eXist. The functions are grouped by use:

- ADD funcctions returning complete html nodes
- INSERT functions returning strings
- LOAD functions are loading data from the API and storing into the $model map
- VIEW functions used by view.xql
- PARAMS functions handling parameters for get requests
- TEMPLATE functions returning nodes to be processed

### Load functions

The LOAD functions retrieve data from the backend and write to the `$model` variables. There the data can be processed by the frontend. 

*Setup*

```
import module namespace edweb="http://www.bbaw.de/telota/software/ediarum/web/lib";
```

## Controller library `edweb-controller.xql`

This library contains helper functions to be used in a `controller.xql` file, functions for request parameter handling and interface functions to the API/backend.

*Setup*

```
import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";
```

## Backend functions `edweb-api.xql`

The functions at the backend retrieves data and perform searches within the database.