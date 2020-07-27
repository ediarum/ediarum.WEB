xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare option output:method "text";
declare option output:media-type "text/plain";

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

let $view := request:get-parameter("view", request:get-attribute("view"))||""

let $map := edwebapi:get-object($app-target, $object-type, $object-id)

let $xml := 
    if ($view != "")
    then 
        let $view-params := local:init-params((tokenize($map?views?($view)?params,' ')))
        return edwebapi:get-object-as($app-target, $object-type, $object-id, $view, $view-params)
    else 
        $map?xml

return $xml