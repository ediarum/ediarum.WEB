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

let $order := request:get-parameter("order", request:get-attribute("order"))
let $filter-expression := request:get-parameter("filterExpression", ())
let $range := number(request:get-parameter("range", request:get-attribute("range")))
let $page := number(request:get-parameter("page", request:get-attribute("page")))
let $from := number(request:get-parameter("from", request:get-attribute("from")))

let $show := request:get-parameter("show", request:get-attribute("show"))

let $config := edwebapi:get-config($app-target)
let $is-object := exists($config//appconf:object[@xml:id=$object-type])
let $is-relation := exists($config//appconf:relation[@xml:id=$object-type])

let $result := 
    if ($is-object and $show eq 'compact')
    then 
        edwebapi:load-map-from-cache(
            "edwebapi:get-object-list-without-filter", 
            [$app-target, $object-type], 
            if ($cache = "yes")
            then ()
            else collection(edwebapi:data-collection($app-target))/*, 
            $cache = "no"
        )
    else if ($is-object) 
    then
        edwebapi:load-map-from-cache(
            "edwebapi:get-object-list", 
            [$app-target, $object-type], 
            if ($cache = "yes")
            then ()
            else collection(edwebapi:data-collection($app-target))/*, 
            $cache = "no"
        )
    else if ($is-relation) 
    then 
        edwebapi:load-map-from-cache(
            "edwebapi:get-relation-list",
            [$app-target, $object-type], 
            if ($cache = "yes")
            then ()
            else collection(edwebapi:data-collection($app-target))/*, 
            $cache = "no"
        )
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
    else $result
