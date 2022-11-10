xquery version "3.1";

module namespace edwebcache="http://www.bbaw.de/telota/software/ediarum/web/cache";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";

declare variable $edwebcache:cache-collection := "cache";

declare function edwebcache:data-collection(
    $app-target as xs:string
) as xs:string
{
    let $path := doc($app-target||"/appconf.xml")//appconf:project/appconf:collection/normalize-space()
    return 
        if (starts-with($path, '/'))
        then $path
        else $app-target||"/"||$path
};

(:~
 : Retrieves and stores the result of a function in cache. Only executes the function if no cache
 : exists or if the cache is out of date because data updates.
 : 
 : @param $function-qname the qname of the function to apply
 : @param $params an array of the function params. IMPORTANT: the first parameter must be 'app-target'.
 : $node-set the node set the cache date is compared to
 : @reload if true the cache is always rebuild
 : @return the result of the function as a map.
 :)
declare function edwebcache:load-map-from-cache(
    $function-qname as xs:QName,
    $params as array(*),
    $app-target as xs:string?,
    $cache as xs:string?
) as map(*)
{
    if ($cache = "off")
    then
        function-lookup($function-qname, $params => array:size() ) => apply($params)
    else
    let $cache-collection :=
        if (xmldb:collection-available($app-target||"/"||$edwebcache:cache-collection))
        then $app-target||"/"||$edwebcache:cache-collection
        else xmldb:create-collection($app-target, $edwebcache:cache-collection)
    let $cache-file-name := local-name-from-QName($function-qname)||"-"
        ||translate(string-join($params?*[position()!=1], "-"),'/','__')||".json"

    let $map-from-cache :=
        if (doc-available($cache-collection||"/"||$cache-file-name||".lock"))
        then
            if(util:binary-doc-available($cache-collection||"/"||$cache-file-name))
            then json-doc($cache-collection||"/"||$cache-file-name)
            else error(xs:QName("edwebcache:load-map-from-cache"), "Cache for '"||$cache-file-name||"' can't be accessed: "||doc($cache-collection||"/"||$cache-file-name||".lock")/string())
        else if ($cache = "reset")
        then ()
        else if (not(util:binary-doc-available($cache-collection||"/"||$cache-file-name)))
        then ()
        else if ($cache = "no")
        then
            let $data-collection := edwebcache:data-collection($app-target)
            let $node-set as node()* :=
                if ($data-collection||"" = "")
                then ()
                else if (xmldb:collection-available($data-collection))
                then collection($data-collection) (: /* :)
                else if (doc-available($data-collection))
                then doc($data-collection)/*
                else error(xs:QName("edwebcache:load-map-from-cache"), "Can't find collection or resource. data-collection: "||$data-collection)
            let $map-from-cache := json-doc($cache-collection||"/"||$cache-file-name)
            let $since := $map-from-cache?date-time
            let $last-modified := xmldb:find-last-modified-since($node-set, $since)
            return
                if (count($last-modified)=0)
                then $map-from-cache
                else ()
        else json-doc($cache-collection||"/"||$cache-file-name)
    return
        if (exists($map-from-cache))
        then $map-from-cache
        else
            let $set-lock-for-cache-file := xmldb:store($cache-collection,$cache-file-name||".lock", <root>Locked since {util:system-dateTime()}.</root>)
            let $map := function-lookup($function-qname, $params => array:size() ) => apply($params)
            let $touch-file := xmldb:store($cache-collection, $cache-file-name, serialize(map {"error": "##"||count(map:keys($map))}, <output:serialization-parameters><output:method>json</output:method><output:media-type>application/json</output:media-type></output:serialization-parameters> ))
            let $serialization := serialize($map, <output:serialization-parameters><output:method>json</output:method><output:media-type>application/json</output:media-type></output:serialization-parameters>)
            let $set-lock-for-cache-file := xmldb:store($cache-collection,$cache-file-name||".lock", <root>Locked since {util:system-dateTime()}. Map successful generated.</root>)
            let $store := xmldb:store($cache-collection, $cache-file-name, $serialization)
            let $remove-lock-for-cache-file := xmldb:remove($cache-collection, $cache-file-name||".lock")
            return json-doc($cache-collection||"/"||$cache-file-name)
};
