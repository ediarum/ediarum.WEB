xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
declare option output:method "json";
declare option output:media-type "application/json";

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $cache := request:get-parameter("cache", request:get-attribute("cache"))

return edwebapi:get-all($app-target, $cache)