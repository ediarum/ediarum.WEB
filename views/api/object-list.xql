xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
declare option output:method "json";
declare option output:media-type "application/json";

(:~
 : Reads the parameters of the request to a map.
 :
 : @param $param-names a list of parameters.
 : @return a map with parameter names as keys and the content as values.
 :)
declare function local:init-params(
    $param-names as xs:string*
) as map() 
{
    map:merge((
        for $p in $param-names
        return map:entry($p, request:get-parameter($p, request:get-attribute($p)))
    ))
};

let $object-type := request:get-parameter("object-type",request:get-attribute("object-type"))
let $cache := request:get-parameter("cache", request:get-attribute("cache"))
let $app-target := request:get-parameter("app-target",request:get-attribute("app-target"))
let $limit := request:get-parameter("limit",request:get-attribute("limit"))

let $search-query := request:get-parameter("search",request:get-attribute("search"))
let $kwic-width := request:get-parameter("kwic-width",request:get-attribute("kwic-width"))
let $search-type := request:get-parameter("search-type",request:get-attribute("search-type"))
let $slop := request:get-parameter("slop",request:get-attribute("slop"))

let $order := request:get-parameter("order", request:get-attribute("order"))
let $filter-expression := request:get-parameter("filterExpression", ())
let $range := number(request:get-parameter("range", request:get-attribute("range")))
let $page := number(request:get-parameter("page", request:get-attribute("page")))
let $from := number(request:get-parameter("from", request:get-attribute("from")))

let $id := request:get-parameter("id", request:get-attribute("id"))
let $object := request:get-parameter("object",request:get-attribute("object"))
let $subject := request:get-parameter("subject",request:get-attribute("subject"))

let $show := request:get-parameter("show", request:get-attribute("show"))||""

let $config := edwebapi:get-config($app-target)
let $is-object := exists($config//appconf:object[@xml:id=$object-type])
let $is-relation := exists($config//appconf:relation[@xml:id=$object-type])

let $result := 
    if ($is-object and $show eq 'compact')
    then 
        edwebapi:load-map-from-cache(
            "edwebapi:get-object-list-without-filter", 
            [$app-target, $object-type, $limit], 
            $app-target,
            $cache = "no", 
            $cache = "reset"
        )
    else if ($is-object) 
    then
        edwebapi:load-map-from-cache(
            "edwebapi:get-object-list", 
            [$app-target, $object-type, $limit], 
            $app-target, 
            $cache = "no",
            $cache = "reset"
        )
    else if ($is-relation)
    then
        if ($show = ("", "list", "full"))
        then
        edwebapi:load-map-from-cache(
            "edwebapi:get-relation-list",
            [$app-target, $object-type, $show, $limit],
            $app-target,
            $cache = "no",
            $cache = "reset"
        )
        else "Parameter 'show' must be one of 'list', 'full' or ''."
    else $object-type||" isn't defined for '"||$app-target||"'."
return
    if ($is-object and ($show eq 'list' or $show eq 'all' or $show eq 'compact')) 
    then
        let $filter-params := 
            if ($show eq 'list') 
            then local:init-params((map:keys($result?filter)))
            else if ($show eq 'all') 
            then map:merge(())
            else map:merge(())
        let $result := 
            if ($search-query||"" != "")
            then 
                edwebapi:get-object-list-with-search(
                    $result, 
                    $app-target, 
                    $object-type, 
                    ".", 
                    $kwic-width, 
                    $search-query,
                    $search-type,
                    $slop
                )
            else $result
        let $array := $result?list?*
        let $array := edwebapi:order-items($array, $order)
        let $array := edwebapi:filter-list($array, $result?filter, $filter-params)
        return 
            if ($page) 
            then subsequence($array, (($page - 1) * $range) + 1, $range )
            else if ($from) 
            then subsequence($array, $from, $range )
            else $array
    else if ($is-object and ($show eq 'filter')) 
    then $result?filter
    (: Relations :)
    else if ($show eq 'list' and $subject||"" != "")
    then $result?list?*[?subject = $subject]
    else if ($show eq 'full' and $subject||"" != "")
    then $result?list?*[?subject?id = $subject]
    else if ($show eq 'list' and $object||"" != "")
    then $result?list?*[?object = $object]
    else if ($show eq 'full' and $object||"" != "")
    then $result?list?*[?object?id = $object]
    else $result
