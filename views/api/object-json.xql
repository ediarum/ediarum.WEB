xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
declare option output:method "json";
declare option output:media-type "application/json";

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $object-type := request:get-parameter("object-type", request:get-attribute("object-type"))
let $object-id := request:get-parameter("object-id", request:get-attribute("object-id"))

let $part := request:get-parameter("part", request:get-attribute("part"))
let $output := request:get-parameter("output", request:get-attribute("output"))

let $map := edwebapi:get-object($app-target, $object-type, $object-id)
return
    if ($part != "") 
    then
        map:merge((
            $map?parts?($part),
            map:entry(
                "list", 
                edwebapi:list-parts($map?xml, $map?parts, $part, $object-type, $object-id)
            )
        ))
    else if ($output = "json-xml")
    then $map
    else map:remove($map, 'xml')

