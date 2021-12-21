xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";
import module namespace kwic="http://exist-db.org/xquery/kwic";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace functx = "http://www.functx.com";

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

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $object-type := request:get-parameter("object-type", request:get-attribute("object-type"))
let $object-id := request:get-parameter("object-id", request:get-attribute("object-id"))

let $search-query := request:get-parameter("search", request:get-attribute("search"))
let $search-type := request:get-parameter("search-type", request:get-attribute("search-type"))
let $search-xpath := request:get-parameter("search-xpath", request:get-attribute("search-xpath"))
let $search-xpath :=
    if ($search-xpath||"" eq "")
    then "."
    else $search-xpath
let $slop := request:get-parameter("slop", request:get-attribute("slop"))
let $kwic-width := request:get-parameter("kwic-width", request:get-attribute("kwic-width"))

let $view := request:get-parameter("view", request:get-attribute("view"))||""

let $map :=
    if ($search-query||"" != "")
    then
        edwebapi:get-object-with-search($app-target, $object-type, $object-id, (), $kwic-width, $search-xpath, $search-query, $search-type, $slop)
    else
        edwebapi:get-object($app-target, $object-type, $object-id)

let $xml := 
    if ($view != "")
    then 
        let $view-params := local:init-params((tokenize($map?views?($view)?params,' ')))
        return edwebapi:get-object-as($app-target, $object-type, $object-id, $view, $view-params)
    else 
        $map?xml

return $xml