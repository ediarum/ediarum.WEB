# Features

- [Features](#features)
  - [Automatic link generation](#automatic-link-generation)
  - [Referrer and highlighting](#referrer-and-highlighting)
  - [Preconfigured layout](#preconfigured-layout)
    - [Colors and fonts](#colors-and-fonts)

## Automatic link generation

It is possible to generate links of a `<a>` element with the use of simple constants. Just insert one of the following constants at the beginning of the string in a `href` attribute:

- `$base-url/` is replaced with the app root URL, e.g. `https://example.com/exist/apps/myapp/`
- `$id/` is replaced with the link to the object with this ID, e.g. `https://example.com/exist/apps/myapp/object-type/id`
- `$edweb/` is replaced with the root URL of the ediarum.WEB app, e.g. `https://example.com/exist/apps/ediarum.WEB/`

*Setup*

To use this feature one has to insert the function `edweb:view-expand-links` to the `view.xql` of your app. E.g.

```
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