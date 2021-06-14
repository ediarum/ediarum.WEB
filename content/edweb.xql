xquery version "3.1";

(:~
 : The generalized functions for generating the content of ediarum.web.
 :)
module namespace edweb="http://www.bbaw.de/telota/software/ediarum/web/lib";

import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace http="http://expath.org/ns/http-client";

declare variable $edweb:controller := "/ediarum.web";
declare variable $edweb:projects-collection := "/db/projects";
(: See also $edwebapi:param-separator. :)
declare variable $edweb:param-separator := ";"; 
declare variable $edweb:view-uri-label-separator := ":l:"; 
declare variable $edweb:view-view-separator := "::v::"; 

declare function functx:get-matches-and-non-matches($string as xs:string?, $regex as xs:string) as element()* { let $iomf := functx:index-of-match-first($string, $regex) return if (empty($iomf)) then <non-match>{$string}</non-match> else if ($iomf > 1) then (<non-match>{substring($string,1,$iomf - 1)}</non-match>, functx:get-matches-and-non-matches( substring($string,$iomf),$regex)) else let $length := string-length($string) - string-length(functx:replace-first($string, $regex,'')) return (<match>{substring($string,1,$length)}</match>, if (string-length($string) > $length) then functx:get-matches-and-non-matches(substring($string,$length + 1),$regex) else ()) };
declare function functx:index-of-match-first($arg as xs:string?, $pattern as xs:string) as xs:integer? { if (matches($arg,$pattern)) then string-length(tokenize($arg, $pattern)[1]) + 1 else () };
declare function functx:pad-integer-to-length($integerToPad as xs:anyAtomicType?, $length as xs:integer) as xs:string { if ($length < string-length(string($integerToPad))) then error(xs:QName('functx:Integer_Longer_Than_Length')) else concat (functx:repeat-string( '0',$length - string-length(string($integerToPad))), string($integerToPad)) };
declare function functx:replace-first($arg as xs:string?, $pattern as xs:string, $replacement as xs:string) as xs:string { replace($arg, concat('(^.*?)', $pattern), concat('$1',$replacement)) };
declare function functx:repeat-string($stringToRepeat as xs:string?, $count as xs:integer) as xs:string { string-join((for $i in 1 to $count return $stringToRepeat), '')};
declare function functx:atomic-type( $values as xs:anyAtomicType* )  as xs:string* { for $val in $values return (if ($val instance of xs:untypedAtomic) then 'xs:untypedAtomic' else if ($val instance of xs:anyURI) then 'xs:anyURI' else if ($val instance of xs:ENTITY) then 'xs:ENTITY' else if ($val instance of xs:ID) then 'xs:ID' else if ($val instance of xs:NMTOKEN) then 'xs:NMTOKEN' else if ($val instance of xs:language) then 'xs:language' else if ($val instance of xs:NCName) then 'xs:NCName' else if ($val instance of xs:Name) then 'xs:Name' else if ($val instance of xs:token) then 'xs:token' else if ($val instance of xs:normalizedString) then 'xs:normalizedString' else if ($val instance of xs:string) then 'xs:string' else if ($val instance of xs:QName) then 'xs:QName' else if ($val instance of xs:boolean) then 'xs:boolean' else if ($val instance of xs:base64Binary) then 'xs:base64Binary' else if ($val instance of xs:hexBinary) then 'xs:hexBinary' else if ($val instance of xs:byte) then 'xs:byte' else if ($val instance of xs:short) then 'xs:short' else if ($val instance of xs:int) then 'xs:int' else if ($val instance of xs:long) then 'xs:long' else if ($val instance of xs:unsignedByte) then 'xs:unsignedByte' else if ($val instance of xs:unsignedShort) then 'xs:unsignedShort' else if ($val instance of xs:unsignedInt) then 'xs:unsignedInt' else if ($val instance of xs:unsignedLong) then 'xs:unsignedLong' else if ($val instance of xs:positiveInteger) then 'xs:positiveInteger' else if ($val instance of xs:nonNegativeInteger) then 'xs:nonNegativeInteger' else if ($val instance of xs:negativeInteger) then 'xs:negativeInteger' else if ($val instance of xs:nonPositiveInteger) then 'xs:nonPositiveInteger' else if ($val instance of xs:integer) then 'xs:integer' else if ($val instance of xs:decimal) then 'xs:decimal' else if ($val instance of xs:float) then 'xs:float' else if ($val instance of xs:double) then 'xs:double' else if ($val instance of xs:date) then 'xs:date' else if ($val instance of xs:time) then 'xs:time' else if ($val instance of xs:dateTime) then 'xs:dateTime' else if ($val instance of xs:dayTimeDuration) then 'xs:dayTimeDuration' else if ($val instance of xs:yearMonthDuration) then 'xs:yearMonthDuration' else if ($val instance of xs:duration) then 'xs:duration' else if ($val instance of xs:gMonth) then 'xs:gMonth' else if ($val instance of xs:gYear) then 'xs:gYear' else if ($val instance of xs:gYearMonth) then 'xs:gYearMonth' else if ($val instance of xs:gDay) then 'xs:gDay' else if ($val instance of xs:gMonthDay) then 'xs:gMonthDay' else 'unknown')};
declare %test:args("abc123def", "\d") %test:assertEquals("1", "2", "3") function functx:get-matches ($string as xs:string?, $regex as xs:string) as xs:string* { functx:get-matches-and-non-matches($string,$regex)/self::match/string() };
declare function functx:escape-for-regex ($arg as xs:string?) as xs:string { replace($arg, '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1') };

(: ADD funcctions returning complete html nodes :)

(:~ 
 : Loads the default assets from edweb.
 :
 : @return a list of <script> and <link> elements for the html header.
 :)
declare function edweb:add-assets(
    $node as node(), 
    $model as map(*)
) as element()* 
{
    let $styles := 
        (
            "reset/reset.css",
            "bootstrap/bootstrap.min.css",
            "uitotop/ui.totop.css",
            "font-awesome/font-awesome.min.css"
        )
    for $css in $styles
    return <link xmlns="http://www.w3.org/1999/xhtml" rel="stylesheet" type="text/css" href="$edweb/assets/{$css}"/>
    ,
    let $scripts := 
        (
            "jquery/jquery-1.11.3.min.js",
            "jquery/jquery-ui-1.10.3.custom.js",
            "prettify/prettify.js",
            "uitotop/jquery.ui.totop.js",
            "bootstrap/bootstrap.min.js"
        )
    for $js in $scripts
    return <script xmlns="http://www.w3.org/1999/xhtml" src="$edweb/assets/{$js}" type="text/javascript">&#160;</script>
};

(:~
 :
 :)
declare function edweb:add-breadcrumb-items(
    $node as node(), 
    $model as map(*), 
    $filter as xs:string?
) 
{
    let $object-type := request:get-attribute("object-type")
    let $object-id := $model?id
    
    let $object-type-label := $model?object-type-label

    let $filters := $model?filters?*?id
    let $filter := 
        if (empty($filter))
        then string-join($filters, " ")
        else $filter
    
    let $breadcrumb-items := 
        for $f in tokenize($filter, " ")
        let $filter-values := $model?all[?id = $object-id]?filter?($f)

        let $filter-depends := normalize-space(substring-before($filter, $f))

        let $other-filter := 
            for $f in tokenize($filter-depends, " ")
            let $filter-value := $model?all[?id = $object-id]?filter?($f)
            let $filter-value := 
                if ($filter-value instance of array(*)) 
                then $filter-value?*[1]
                else $filter-value
            return $f||"="||$filter-value
        let $filter-value := 
            if ($filter-values instance of array(*)) 
            then
                    $filter-values?*[1]
            else $filter-values
        let $href := string-join(($other-filter, $f||"="||$filter-value), "&amp;")
        return
            if ($filter-value) 
            then
                    <li class="breadcrumb-item">
                        <a href="$base-url/{$object-type}/index.html?{$href}">{$filter-value}</a>
                    </li>
            else ()

    let $c := console:log("loading", $model?all)
    return
        <ol class="p-0 m-0 mr-auto breadcrumb">
            <li class="breadcrumb-item">
                <a href="$base-url/{$object-type}/index.html">{$object-type-label}</a>
            </li>
            { $breadcrumb-items }
        </ol>
};

(:~
 : Shows debug informations like the current $model, the request attributes and parameters.
 :
 : @param $node the current node
 : @param $model the current model
 : @return a html table with the supplied information.
 :)
declare function edweb:add-debug-information(
    $node as node(),
    $model as map(*)
) as node() 
{
    <table>
        <tr>
            <td>request-parameters:&#160;</td>
            <td>
                (
                <table>
                {
                    for $p in request:get-parameter-names()
                    return
                        <tr>
                            <td>&#160;&#160;&#160;{$p}:&#160;</td>
                            <td>"{request:get-parameter($p, ())}"</td>
                        </tr>
                }
                </table>
                )
            </td>
        </tr>
        <tr>
            <td>request-attributes:&#160;</td>
            <td>
                (
                <table>
                {
                    for $p in request:attribute-names()
                    return 
                        <tr>
                            <td>&#160;&#160;&#160;{$p}:&#160;</td>
                            <td><pre>{serialize(request:get-attribute($p))}</pre></td>
                        </tr>
                }
                </table>
                )
            </td>
        </tr>
        <tr>
            <td>&#160;$model:&#160;</td>
            <td>{ "{",local:create-table-from-map($model),"}" }</td>
        </tr>
    </table>
};

(:~ 
 : Generates the link option for selecting all elements in the current filter.
 :
 : @return a <a> element with right URL.
 :)
declare function edweb:add-filter-all-link(
    $node as node(), 
    $model as map(*)
) as node() 
{
    let $filter-id := $model("filter")("id")
    let $filters := map:keys($model("filters"))
    let $map := 
        map:merge((
            map:entry($filter-id, ""),
            for $f in $filters
            return
                if (contains(" "||$model("filters")($f)("depends")||" ", " "||$filter-id||" ")) 
                then map:entry($f, "")
                else ()
        ))
    let $href := request:get-uri()||"?"||edweb:params-insert($model("params"),$map)
    return <a href="{$href}" class="visible enabled">Alle</a>
};

(:~ 
 : Generates the link option for model?item
 :
 : @return a <a> element with right URL.
 :)
declare function edweb:add-filter-item-link(
    $node as node(), 
    $model as map(*)
) as node() 
{
    let $href := $model?item?href
    let $enabled := if ($model?item?count-select > 0) then "enabled" else "disabled"
    let $selected := if ($model?item?selected eq "selected") then "current" else ()
    let $count := <span class="count">{$model?item?count-select}</span>
    let $close := 
        if ($model("item")("selected") eq "selected") 
        then <span aria-hidden="true" class="pull-right close">×</span>
        else ()
    return
        <a href="{$href}" class="{$selected} {$enabled}">{$model?item?label} {$count}{$close}</a>
};

(:~ 
 : Generates HTML filter navigation fragments for each possible filter.
 :
 : @param $node the node the current request.
 : @param $model the model of the current request.
 : @return the $node fragment for each filter.
 :)
declare %templates:wrap function edweb:add-filter-nav(
    $node as node(), 
    $model as map(*)
) as node()* 
{
    let $filters := map:keys($model?filter)
    for $filter in $filters
    let $div :=
        <div class="box graybox filter" data-template="edweb:load-filter" data-template-filter-name="{$filter}">
            {$node/*}
        </div>
    order by $model?filter?($filter)?n
    return
        templates:process($div, $model)
};

(:~
 :
 :)
declare function edweb:add-link-to-prev-object(
    $node as node(), 
    $model as map(*)
) 
{
    let $labelled-ids := $model?labelled[?label-pos=1]?id
    let $object-type := $model?object-type
    let $position := index-of( $labelled-ids, $model?id )
    return
        if ($labelled-ids[$position -1]) 
        then <a href="$base-url/{$object-type}/{$labelled-ids[$position -1]}" class="nav-link"><i class="fa fa-arrow-left"></i></a>
        else ()
};

(:~
 :
 :)
declare function edweb:add-link-to-next-object(
    $node as node(), 
    $model as map(*)
) 
{
    let $labelled-ids := $model?labelled[?label-pos=1]?id
    let $object-type := $model?object-type
    let $position := index-of( $labelled-ids, $model?id )
    return
        if ($labelled-ids[$position +1]) 
        then <a href="$base-url/{$object-type}/{$labelled-ids[$position +1]}" class="nav-link"><i class="fa fa-arrow-right"></i></a>
        else ()
};

(:~
 :
 :)
declare function edweb:add-main-nav(
    $node as node(),
    $model as map(*)
) as node()*
{
    let $object-types := edwebcontroller:api-get("/api")//appconf:object
    return
        for $object-type in $object-types
        let $id := $object-type/@xml:id/string()
        let $name := $object-type/appconf:name/string()
        return
            <li class="nav-item">
                <a class="nav-link" href="$base-url/{$id}/index.html">{$name}</a>
            </li>
};

(:~ 
 : Generates a pagination navigation.
 :
 : @from the key of model map which contains a list of items to add pagination
 : @return the list of pages
 :)
declare %templates:wrap function edweb:add-pagination-nav(
    $node as node(), 
    $model as map(*), 
    $from as xs:string
) as node() 
{
    let $count := count($model($from))
    let $page-size := number(edweb:params-get-page-size())
    let $number-of-pages := xs:integer(ceiling($count div $page-size))
    let $pages := (1 to $number-of-pages)
    let $active-page := number(edweb:params-get-page())
    let $previous-page :=
        if ($active-page - 1 < 1) 
        then 1
        else $active-page - 1
    let $next-page :=
        if ($active-page + 1 > $number-of-pages) 
        then $active-page
        else $active-page + 1
    let $previous-10-page :=
        if ($active-page - 10 < 1) 
        then 1
        else $active-page - 10
    let $next-10-page :=
        if ($active-page + 10 > $number-of-pages) 
        then $number-of-pages
        else $active-page + 10
    let $prev-navigation :=
        if ($active-page > 1) 
        then (
            <li class="page-item">
                <a class="page-link" 
                   href="?{edweb:params-insert($model("params"))}&amp;p={$previous-10-page}" 
                   aria-label="Previous">
                    <span aria-hidden="true">«</span>
                    <span class="sr-only">First</span>
                </a>
            </li>,
            <li class="page-item">
                <a class="page-link" 
                   href="?{edweb:params-insert($model("params"))}&amp;p={$previous-page}" 
                   aria-label="Previous">
                    <span aria-hidden="true">‹</span>
                    <span class="sr-only">Previous</span>
                </a>
            </li>
        )
        else (
            <li class="page-item disabled">
                <span class="page-link">
                    <span aria-hidden="true">«</span>
                    <span class="sr-only">First</span>
                </span>
            </li>,
            <li class="page-item disabled">
                <span class="page-link">
                    <span aria-hidden="true">‹</span>
                    <span class="sr-only">Previous</span>
                </span>
            </li>
        )
    let $next-navigation :=
        if ($active-page < $number-of-pages) 
        then (
            <li class="page-item">
                <a class="page-link" 
                   href="?{edweb:params-insert($model("params"))}&amp;p={$next-page}" 
                   aria-label="Next">
                    <span aria-hidden="true">›</span>
                    <span class="sr-only">Next</span>
                </a>
            </li>,
            <li class="page-item">
                <a class="page-link" 
                   href="?{edweb:params-insert($model("params"))}&amp;p={$next-10-page}" 
                   aria-label="Next">
                    <span aria-hidden="true">»</span>
                    <span class="sr-only">Last</span>
                </a>
            </li>
        )
        else (
            <li class="page-item disabled">
                <span class="page-link">
                    <span aria-hidden="true">›</span>
                    <span class="sr-only">Next</span>
                </span>
            </li>,
            <li class="page-item disabled">
                <span class="page-link">
                    <span aria-hidden="true">»</span>
                    <span class="sr-only">Last</span>
                </span>
            </li>
        )
    let $list-of-pages :=
        for $page at $pos in $pages
        return
            if ($page eq $active-page) 
            then
                <li class="page-item active">
                    <a class="page-link" 
                       href="?{edweb:params-insert($model("params"))}&amp;p={$page}"
                       >{$page} <span class="sr-only">(current)</span></a>
                </li>
            else if ($pos = (1, 2, 3, $active-page -2, $active-page -1, $active-page +1, 
                $active-page +2, $number-of-pages -2, $number-of-pages -1, $number-of-pages)) 
            then
                <li class="page-item">
                    <a class="page-link" 
                       href="?{edweb:params-insert($model("params"))}&amp;p={$page}"
                       >{$page}</a>
                </li>
            else if ($pos = ($active-page -3)) 
            then
                <li class="page-item disabled"
                    ><span class="page-link cursor-default">...</span></li>
            else if ($pos = ($active-page +3)) 
            then
                <li class="page-item disabled"
                    ><span class="page-link cursor-default">...</span></li>
            else ()
    let $navigation :=
        <nav aria-label="Page navigation">
            <ul class="pagination justify-content-center"> { 
                $prev-navigation,
                $list-of-pages,
                $next-navigation 
            } </ul>
        </nav>
    return $navigation
};

(:~
 : Generates a list with links to different views of the current object.
 :
 : @param $node the node of the current request.
 : @param $model the model of the current request.
 : @return a <ul> list.
 :)
declare  %templates:wrap function edweb:add-view-list(
    $node as node(), 
    $model as map(*)
) as node()* 
{
    let $views := local:get-object-views($model)
    let $selected := request:get-uri()
    return edweb:add-view-list($node, $model, $views, $selected)
};

(:~
 : Generates a list with links to different views.
 :
 : @param $node the node of the current request.
 : @param $model the model of the current request.
 : @param $views a string which contains the urls and labels of the views in the form "url-1:label-1::url-2:label-2".
 : @param $selected the url of the current view.
 : @return a <ul> list.
 :)
declare %templates:wrap function edweb:add-view-list(
    $node as node(), 
    $model as map(*), 
    $views as xs:string, 
    $selected as xs:string
) as node()* 
{
    let $view-array := tokenize($views, $edweb:view-view-separator)
    let $view-list :=
        for $view in $view-array
        let $url := substring-before($view, $edweb:view-uri-label-separator)
        let $label := substring-after($view, $edweb:view-uri-label-separator)
        let $is-active := 
            if ($url = $selected) 
            then "active"
            else ()
        let $is-selected := 
            if ($url = $selected) 
            then "selected"
            else ()
        let $list-item :=
            <li class="navbar-item {$is-active} mr-4">
                <a class="navbar-link {$is-selected}" href="{$url}">{$label}</a>
            </li>
        return $list-item
    let $class := $node/@class/string()
    return <ul class="{$class}">{ $view-list }</ul>
};

(:~ 
 : Generates a navbar with links to different views configured in the appconf.
 :
 : @param $node the node of the current request.
 : @param $model the model of the current request.
 : @return a bootstrap navbar.
 :)
declare function edweb:add-view-nav(
    $node as node(), 
    $model as map(*)
) as node()* 
{
    let $view-list := edweb:add-view-list(<ul class="navbar-nav"></ul>, $model)
    return
        <nav id="view-nav" class="navbar navbar-expand-sm py-0 navbar-dark">
            <button type="button" class="navbar-toggler" data-toggle="collapse" data-target="#view-navbar" aria-expanded="false">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="view-navbar">
                {$view-list}
            </div>
        </nav>
};

(:~ 
 : Generates a navbar with links to different views.
 :
 : @param $node the node of the current request.
 : @param $model the model of the current request.
 : @param $views a string which contains the urls and labels of the views in the form "url-1:label-1::url-2:label-2".
 : @param $selected the url of the current view.
 : @return a bootstrap navbar.
 :)
declare function edweb:add-view-nav(
    $node as node(), 
    $model as map(*), 
    $views as xs:string, 
    $selected as xs:string
) as node()* 
{
    let $view-list := edweb:add-view-list(<ul class="navbar-nav"></ul>, $model, $views, $selected)
    return
        <nav id="view-nav" class="navbar navbar-expand-sm py-0 navbar-dark">
            <button type="button" class="navbar-toggler" data-toggle="collapse" data-target="#view-navbar" aria-expanded="false">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="view-navbar">
                {$view-list}
            </div>
        </nav>
};

(: INSERT functions returning strings :)

(:~
 :
 :)
declare function edweb:insert-count(
    $node as node(), 
    $model as map(*), 
    $from as xs:string
) as xs:string 
{
    string(count($model?($from)))
};

(:~
 :
 :)
declare function edweb:insert-string(
    $node as node(), 
    $model as map(*), 
    $path as xs:string
) as xs:string? 
{
    local:template-get-string($model, $path)
};

(:~
 :
 :)
declare function edweb:insert-xml-string(
    $node as node(), 
    $model as map(*), 
    $path as xs:string
) 
{
    let $xml := edweb:insert-string($node, $model, $path)
    return
        if (starts-with($xml,'<'))
        then
            try {
                parse-xml($xml)
            }
            catch * {
                $xml
            }
        else $xml
};


declare function local:template-get-string(
    $model as map(*), 
    $path as xs:string
) as xs:string? 
{ 
    if (contains($path, "?")) 
    then
        let $model := $model?(substring-before($path, "?"))
        let $path := substring-after($path, "?")
        return
            if ($model instance of array(*))
            then local:template-get-string-from-array($model, $path)            
            else local:template-get-string($model, $path)
    else $model?($path)||""
};

declare function local:template-get-string-from-array(
    $model as array(*), 
    $path as xs:string
) as xs:string? 
{
    if (contains($path, "?")) 
    then
        let $model := $model?(xs:int(substring-before($path, "?")))
        let $path := substring-after($path, "?")
        return
            if ($model instance of array(*))
            then local:template-get-string-from-array($model, $path)            
            else local:template-get-string($model, $path)
    else $model?(xs:int($path))||""
};

(: LOAD functions are loading data from the API and storing into the $model map. :)

(:~
 :
 :)
declare %templates:wrap function edweb:load(
    $node as node(), 
    $model as map(*), 
    $key as xs:string, 
    $path as xs:string
) as map(*) 
{
    let $items := edwebcontroller:api-get($path)
    let $add-map := map:entry($key, $items)
    return
        map:merge(($model, $add-map))
};

(:~
 : Loads an object with the current id and object-type.
 :
 : @param $node the node of the current request.
 : @param $model the current model of the request.
 : @return a map of the model incl. the current object.
 :)
declare %templates:wrap function edweb:load-current-object(
    $node as node(), 
    $model as map(*)
) as map(*) 
{
    let $object-type := request:get-attribute("object-type")
    let $object-id :=
        if (request:get-attribute("find")||"" != "")
        then
            let $id-type := request:get-attribute("find")
            let $find-id := request:get-attribute("id")
            let $object := edwebcontroller:api-get("/api/"||$object-type||"?show=list&amp;"||$id-type||"="||$find-id)
            return  $object?id
        else
            request:get-attribute("id")
    let $map := edwebcontroller:api-get("/api/"||$object-type||"/"||$object-id)
    let $current-doc := 
        map:entry( 
            "current-doc",
            edwebcontroller:api-get("/api/"||$object-type||"/"||$object-id||"?output=xml")
        )
    (: TODO: Remove this. The following line must be present! Otherwise there exists an error: "element(<xml>...</xml>) is not a subtype of map"! :)
(:    let $c := console:log("loading", $current-doc):)
(:    let $model := edweb:load-project($node, $model):)
    return
        map:merge(($model, $map, $current-doc))
};

(:~
 :
 :)
declare %templates:wrap function edweb:load-filter(
    $node as node(), 
    $model as map(*), 
    $filter-name as xs:string
) as map(*) 
{
    let $object-type := request:get-attribute("object-type")
    let $map-entries :=
        for $filter in $model?("filters")?*
        return
            if (contains(" "||$filter("depends")||" ", " "||$filter-name||" ")) 
            then map:entry($filter?("id"), "")
            else ()
    let $map := edwebcontroller:api-get("/api/"||$object-type)
    let $labels := 
        for $l in distinct-values($model?("all")?("filter")?($filter-name))[. != '']
        let $this-label := $l
        let $add-label := 
            string-join(
                distinct-values((
                    tokenize($model("params")($filter-name), $edweb:param-separator),
                    $l
                )), 
                $edweb:param-separator
            )
        let $remove-label := 
            string-join(
                distinct-values(
                    tokenize($model("params")($filter-name), $edweb:param-separator)[not(.=$l)]
                ), 
                $edweb:param-separator
            )
        let $selected :=
            if ($this-label = tokenize($model?params?($filter-name), $edweb:param-separator)) 
            then "selected"
            else ""
        let $filter-params :=
            let $type := $model?filters?($filter-name)?type 
            return
                if ($type eq "single" or $type eq "greater-than" or $type eq "lower-than") 
                then 
                    edweb:params-insert(
                        $model("params"),
                        map:merge((
                            map:entry($filter-name, $this-label), 
                            $map-entries
                        ))
                    )
                else if ($selected) 
                then
                    edweb:params-insert(
                        $model("params"),
                        map:merge((
                            map:entry($filter-name, $remove-label),
                            $map-entries
                        ))
                    )
                else
                    edweb:params-insert(
                        $model("params"),
                        map:merge((
                            map:entry($filter-name, $add-label),
                            $map-entries
                        ))
                    )
        let $filter-select-items :=
            let $params := edweb:params-load-from-string($filter-params)
            return local:filter-list($map?list?*, $map?filter, $params)
        let $count-select := 
            if (exists($filter-select-items)) 
            then count($filter-select-items) 
            else 0
        order by $l 
        return
            map:merge((
                map:entry("label", $l),
                map:entry("selected", $selected),
                map:entry("count-select", $count-select),
                map:entry("href", request:get-uri()||"?"||$filter-params)
            ))
    let $add-map := 
        map:merge((
            map:entry("filter", $model?("filters")?($filter-name)),
            map:entry("filter-items", ($labels))
        ))
    return map:merge(($model, $add-map))
};

(:~
 : see edwebapi:filter-list
 :)
declare function local:filter-list(
    $list as map(*)*, 
    $filters as map(*), 
    $params as map(*)
) as map(*)* 
{
    if (count(map:keys($filters)) > 0) then
        let $filter := $filters?*[1]
        let $filter-id := $filter?id
        let $filter-values := tokenize($params?($filter-id), $edweb:param-separator)
        let $filter-expression :=
            if (empty($filter-values)) 
            then function($list as map(*)*) { $list}
            else
                switch($filter?type)
                case "single" 
                return function($list as map(*)*) { $list[?filter?($filter-id) = $filter-values] }
                case "union" 
                return function($list as map(*)*) { $list[?filter?($filter-id) = $filter-values] }
                case "intersect" 
                return
                    function($list as map(*)*) {
                        for $item in $list 
                        let $item-filter-values := $item?filter?($filter-id)
                        let $filters-are-true := 
                            for $fv in $filter-values 
                            return ($fv = $item-filter-values) 
                        return
                            if (not( false() = ($filters-are-true) )) 
                            then $item
                            else ()
                    }
                case "greater-than" 
                return function($list as map(*)*) { $list[?filter?($filter-id) >= $filter-values] }
                case "lower-than" 
                return function($list as map(*)*) { $list[?filter?($filter-id) <= $filter-values] }
                default 
                return function($list as map(*)*) { () }
        let $filtered-list := $filter-expression($list)
        let $other-filter := map:remove($filters, $filter-id)
        return
            if (count(map:keys($other-filter)) > 0) 
            then local:filter-list($filtered-list, $other-filter, $params)
            else $filtered-list
    else $list
};

(:~
 :
 :)
declare %templates:wrap function edweb:load-inner-navigation(
    $node as node(), 
    $model as map(*), 
    $inner-navigation-name as xs:string
) as map(*) 
{
    let $inner-nav := $model?inner-nav?($inner-navigation-name)
    let $add-map := 
        map:merge((
            map:entry("inner-navigation-id", $inner-navigation-name),
            map:entry("inner-navigation-name", $inner-nav?name),
            map:entry("inner-navigation-items", $inner-nav?list?*)
        ))
    return map:merge(($model, $add-map))
};

(:~
 :
 :)
declare %templates:wrap function edweb:load-objects(
    $node as node(), 
    $model as map(*)
) as map(*) 
{
    let $object-type := request:get-attribute("object-type")
    let $object-type-label := 
        edwebcontroller:api-get("/api")//appconf:object[@xml:id=$object-type]/appconf:name
    let $all-objects := edwebcontroller:api-get("/api/"||$object-type||"?show=all")
    let $c := console:log("loading", count($all-objects))
    let $labelled-objects := edwebcontroller:api-get("/api/"||$object-type||"?show=all&amp;order=label")
    let $c := console:log("loading", count($labelled-objects))
    let $filters := edwebcontroller:api-get("/api/"||$object-type||"?show=filter")
    let $filter-params := edweb:params-load((map:keys($filters)))
    let $filtered-objects := 
        edwebcontroller:api-get(
            "/api/"||$object-type||"?show=list&amp;order=label&amp;"
            ||edweb:params-insert($filter-params)
        )
    let $c := console:log("loading", count($filtered-objects))
    let $show-objects := 
        edwebcontroller:api-get(
            "/api/"||$object-type||"?show=list&amp;order=label&amp;page="||edweb:params-get-page()
            ||"&amp;range="||edweb:params-get-page-size()||"&amp;"||edweb:params-insert($filter-params)
        )
    let $c := console:log("loading", count($show-objects))
    let $add-map := 
        map:merge((
            map:entry("object-type", $object-type),
            map:entry("object-type-label", $object-type-label),
            map:entry("all", $all-objects),
            map:entry("labelled", $labelled-objects),
            map:entry("filtered", $filtered-objects),
            map:entry("show", $show-objects),
            map:entry("filters", $filters),
            map:entry("params", $filter-params)
        ))
    let $model := edweb:load-project($node, $model)
    return
        map:merge(($model, $add-map))
};

(:~
 :
 :)
declare function edweb:load-project(
    $node as node(),
    $model as map(*)
) as map(*) 
{
    let $appconf := edwebcontroller:api-get("/api")
    let $project-status := $appconf//appconf:project/appconf:status/string()
    let $project-name := $appconf//appconf:project/appconf:name/string()
    let $project-map :=
        map:entry("project",
            map:merge((
                map:entry("status", $project-status),
                map:entry("name", $project-name)
            ))
        )
    return map:merge(($model, $project-map))
};

(:~
 : Loads all relations from API for current item as subject. The relations can
 : be accessed in the model by using the "relations" key.
 :
 : @param $node the current node
 : @param $model the current model
 : @param $relation the name of the relation (relation API endpoint)
 : @return the updated model
 :)
declare function edweb:load-relations-for-subject(
    $node as node(), 
    $model as map(*), 
    $relation as xs:string
) as map(*) 
{
    (: let $cons := console:log("test") :)
    let $id := request:get-attribute("id")
    let $relations-map := edwebcontroller:api-get("/api/"||$relation)
    let $object-list := edwebcontroller:api-get("/api/"||$relations-map("object-type"))
    let $relations := $relations-map?list?*[?subject = $id]
    let $items := 
        for $r in $relations
        let $object-id := $r?object
        let $object-map := $object-list?list?($object-id)
        order by $object-map?label
        return 
            map:merge((
                $object-map,
                map:entry("predicate", $r?predicate)
            ))
    let $add-map := map:entry("relations", $items)
    return map:merge(($add-map, $model))
};

(:~
 : Loads all relations from API for current item as object. The relations can
 : be accessed in the model by using the "relations" key.
 :
 : @param $node the current node
 : @param $model the current model
 : @param $relation the name of the relation (relation API endpoint)
 : @return the updated model
 :)
declare function edweb:load-relations-for-object(
    $node as node(),
    $model as map(*),
    $relation as xs:string
) as map(*)
{
    let $id := request:get-attribute("id")
    let $relations-map := edwebcontroller:api-get("/api/"||$relation)
    let $subject-list := edwebcontroller:api-get("/api/"||$relations-map("subject-type"))
    let $relations := $relations-map?list?*[?object = $id]
    let $items := 
        for $r in $relations
        let $subject-id := $r?subject
        let $subject-map := $subject-list?list?($subject-id)
        order by $subject-map?label
        return 
            map:merge((
                $subject-map,
                map:entry("predicate", $r?predicate)
            ))
    let $add-map := map:entry("relations", $items)
    return map:merge(($add-map, $model))
};

(:~
 : Loads all relations from the API. The relations can be accessed in the model
 : by using the "relations" key.
 :
 : @param $node the current node
 : @param $model the current model
 : @param $relation the name of the relation (relation API endpoint)
 : @return the updated model
 :)
declare function edweb:load-relations(
    $node as node(),
    $model as map(*),
    $relation as xs:string
) as map(*)
{
    let $subject-relations := edweb:load-relations-for-subject($node, $model, $relation)
    let $object-relations := edweb:load-relations-for-object($node, $model, $relation)
    let $all-relations := 
        if (not(empty($subject-relations?relations)) and not(empty($object-relations?relations)))
        then map:entry("relations", ($subject-relations?relations?*, $object-relations?relations?*))
        else if (not(empty($subject-relations?relations)))
        then $subject-relations
        else if (not(empty($object-relations?relations)))
        then $object-relations
        else ()
    return map:merge(($all-relations, $model))
};

(: VIEW functions used by view.xql :)

(:~ 
 : Expand all links starting with "$edweb" to the edweb collection and with "$base-url" to the 
 : current base-url. Adds internal links to text matches starting with "$id/"
 :
 : @param $node the node which contains expandable links
 : @error-function a function to be executed on @href if $id/ can't retrieve anything
 : @return the node with expanded links
 :)
declare function edweb:view-expand-links(
    $node as node(), 
    $error-function as function(*)?
) as node()
{
    let $link-list := edwebcontroller:api-get("/api?id-type=all")
    let $error-f := 
        if ($error-function instance of function(*)) 
        then $error-function
        else
            function($href) {
                error(
                    xs:QName("edweb:view-expand-links-001"), 
                    "There is no object with id: "||$href
                )
            }
    return local:view-expand-links($node, $link-list, $error-f)
};


(:~
 :
 :)
declare function local:view-expand-links(
    $node as node(), 
    $link-list as map(), 
    $error-function as function(*)
) as node()
{
    if ($node instance of element()) then
        let $href := $node/@href
        let $src := $node/@src
        let $attribute := 
            if ($node/@href)
            then $node/@href
            else $node/@src
        let $expanded :=
            if (starts-with($attribute, "$base-url/")) 
            then     
                substring-before(request:get-uri(), edwebcontroller:get-exist-controller())
                ||edwebcontroller:get-exist-controller()||substring-after($attribute, "$base-url")
            else if (starts-with($attribute, "$edweb/")) 
            then
                substring-before(request:get-uri(), edwebcontroller:get-exist-controller())
                ||$edweb:controller||substring-after($attribute, "$edweb")
            else if (starts-with($attribute, "$id/")) 
            then
                try {
                    let $current-id := request:get-attribute("id")
                    let $set-referer :=
                        if ($current-id||"" != "")
                        then "?ref="||$current-id
                        else ""
                    return
                        substring-before(request:get-uri(), edwebcontroller:get-exist-controller())
                        ||edwebcontroller:get-exist-controller()||"/"
                        ||$link-list?(substring-after($attribute, "$id/"))?object-type
                        ||"/"||substring-after($attribute, "$id/")||$set-referer
                } 
                catch * {
                    $error-function($attribute)
                }
            else $attribute
        return
            if ($node/@href) 
            then
                element { node-name($node) } {
                    attribute href { $expanded },
                    $node/@* except $node/@href, 
                    let $href-id := substring-after($attribute, "$id/") 
                    let $referer := request:get-parameter("ref", request:get-attribute("ref"))
                    return
                    if ($href-id=$referer)
                    then
                        element span {
                            attribute class { "referer" },
                            for $child in $node/node() 
                            return local:view-expand-links($child, $link-list, $error-function)
                        }
                    else
                        for $child in $node/node() 
                        return local:view-expand-links($child, $link-list, $error-function)
                }
            else if ($node/@src)
            then
                element { node-name($node) } {
                    attribute src { $expanded },
                    $node/@* except $node/@src, 
                    for $child in $node/node() 
                    return local:view-expand-links($child, $link-list, $error-function)
                }
            else
                element { node-name($node) } {
                    $node/@*, 
                    for $child in $node/node() 
                    return local:view-expand-links($child, $link-list, $error-function)
                }
    else if ($node instance of text()) 
    then $node
    else $node
};

(: PARAMS functions handling parameters for get requests :)

(:~
 : Reads the current page from the request parameter 'p'. Default is 1.
 :
 : @return the number of the page.
 :)
declare function edweb:params-get-page(
) as xs:integer
{
    request:get-parameter("p", "1")
};

(:~ 
 : Reads the number of objects per page from the request parameter 'ps'. Default is 20.
 :
 : @return the number of objects per page.
 :)
declare function edweb:params-get-page-size(
) as xs:integer 
{
    request:get-parameter("ps", "50")
};

(:~
 : Returns a string with the parameters for use in URI.
 :
 : @param $params a map containing the current parameters.
 :)
declare function edweb:params-insert(
    $params as map()
) as xs:string 
{
    let $param-names := map:keys($params)
    return
        string-join(
            for $param in $param-names
            let $value := map:get($params, $param)
            return
                if ($value != "") 
                then $param||"="||$value
                else ()
            ,
            "&amp;"
        )
};

(:~
 : Returns a string with the parameters for use in URI.
 :
 : @param $params a map containing the current parameters.
 : @param $new-params a map with new parameter values.
 :)
declare function edweb:params-insert(
    $params as map(), 
    $new-params as map()
) as xs:string 
{
    let $param-names := map:keys($params)
    return
        string-join(
            for $param in $param-names
            let $value :=
                if (exists(map:get($new-params, $param))) 
                then map:get($new-params, $param)
                else map:get($params, $param)
            return
                if ($value != "") 
                then $param||"="||$value
                else ()
            ,
            "&amp;"
        )
};

(:~
 : Reads the parameters of the request to a map.
 :
 : @param $param-names a list of parameters.
 : @return a map with parameter names as keys and the content as values.
 :)
declare function edweb:params-load(
    $param-names as xs:string*
) as map() 
{
    map:merge(
        for $p in $param-names
        return map:entry($p, request:get-parameter($p, ""))
    )
};

(:~
 : Reads the parameters of a string to a map.
 :
 : @param $params the string of params like "from=4&to=10".
 : @return a map with parameter names as keys and the content as values.
 :)
declare function edweb:params-load-from-string(
    $params as xs:string*
) as map() 
{
    map:merge(
        for $p in tokenize($params, "&amp;")
        let $key := substring-before($p, "=")
        let $value := substring-after($p, "=")
        return map:entry($key, $value)
    )
};

(: TEMPLATE functions returning nodes to be processed  :)

(:~
 :
 :)
declare function edweb:template-add-string-to-href(
    $node as node(), 
    $model as map(*)
) as node() 
{
    let $regex := "\$\{(.*?)\}"
    let $href := 
        string-join(
            (
                for $part at $pos in 
                    functx:get-matches-and-non-matches($node/@href/string(), $regex)
                return 
                    if ($part/self::non-match) 
                    then $part/string()
                    else if ($part/self::match) 
                    then
                        let $key := replace($part, $regex, "$1")
                        return local:template-get-string($model, $key)
                else ()
        	),
            ""
        )
    return
        element { node-name($node) } {
            attribute href { $href }
            ,
            $node/@*[not(starts-with(name(), 'data-template'))] except $node/@href
            ,
            for $child in $node/node() 
            return templates:process($child, $model)
        }
};

(:~
 :
 :)
declare function edweb:template-add-xpath-to-href(
    $node as node(), 
    $model as map(*)
) as node() 
{
    let $xml := $model?current-doc
    let $regex := "\$\{(.*?)\}"
    let $href := 
        string-join(
            (
                for $part at $pos in 
                    functx:get-matches-and-non-matches($node/@href/string(), $regex)
                return 
                    if ($part/self::non-match) 
                    then $part/string()
                    else if ($part/self::match) 
                    then
                        let $key := replace($part, $regex, "$1")
                        return util:eval-inline($xml, $key)
                    else ()
    	    )
            , 
            ""
        )
    return
        element { node-name($node) } {
            attribute href { $href }
            ,
            $node/@*[not(starts-with(name(), 'data-template'))] except $node/@href
            ,
            for $child in $node/node() 
            return templates:process($child, $model)
        }
};

(:~ 
 : Returns an <a> node with an @href attribute which points to the current object.
 :
 : @param $node the node of the current request.
 : @param $model the model of the current request.
 :)
declare function edweb:template-detail-link(
    $node as node(), 
    $model as map(*), 
    $from as xs:string
) as node() 
{
    let $id := $model?($from)?("id")
    return
        <a href="$id/{$id}">
            {templates:process($node/node(), $model)}
        </a>
};

(:~
 :
 :)
declare %templates:wrap function edweb:template-show-filters(
    $node as node(), 
    $model as map(*)
) as node()* 
{
    for $filter in $model?filters?*[?type != "id"]
    let $div :=
        <div data-template="edweb:load-filter" data-template-filter-name="{$filter?id}">
            {$node/*}
        </div>
    order by $filter?n
    return
        templates:process($div, $model)
};

(:~
 : Processes the node further only if a specified parameter is set.
 :
 : @param $node the current node.
 : @param $model the current model.
 : @param $parameter the parameter to be tested.
 : @return the content of node.
 :)
declare function edweb:template-show-if-parameter-set(
    $node as node(), 
    $model as map(*), 
    $parameter as xs:string
) as node()* 
{
    let $p := request:get-parameter($parameter, "")
    let $child-nodes :=
        if ($p eq "") 
        then ()
        else templates:process($node/node(), $model)
    return $child-nodes
};

(:~
 : Makes a switch in view available. The node should contain a element <switch> with the switch 
 : variable and the possible outcome nodes with the attribute @case. There should be one child with
 : @case="default".
 :
 : @param $node the node of the current request
 : @param $model the model of the current request
 : @return the child of $node with @case = <switch> or the default.
 :)
declare %templates:wrap function edweb:template-switch(
    $node as node(), 
    $model as map(*)
) 
{
    let $switch := templates:process($node/*:switch, $model)/normalize-space()
    return
        if ($switch = ($node/*/@case/string())) 
        then templates:process($node/*[@case = $switch], $model)
        else templates:process($node/*[@case = "default"], $model)
};

(:~  
 : Performs an XSLT transformation of the current object.
 :
 : @param $node the node the current request.
 : @param $model the model of the current request.
 : @return the transformed object.
 :)
declare function edweb:template-transform-current(
    $node as node(), 
    $model as map(*), 
    $resource as xs:string*
) as node()* 
{
    let $view := request:get-attribute("view")
    let $xsl-resource := 
        if ($resource) 
        then $resource 
        else if ($view != "")
        then $model?views?($view)?xslt
        else $model?views?*[?n=1]?xslt
    return
        if (empty($xsl-resource))
        then <div>Bitte Stylesheet angeben.</div>
        else
    let $path := edwebcontroller:get-exist-root()||edwebcontroller:get-exist-controller()||"/"||$xsl-resource
    let $stylesheet := 
        if (doc($path)) 
        then doc($path) 
        else error(xs:QName("edweb:template-transform-current-001"), $path||" not found.")
    let $xml := $model?current-doc
    let $parameters :=
        <parameters>
            <param name="exist:stop-on-error" value="yes"/> 
            { 
                for $param in templates:process($node/*, $model)/*:param
                return element param {
                    attribute name { $param/@name },
                    attribute value { $param/@value }
            }
        } </parameters>
    let $result :=
        try {
            transform:transform($xml, $stylesheet, $parameters)
        } 
        catch * {
            error(xs:QName("edweb:template-transform-current-002"), "Can't transform "
                ||util:collection-name($xml)||"/"||util:document-name($xml)||" with "
                ||util:document-name($path))
        }
    return templates:process($result, $model)
};

(: LOCAL functions :)

(:~
 : A helper function to transform a map() to an html table.
 :
 : @param $map the map to be transformed
 : @return a html table
 :)
declare function local:create-table-from-map(
    $map as map(*)
) as node() 
{
    let $table-rows :=
        map:for-each($map, function($key, $value) {
            <tr>
                <td>&#160;&#160;&#160;{$key}:&#160;</td>
                <td>{
                    if ($value instance of xs:string) 
                    then """"||$value||""""
                    else if ($value instance of xs:integer) 
                    then $value||""
                    else if ($value instance of map(*)) 
                    then ("{",local:create-table-from-map($value),"}")
                    else if ($value instance of node()) 
                    then "XML"
                    else if ($value instance of array(*)) 
                    then "array"
                    else if ($value instance of function(*)) 
                    then "Function"
                    else if (empty($value)) 
                    then "null"
                    else (
                        "("
                        ,
                        for $value in $value return 
                        if ($value instance of xs:string) 
                        then """"||$value||""""
                        else if ($value instance of xs:integer) 
                        then $value||""
                        else if ($value instance of map(*)) 
                        then ("{",local:create-table-from-map($value),"}")
                        else if ($value instance of node()) 
                        then "XML"
                        else if ($value instance of array(*)) 
                        then "array"
                        else if ($value instance of function(*)) 
                        then "Function"
                        else if (empty($value)) 
                        then "null"
                        else ()
                        ,
                        ")")
                }</td>
            </tr>
        })
    return <table>{ $table-rows }</table>
};

(:~
 : Retrieves the views of the current object.
 :
 : @return Returns a string with uris and labels like "uri-1:label-1::uri-2:label-2"
 :)
declare function local:get-object-views(
    $model as map(*)
) as xs:string 
{
    let $uri := request:get-uri()
    let $uri :=
        if (contains($uri, "/view/"))
        then
            (: /texts/t0001/view/default/my/path  --> /texts/t0001/ || my/path || view :)
            substring-before($uri, "/view/")||"/"
            ||substring-after(substring-after($uri, "/view/"), "/")||"view"
        else $uri||"/view"
    let $views :=
        for $view in $model?views?*
        let $id := $view?id
        let $n := $view?n
        let $label := $view?label
        let $uri := $uri||"/"||$id
        order by $n
        return $uri||$edweb:view-uri-label-separator||$label
    return string-join($views, $edweb:view-view-separator)
};
