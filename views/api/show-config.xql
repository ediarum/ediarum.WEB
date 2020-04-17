xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";

declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))

let $xml := edwebapi:get-config($app-target)
return $xml

