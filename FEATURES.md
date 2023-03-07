# Features

- [Backend API](#backend-api)
- [Automatic link generation](#automatic-link-generation)
- [Referrer and highlighting](#referrer-and-highlighting)
- [Preconfigured layout](#preconfigured-layout)
  - [Colors and fonts](#colors-and-fonts)
- [Citation Text Services API (CTS API)](#citation-text-services-api-cts-api)
- [Example for `controller.xql`](#example-for-controllerxql)

## Backend API

ediarum.WEB offers a API to retrieve all needed data for the frontend. Details of the API is found in [API.md](API.md).

The following features are supported:

- List of objects incl. facetted search and fulltext search
- Single object as XML
- Transform a single object with XSLT
- Metadata of an object as JSON
- Search within a list of objects or in a single object and highlight the hits
- Retrieve passages / parts of an object
- Search for relations between objects

*Setup*

To include the ediarum.web backend API add a `appconf.xml` (see [APPCONF.xml](APPCONF.xml)) to your project and include the following lines to your `controller.xql`:

```xquery
import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";

edwebcontroller:init-exist-variables($exist:path, $exist:resource, $exist:controller, $exist:prefix, $exist:root),

(: Always use cached data, even if data are newer than cache. :)
request:set-attribute("cache", "yes"),

(: Include the ediarum.web API :)
edwebcontroller:generate-api(),

(: Other requests than defined are passed through :)
edwebcontroller:pass-through()
```

*Example*

For a more complex example of a `controller.xql` see the [example for `controller.xql`](#example-for-controllerxql)

## Automatic link generation

It is possible to generate links of a `<a>` element with the use of simple constants. Just insert one of the following constants at the beginning of the string in a `href` attribute:

- `$base-url/` is replaced with the app root URL, e.g. `https://example.com/exist/apps/myapp/`
- `$id/` is replaced with the link to the object with this ID, e.g. `https://example.com/exist/apps/myapp/object-type/id`
- `$id-type(VARIABLE)/` is replaced with the link to the first object with the ID of this id-type (property).
- `$edweb/` is replaced with the root URL of the ediarum.WEB app, e.g. `https://example.com/exist/apps/ediarum.WEB/`

*Setup*

To use this feature one has to insert the function `edweb:view-expand-links` to the `view.xql` of your app. E.g.

```xquery
let $content := request:get-data()
let $result := templates:apply($content, $lookup, (), $config)
return
    edweb:view-expand-links($result, ())
```

*Example*

```xml
<a href="$id/object-00001">
```

## Referrer and highlighting

If one follows a link from one object (A) to another (B) all links to object (A) are highlighted.

*Setup*

To work you have to make use `$id` replacement with the [Autmatic link generation](#automatic-link-generation) at the pages of object (A) and (B). Then in the `href` attribute a referrer to object (A) is set, e.g. `?ref=object-a`.

At the page of object (B) to all links with `$id` to object (A) a `<span>` element with the class `referer` is added:

```xml
<a href="link-to-object-a">
    <span class="referer">
        Linktext ...
    </span>
</a>
```

So, to highlight the links you have to use a appropriate css entry or just use the [prefconfigured layout](#preconfigured-layout).


## Preconfigured layout

ediarum.WEB contains a LESS file with predefined CSS instructions. These are match the used elements and classes of the templating functions.

*Setup*

To use the LESS file copy it from `/resources/ediarum.less` to your app and include it in your less file:

```css
@import "ediarum.less"; 
```

Then use a LESS compiler to generate a CSS file.

### Colors and fonts

Preconfigured colors and fonts can be overwritten by your LESS file:

```css
@primary-color: #4ead6f;
@primary-color-dark: #316E47;
@theme-gray: #d0d0d0;
@theme-dark-gray: #4F4D49;
@theme-light-gray: #f3f3f3;
@main-font:  "Frutiger", "Verdana", "Helvetica", "Arial", sans-serif;
@main-font-size: 12pt;
@navigation-font:  "Frutiger", "Verdana", "Helvetica", "Arial", sans-serif;
@navigation-font-size: 10pt;
@footer-font:  "Frutiger", "Verdana", "Helvetica", "Arial", sans-serif;
@footer-font-size: 9pt;
@content-font:  "Frutiger", "Verdana", "Helvetica", "Arial", sans-serif;
@content-font-size: 10pt;
```

## Citation Text Services API (CTS API)

The CTS specification defines different endpoints to retrieve text data for citation purposes. The specification can be found at <https://github.com/cite-architecture/cts_spec>.

ediarum.WEB supports the following CTS requests:

- GetPassage

*Setup:*

1. Include the ediarum.WEB API in your `controller.xql` (see above) and add the following line before `edwebcontroller:generate-api()`:

    ```xquery
    (: The parameter defines the property name to use as cts urn for the objects. :)
    edwebcontroller:include-cts("cts")
    ```

2. Define in the `appconf.xml` an object property (in the example defined as `cts`, see also [APPCONF.md](APPCONF.md)) which will be used as CTS URN:

    ```xml
    <filter xml:id="cts">
        <name>CTS-URNs</name>
        <type>id</type>
        <xpath>.//tei:text/tei:body/tei:div[@type='translation'or @type='edition' or @type='transcription']/@n/string()</xpath>
        <label-function type="xquery">
            function($string) { $string }
        </label-function>
    </filter>
    ```

    *Important: The object property must be a valid CTS URN of the form `urn:cts:<namespace>:<textgroup>.<work>.<version>`.*

3. Add a definition for object parts in the `appconf.xml` (see [APPCONF.md](APPCONF.md)):

    ```xml
    <parts separator="." prefix="-">
        <part xml:id="book" starts-with="b">
            <root>tei:div[@subtype='book'][parent::tei:div/@type=('edition','translation')]</root>
            <id>@n</id>
            <part xml:id="book-chapter">
                <root>tei:div[@subtype='chapter']</root>
                <id>@n</id>
            </part>
        </part>
    </part>
    ```

*Example:*

A request `/api/cts?request=GetPassage&urn=urn:cts:my-ns:author001.text01.version01:b-1.1` returns:

```xml
<cts:GetPassage xmlns:cts="http://chs.harvard.edu/xmlns/cts/">
  <cts:request>
    <cts:info>Data received via CTS-API of ediarum.WEB at http://localhost:8080/exist/apps/my-project/api/cts</cts:info>
  </cts:request>
  <cts:reply>
    <cts:urn>urn:cts:my-ns:author001.text01.version01:chapter1</cts:urn>
    <cts:passage>
      <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:space="preserve" xml:lang="en">
        <text>
          <body>
            <div type="edition" xml:lang="grc" n="author001.text01.version01">
              <div type="textpart" subtype="book" n="1">
                <div type="textpart" subtype="chapter" n="1">
                  <p>
                    <seg n="1">Some text.</seg>
                    <seg n="2">More text.</seg>
                  </p>
                </div>
              </div>
            </div>
          </body>
        </text>
      </TEI>
    </cts:passage>
  </cts:reply>
</cts:GetPassage>
```

## Example for `controller.xql`

An example for an entire `controller.xql` is:

```xquery
xquery version "3.0";

import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

edwebcontroller:init-exist-variables($exist:path, $exist:resource, $exist:controller, $exist:prefix, $exist:root),

(: Always use cached data, even if data are newer than cache. :)
request:set-attribute("cache", "yes"),

(: Redirect to home page :)
edwebcontroller:redirect("/", "index.html"),

(: Home page :)
edwebcontroller:generate-path("/", "static-pages/index.html"),

(: Letters :)
edwebcontroller:view-with-feed("/letters/index.html", "data-pages/letters.html", "object-type/letters"),
edwebcontroller:view-with-feed("/letters/", "data-pages/letters_details.html", "object-type/letters/id/"),

(: Persons :)
edwebcontroller:view-with-feed("/persons/index.html","data-pages/persons.html", "object-type/persons"),
edwebcontroller:view-with-feed("/persons/", "data-pages/persons_details.html", "object-type/persons/id/"),

(: Home page :)
edwebcontroller:generate-path("/index.html", "static-pages/index.html"),

(: Include CTS API :)
edwebcontroller:include-cts-api("cts"),

(: Include the ediarum.web API :)
edwebcontroller:generate-api(),

(: Other requests than defined are passed through :)
edwebcontroller:pass-through()
```
