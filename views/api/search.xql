xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace appconf = "http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare option output:method "json";
declare option output:media-type "application/json";

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $limit := request:get-parameter("limit", request:get-attribute("limit"))
let $cache := request:get-parameter("cache", request:get-attribute("cache"))
let $search-id := request:get-parameter("search-id", request:get-attribute("search-id"))

let $kwic-width := request:get-parameter("kwic-width", request:get-attribute("kwic-width"))
let $query := request:get-parameter("q", request:get-attribute("q"))
let $type := request:get-parameter("type", request:get-attribute("type"))
let $slop := request:get-parameter("slop", request:get-attribute("slop"))

return 
    edwebapi:get-search-results(
        $app-target, 
        $search-id, 
        $kwic-width, 
        $query, 
        $type,
        $slop,
        $limit,
        $cache
    )
