xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
declare option output:method "json";
declare option output:media-type "application/json";

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $cache := request:get-parameter("cache", request:get-attribute("cache"))

let $id := request:get-parameter("id", request:get-attribute("id"))
let $id-type := request:get-parameter("id-type", request:get-attribute("id-type"))

return
    if ($id||"" != "")
    then edwebapi:get-by-id($app-target, $id, $id-type)
    else if ($id-type = "all")
    then edwebapi:get-all($app-target, false(), $cache)
    else
    let $all-list := edwebapi:get-all($app-target, true(), $cache)
    return
    if ($id-type = "complete")
    then
        map:remove($all-list, "date-time")
    else
        map:remove($all-list, "date-time")?*[?filter?($id-type)||"" != ""]
