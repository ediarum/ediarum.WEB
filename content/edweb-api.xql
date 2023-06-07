xquery version "3.1";

(:~
 : The generalized functions for generating the content of ediarum.web.
 :)
module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";


import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";
import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace functx = "http://www.functx.com";

declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare variable $edwebapi:controller := "/ediarum.web";
declare variable $edwebapi:projects-collection := "/db/projects";
(: See also $edweb:param-separator. :)
declare variable $edwebapi:param-separator := ";";
declare variable $edwebapi:object-limit := 10000;
declare variable $edwebapi:cache-collection := "cache";

declare function edwebapi:map-from-cache(
    $app-target as xs:string,
    $cache-file-name as xs:string,
    $cache as xs:string?
)
{

    if ($cache = "off")
    then ()
    else
    let $cache-collection :=
        if (xmldb:collection-available($app-target||"/"||$edwebapi:cache-collection))
        then $app-target||"/"||$edwebapi:cache-collection
        else xmldb:create-collection($app-target, $edwebapi:cache-collection)
    return
        if (doc-available($cache-collection||"/"||$cache-file-name||".lock"))
        then
            if(util:binary-doc-available($cache-collection||"/"||$cache-file-name))
            then json-doc($cache-collection||"/"||$cache-file-name)
            else error(xs:QName("edwebapi:load-map-from-cache"), "Cache for '"||$cache-file-name||"' can't be accessed: "||doc($cache-collection||"/"||$cache-file-name||".lock")/string())
        else if ($cache = "reset")
        then ()
        else if (not(util:binary-doc-available($cache-collection||"/"||$cache-file-name)))
        then ()
        else if ($cache = "yes")
        then json-doc($cache-collection||"/"||$cache-file-name)
        else
            let $data-collection := edwebapi:data-collection($app-target)
            let $node-set as node()* :=
                if ($data-collection||"" = "")
                then ()
                else if (xmldb:collection-available($data-collection))
                then collection($data-collection) (: /* :)
                else if (doc-available($data-collection))
                then doc($data-collection)/*
                else error(xs:QName("edwebapi:load-map-from-cache"), "Can't find collection or resource. data-collection: "||$data-collection)
            let $map-from-cache := json-doc($cache-collection||"/"||$cache-file-name)
            let $since := $map-from-cache?date-time
            let $last-modified := xmldb:find-last-modified-since($node-set, $since)
            return
                if (count($last-modified)=0)
                then $map-from-cache
                else ()
};

declare function edwebapi:get-cache-file-name(
    $function-qname as xs:QName,
    $params as array(*)
)
{
    local-name-from-QName($function-qname)||"-"
        ||translate(string-join($params?*[position()!=1], "-"),'/','__')||".json"
};

declare function edwebapi:save-to-cache(
    $app-target as xs:string,
    $cache-file-name as xs:string,
    $map as map(*),
    $cache as xs:string?
)
{
    if ($cache = "off")
    then ()
    else
    let $cache-collection :=
        if (xmldb:collection-available($app-target||"/"||$edwebapi:cache-collection))
        then $app-target||"/"||$edwebapi:cache-collection
        else xmldb:create-collection($app-target, $edwebapi:cache-collection)
    let $serialization := serialize($map, <output:serialization-parameters><output:method>json</output:method><output:media-type>application/json</output:media-type></output:serialization-parameters>)
    return
        xmldb:store($cache-collection, $cache-file-name, $serialization)
};

(:~
 : 
 :)
declare function edwebapi:filter-list(
    $list as map(*)*, 
    $filters as map(*), 
    $params as map(*)
) as map(*)* 
{
    if (count(map:keys($filters)) > 0) then
        let $filter := $filters?*[1]
        let $filter-id := $filter?id
        let $filter-values := tokenize($params?($filter-id), $edwebapi:param-separator)
        let $filter-expression :=
            if (empty($filter-values)) 
            then function($list as map(*)*) { $list}
            else
                switch($filter?type)
                case "id" 
                return function($list as map(*)*) { $list[?filter?($filter-id) = $filter-values] }
                case "single" 
                return function($list as map(*)*) { $list[?filter?($filter-id) = $filter-values] }
                case "union" 
                return function($list as map(*)*) { $list[?filter?($filter-id) = $filter-values] }
                case "intersect" 
                return
                    function($list as map(*)*) {
                        for $item in $list 
                        let $item-filter-values := $item?filter?($filter-id)
                        let $filters-are-true := 
                            for $fv in $filter-values 
                            return ($fv = $item-filter-values) 
                        return
                            if (not( false() = ($filters-are-true) )) 
                            then $item
                            else ()
                    }
                case "greater-than" 
                return function($list as map(*)*) { $list[?filter?($filter-id) >= $filter-values] }
                case "lower-than" 
                return function($list as map(*)*) { $list[?filter?($filter-id) <= $filter-values] }
                default 
                return function($list as map(*)*) { () }
        let $filtered-list := $filter-expression($list)
        let $other-filter := map:remove($filters, $filter-id)
        return
            if (count(map:keys($other-filter)) > 0) 
            then edwebapi:filter-list($filtered-list, $other-filter, $params)
            else $filtered-list
    else $list
};

(:~
 : Retrieves all defined objects with or without filter properties.
 :
 : @param $app-target the collection name where the app is installed, e.g. project.WEB
 : @param $with-filters boolean value if filter properties should be shown.
 : @return a list of objects maps
 :)
declare function edwebapi:get-all(
    $app-target as xs:string,
    $with-filters as xs:boolean,
    $cache as xs:string?
) as map(*)
{
    let $cache-file-name := translate("get-all-"||$with-filters||".json", '/','__')
    let $cache-map := edwebapi:map-from-cache($app-target, $cache-file-name, $cache)
    return if (exists($cache-map)) then $cache-map else

    let $map := map:merge((
        map:entry("date-time", current-dateTime()),
        for $object-type in edwebapi:get-config($app-target)//appconf:object/@xml:id
        return edwebapi:get-object-list($app-target, $object-type, $with-filters, $cache)?list
    ))

    let $store := edwebapi:save-to-cache($app-target, $cache-file-name, $map, $cache)
    return $map
};

(:~
 : Retrieves the appconf.xml from the project app.
 :
 : @param $app-target the collection name where the app is installed, e.g. project.WEB
 : @return the appconf.xml as node
 :)
declare function edwebapi:get-config(
    $app-target as xs:string
) as node()*
{
    doc($app-target||"/appconf.xml")
};

(:~
 :
 :)
declare function edwebapi:list-parts(
    $xml, 
    $parts, 
    $part-name, 
    $object-type, 
    $object-id
) 
{
    let $part := $parts?($part-name)
    let $root := $part?root
    let $id-path := $part?id
    let $xpath := ".//" || $root || "/" || $id-path
    let $depends := $part?depends
    (: Wenn es depend gibt, .. :)
    return
        if ($depends != "") 
        then
            (: .. gib den 'path' mit, suche die dortigen IDs und liefere subxml, sowie den 
               ersetzten 'path' zurück. :)
            let $depend-maps :=
                local:list-part-ids(
                    $xml,
                    $parts,
                    $parts?($depends),
                    $part?path,
                    $object-type,
                    $object-id
                )
            (: Dann suche nach Teilen im 'subxml' .. :)
            for $d-map in $depend-maps
            let $ids := util:eval-inline($d-map?xml, $xpath)
            (: .. und ersetze im 'path' die aktuelle IDs. :)
            for $id in $ids
            return replace($d-map?path, "<" || $part?xmlid || ">", $id)
        else
            (: Sonst suche im XML und ersetze im 'path' die aktuelle ID. :)
            let $ids := util:eval-inline($xml, $xpath)
            for $id in $ids
            return replace($part?path, "<" || $part?xmlid || ">", $id)
};

(:~
 :
 :)
declare function local:list-part-ids(
    $xml as node(),
    $parts as map(*),
    $part as map(*),
    $sub-path as xs:string,
    $object-type as xs:string,
    $object-id as xs:string
) as map(*)*
{
    let $maps :=
        (: Wenn es Abhängigkeiten gibt, .. :)
        if ($part?depends != "")
        then
            (: .. dann rufe diese Funktion rekursiv auf, .. :)
            local:list-part-ids(
                $xml, (: .. übergebe das volle XML, .. :)
                $parts, (: .. die Definition aller "Teile", .. :)
                $parts?($part?depends), (: .. den "Teil" mit Abhängigkeit, .. :)
                $part?path, (: .. den aktuellen "Pfad", z.B. <book>.<chapter>, .. :)
                $object-type, (: .. den Objekt-Typ .. :)
                $object-id (: .. und die ID. :)
            )
            (: Als Resultat gibt es eine Map mit den jeweiligen Teil-XMLs und teilweise aufgelösten Pfaden. :)
        else
            (: Ansonsten nimm .. :)
            map {
                "xml": $xml, (: .. das vollständige XML .. :)
                "path": $part?path (: .. und die Pfaddefinition, z.B. <book>. :)
            }

    (: Für jedes Teil-XML und die Pfaddefinition, z.B. book-1.<chapter>, book-2.<chapter> :)
    for $map in $maps
    let $xml := $map?xml
    let $path := $map?path

    (: .. stelle den XPATH-Ausdruck zusammen, .. :)
    let $root := $part?root
    let $id-path := $part?id
    let $xpath := ".//" || $root || "/" || $id-path
    (: .. suche nach Teilen mit IDs im 'subxml' .. :)
    let $ids := util:eval-inline($xml, $xpath)
    (: .. und ersetze im 'path' die gefundenen IDs. :)
    for $id in $ids
    (: Nimm den Pfad für den aktuellen Teil, z.B.: prefix-<book> --> prefix-1, .. :)
    let $this-path := replace($path, "<" || $part?xmlid || ">", $id)
    (: .. um damit den längeren Subpfad zu konkretisieren, z.B.: prefix-<book>.<chapter> --> prefix-1.<chapter>, .. :)
    let $sub-path := replace($sub-path, $part?path, $this-path)
    (: .. und das jeweilige spezifischere Sub-XML zu holen und weiterzurreichen. :)
    let $sub-xml := edwebcontroller:api-get("/api/"||$object-type||"/"||$object-id||"/"||$this-path)
    return
        (: Übergebe das XML und den konkretisierten Pfad an die aufrufende Funktion. :)
        map:merge((
            map:entry("id", $id),
            map:entry("path", $sub-path),
            map:entry("xml", $sub-xml)
        ))
};

(:~
 :
 :)
declare function edwebapi:get-object(
    $app-target as xs:string,
    $object-type as xs:string, 
    $object-id as xs:string
) as map(*) 
{
    let $cache := ""
    let $object-def := edwebapi:get-config($app-target)//appconf:object[@xml:id=$object-type]

    let $item := edwebapi:get-object-xml($app-target, $object-type, $object-id)
    let $xml := $item

    let $inner-nav :=
        for $n in $object-def/appconf:inner-navigation/appconf:navigation
        let $key := $n/@xml:id/string()
        let $xpath := $n/appconf:xpath/string()
        let $id-path := $n/appconf:id/string()
        let $label-func := $n/appconf:label-function/normalize-space()
        let $order-by := $n/appconf:order-by/string()
        let $list :=
            array {
                for $i at $pos in util:eval-inline($item, $xpath)
                let $id := util:eval-inline($i, $id-path)||""
                let $label := util:eval($label-func)($i)
                let $order := 
                    if ($order-by = "label") 
                    then $label[1]
                    else $pos
                order by $order
                return
                    map:merge((
                        map:entry("id", $id),
                        map:entry("label", $label)
                    ))
            }
        return
            map:entry(
                $key, 
                map:merge((
                    map:entry("name", $n/appconf:name/string()),
                    map:entry("xpath", $xpath),
                    map:entry("id", $id-path),
                    map:entry("order-by", $order-by),
                    map:entry("label-function", $label-func),
                    map:entry("list", $list)
                ))
            )
    let $parts :=
        let $separator := $object-def/appconf:parts/@separator/string()
        let $prefix := $object-def/appconf:parts/@prefix/string()
        let $prepath := ""
        for $part in $object-def/appconf:parts/appconf:part
            return local:get-part-map($part, $prefix, $prepath, $separator, "")
    let $views := 
        for $view at $pos in $object-def//appconf:views/appconf:view
        let $id := $view/@id/string()
        let $xslt := $view/appconf:xslt/string()
        let $label := $view/appconf:label/string()
        let $params := $view/appconf:xslt/@params/string()||""
        return
            map:entry (
                $id,
                map:merge((
                    map:entry("id", $id),
                    map:entry("xslt", $xslt),
                    map:entry("label", $label),
                    map:entry("params", $params),
                    map:entry("n", $pos)
                )) 
            )

    let $relations :=
        map:merge((
            for $f in $object-def/appconf:filters/appconf:filter[@type='relation']
            let $rel-type-name := $f/appconf:relation/@id/string()
            return
            map:entry(
                $rel-type-name,
                let $rel-perspective := $f/appconf:relation/@as/string()
                let $rel-target :=
                    switch($rel-perspective)
                    case "subject" return "object"
                    case "object" return "subject"
                    default return
                        error(xs:QName("edwebapi:get-object-list-002"),
                            "Invalid configuration parameter value, only 'subject' or 'object' allowed."
                        )
                for $r in edwebapi:get-relation-list($app-target, $rel-type-name, false(), $cache)?list?*
                return map:entry(
                    $r?($rel-perspective),
                    switch($f/appconf:label/string())
                    case "predicate" return $r?predicate
                    case "id" return $r?($rel-target)
                    case "id+predicate"
                    return $r?($rel-target)||"+"||$r?predicate
                    default return
                        error(xs:QName("edwebapi:get-object-list-003"),
                            "Invalid configuration parameter value, only 'id', 'predicate', and 'id+predicate' allowed."
                        )
                )
            )
        ))

    let $object-map := edwebapi:eval-base-data-for-object($object-def, $item)
    let $filter-map := edwebapi:eval-filters-for-object($object-def, $object-map, $item, $relations)
    return 
        map:merge((
            $object-map,
            $filter-map,
            map:entry("xml", $xml),
            map:entry("inner-nav", map:merge(( $inner-nav )) ),
            map:entry("parts", map:merge(( $parts )) ),
            map:entry("views", map:merge(( $views )) )
        ))
};

(:~  
 : Performs an XSLT transformation of the object.
 :
 : @param $app-target
 : @param $object-type 
 : @param $object-id 
 : @param $view the id of the view
 : @param $params a map with parameters which is transferred to the xslt
 : @return the transformed object.
 :)
declare function edwebapi:get-object-as(
    $app-target as xs:string,
    $object-type as xs:string, 
    $object-id as xs:string,
    $view as xs:string,
    $params as map(*)
) as node()* 
{
    let $object := edwebapi:get-object($app-target, $object-type, $object-id)
    let $xsl-path := $object?views?($view)?xslt
    let $path := $app-target||"/"||$xsl-path
    let $stylesheet := 
        if (doc($path)) 
        then doc($path) 
        else error(xs:QName("edwebapi:get-object-as-001"), $path||" not found.")
    let $xml := $object?xml
    let $parameters :=
        <parameters>
            <param name="exist:stop-on-error" value="yes"/> 
            { 
                for $param in map:keys($params)
                return element param {
                    attribute name { $param },
                    attribute value { $params?($param) }
            }
        } </parameters>
    let $result :=
        try {
            transform:transform($xml, $stylesheet, $parameters)
        } 
        catch * {
            error(xs:QName("edwebapi:get-object-as-002"), "Can't transform "
                ||util:collection-name($xml)||"/"||util:document-name($xml)||" with "
                ||$path)
        }
    return $result
};

declare function edwebapi:get-object-with-search(
    $app-target as xs:string,
    $object-type as xs:string,
    $object-id as xs:string,
    $part as xs:string?,
    $kwic-width as xs:string?,
    $search-xpath as xs:string,
    $search-query as xs:string,
    $search-type as xs:string?,
    $slop as xs:string?
) as map(*)
{
    let $object-def := edwebapi:get-config($app-target)//appconf:object[@xml:id=$object-type]
    let $xml := edwebapi:get-object-xml($app-target, $object-type, $object-id)

    (: Search :)
    let $init-indices := local:init-search-indices($app-target)
    let $kwic-width :=
        if ($kwic-width||"" = "")
        then "30"
        else $kwic-width
    let $search-xpath :=
        if ($search-xpath eq ".")
        then "("||string-join($object-def/appconf:lucene/appconf:text/@qname/string(), "|")||")"
        else $search-xpath

    let $query := edwebapi:build-search-query($search-query, $search-type, $slop)

    let $query-function := ".[.//"||$search-xpath||"[ft:query(., $query)]]"
    let $search-score :=
        if ($search-xpath||$search-query||"" != "")
        then ft:score($xml)
        else 0.0
    let $search-hits :=
        if ($search-xpath||$search-query||"" != "")
        then
            if ($search-type = 'distance' or $search-type = 'distance-all-matches')
            then ()
            else util:eval-inline($xml, $query-function)
        else ()
    let $xml :=
        if (count($search-hits) > 0)
        then util:expand($search-hits)
        else $xml

    let $map := edwebapi:get-object($app-target, $object-type, $object-id)
    let $parts-def := $object-def//appconf:parts
    let $part-def := $parts-def//appconf:part[@xml:id eq $part]
    return
        map:merge((
            $map,
            map:entry("xml", $xml),
            map:entry(
                "search-results",
                if ($search-type = 'distance')
                then
                    let $wg1 := substring-before($search-query, '~')
                    let $wg2 := substring-after($search-query, '~')
                    return
                        let $matches :=
                        local:get-matches(normalize-space($xml),
                        "(("||$wg1||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg2||"))|(("||$wg2||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg1||"))"
                        )
                        return for $match in $matches
                        return
                                map:merge ((
                                    map:entry("keyword-1", substring-before($match, " ")),
                                    map:entry("context", $match),
                                    map:entry("keyword-2", functx:substring-after-last($match, " "))
                                ))
                else if ($search-type = 'distance-all-matches')
                then
                    let $wg1 := substring-before($search-query, '~')
                    let $wg2 := substring-after($search-query, '~')
                    return
                        let $query := "(("||$wg1||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg2||"))|(("||$wg2||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg1||"))"
                        let $matches := functx:get-matches(normalize-space($xml), $query)
                        return for $match in $matches
                        let $m-1 := functx:get-matches($match, $query)[1]
                        return
                                map:merge ((
                                    map:entry("keyword-1", substring-before($m-1, " ")),
                                    map:entry("context", $m-1),
                                    map:entry("keyword-2", functx:substring-after-last($m-1, " "))
                                ))
                else
                for $hit in $search-hits
                let $kwic := kwic:summarize($hit, <config width="{$kwic-width}"/>)
                (: TODO delete following line? :)
                for $item at $pos in $kwic
                let $match := ($xml//exist:match)[position() = $pos]
                return
                    map:merge ((
                        map:entry("context-previous", $kwic[$pos]/span[@class='previous']/string()),
                        map:entry("keyword", $kwic[$pos]/span[@class='hi']/string()),
                        map:entry("context-following", $kwic[$pos]/span[@class='following']/string()),
                        map:entry("score", ft:score($hit)),
                        if ($part-def)
                        then map:entry("part-id", local:find-part-id-for-node($parts-def, $part-def, $match))
                        else ()
                    ))
            ),
            map:entry("score", $search-score)
        ))
};

declare function edwebapi:build-search-query(
    $search-query as xs:string,
    $search-type as xs:string?,
    $slop as xs:string?
) as item()
{
    switch ($search-type)
    case "regex" return
        <query><bool>
        {
            for $word in tokenize($search-query, ' ' )
            return
                <regex occur="must">{$word}</regex>
        }
        </bool></query>
    case "distance" return
        if (not(contains($search-query, '~')))
        then error(xs:QName("edwebapi"), "In a search of type 'distance' the 'search' must contain '~' to separate the search terms.")
        else <query><near slop="{$slop}" ordered="no"><regex>{substring-before($search-query,'~')}</regex><regex>{substring-after($search-query,'~')}</regex></near></query>
    case "distance-all-matches" return
        if (not(contains($search-query, '~')))
        then error(xs:QName("edwebapi"), "In a search of type 'distance' the 'search' must contain '~' to separate the search terms.")
        else <query><near slop="{$slop}" ordered="no"><regex>{substring-before($search-query,'~')}</regex><regex>{substring-after($search-query,'~')}</regex></near></query>
    case "phrase" return <query><phrase slop="{$slop}">{$search-query}</phrase></query>
    case "lucene" return $search-query
    default return
        <query><bool>
        {
            for $word in tokenize($search-query, ' ' )
            return
                <term occur="must">{$word}</term>
        }
        </bool></query>
};

declare function local:find-part-id-for-node(
    $parts-def as node(),
    $part-def as node(),
    $match as node()
) as xs:string?
{
    let $super-part-def := $part-def/parent::appconf:part
    (: Suche den Part-Knoten mit ID. :)
    let $part-xpath-root := $part-def/appconf:root/string()
    let $part-node := util:eval("$match/(ancestor::"||$part-xpath-root||" | preceding::"||$part-xpath-root||")[last()]")
    let $part-xpath-id := $part-def/appconf:id/string()
    let $part-id := util:eval("$part-node/"||$part-xpath-id)
    let $separator := $parts-def/@separator/string()
    let $starts-with :=
        if ($part-def/@starts-with)
        then $part-def/@starts-with||$parts-def/@prefix
        else ""
    return
        (: 1. Wenn es keinen super-part gibt, .. :)
        if (count($super-part-def) = 0)
        (: .. dann ancestor/preceding als id :)
        then
            $starts-with||$part-id
        (: 2. Wenn es einen super-part gibt, .. :)
        else
            let $super-part-xpath-root := $super-part-def/appconf:root/string()
            let $super-part-xpath-id := $super-part-def/appconf:id/string()
            (: .. suche super-part von xml-node .. :)
            let $super-part-node-1 := util:eval("$match/(ancestor::"||$super-part-xpath-root||" | preceding::"||$super-part-xpath-root||")[last()]")
            let $super-part-id-1 := util:eval("$super-part-node-1/"||$super-part-xpath-id)
            (: .. und super-part von part-node aus. :)
            let $super-part-node-2 := util:eval("$part-node/(ancestor::"||$super-part-xpath-root||" | preceding::"||$super-part-xpath-root||")[last()]")
            let $super-part-id-2 := util:eval("$super-part-node-2/"||$super-part-xpath-id)
            return
                (: Sind sie identisch, .. :)
                if ($super-part-id-1 = $super-part-id-2)
                (: .. ist part valide und nimm part-id und gehe rekursiv weiter. :)
                then
                    local:find-part-id-for-node($parts-def, $super-part-def, $part-node)||$separator||$starts-with||$part-id
                (: Sonst ist part invalide und kein Treffer. :)
                else ()
};

declare function edwebapi:get-object-xml(
    $app-target as xs:string,
    $object-type as xs:string,
    $object-id as xs:string
) as node()?
{
    let $object-def := edwebapi:get-config($app-target)//appconf:object[@xml:id=$object-type]
    let $namespaces :=
        for $ns in $object-def/appconf:item/appconf:namespace
        let $prefix := $ns/@id/string()
        let $namespace-uri := $ns/string()
        return util:declare-namespace($prefix, $namespace-uri)
    let $list := edwebapi:get-objects($app-target, $object-type)

    let $id-xpath := $object-def/appconf:item/appconf:id
    let $find-expression := $id-xpath||"='"||$object-id||"'"
    let $item := util:eval("$list["||$find-expression||"][1]")

    let $xml :=
        if ($item[1])
        then $item[1]
        else error(xs:QName("edwebapi:get-object-001"), "Can't find object with id "||$object-id)
    return $xml
};

declare function edwebapi:eval-base-data-for-object(
    $object-def as node(),
    $object as node()
) as map(*)
{
    let $object-type := $object-def/@xml:id/string()
    return
    if (count(ft:field($object, $object-type||"---id")) != 1)
    then
        error(
            xs:QName("edwebapi:get-object-list-001"),
            "There should be exact one ID for each object."
            ||" Count: "||count(ft:field($object, $object-type||"---id"))||", Object: "
            ||serialize($object)
        )
    else
        map:merge ((
            map:entry("id", ft:field($object, $object-type||"---id")),
            map:entry("absolute-resource-id", ft:field($object, $object-type||"---absolute-resource-id")),
            map:entry("object-type", $object-def/@xml:id/string()),
            map:entry("labels", array {(ft:field($object, $object-type||"---label") )}),
            map:entry("label", if (count(ft:field($object, $object-type||"---label")) > 0) then ft:field($object, $object-type||"---label")[1] else "<no-label-found>"),
            map:entry("score", 0.0)
        ))
};

declare function edwebapi:eval-filters-for-object(
    $object-def as node(),
    $object as map(*),
    $object-xml as node(),
    $relations-map as map(*)?
) as map(*)
{
    let $object-type := $object-def/@xml:id/string()
    return
        map:merge((
            map:entry("filter", map:merge((
                    map:entry("id", array { $object?id }),
                    for $filter in $object-def/appconf:filters/appconf:filter[not(@type='relation')]
                    return
                        map:entry(string($filter/@xml:id), array { ft:field($object-xml, $object-type||"---"||$filter/@xml:id) ! (if (. != "") then . else ())} ),
                    for $relation-filter in $object-def/appconf:filters/appconf:filter[@type='relation'][appconf:relation/@id = map:keys($relations-map)]
                    return
                        map:entry(
                            $relation-filter/@xml:id/string(),
                            array {
                                $relations-map?($relation-filter/appconf:relation/@id/string())?($object?id)
                            }
                        )
                ))),
            map:entry("label-filter", map:merge((
                    for $f in $object-def/appconf:filters/appconf:filter[./appconf:root[@type = 'label']]
                    return 
                        map:entry(
                            $f/@xml:id/string(), 
                            map:merge((
                            for $fo in $object?labels?* 
                            return 
                                map:entry($fo, array {ft:field($object-xml, $object-type||"---label---"||$f/@xml:id/string()) ! substring-after(., $fo||"---") ! (if (. != "") then . else ())})
                            ))
                        )
                )))
        ))
};

(:~
 : The function retrieves objects from the data.
 :
 : @param $app-target the collection name where the app is installed, e.g. /db/apps/project.WEB
 : @param $object-type the xml:id of the object-type
 : @param $with-filters if false() no filter properties are included.
 : @return a map which contains "date-time", "type"="objects", "list" with an array of object
 : maps containing "id", "absolute-resource-id" "object-type", "label", "filter", "label-filter".
 :)
declare function edwebapi:get-object-list(
    $app-target as xs:string,
    $object-type as xs:string,
    $with-filters as xs:boolean,
    $cache as xs:string?
) as map(*) 
{
    let $cache-file-name := translate("get-object-list-"||$object-type||"-"||$with-filters||".json", '/','__')
    let $cache-map := edwebapi:map-from-cache($app-target, $cache-file-name, $cache)
    return if (exists($cache-map)) then $cache-map else

    let $object-type := string($object-type)
    let $config := edwebapi:get-config($app-target)
    let $object-def := $config//appconf:object[@xml:id=$object-type]
    let $namespaces :=
        for $ns in $object-def/appconf:item/appconf:namespace
        let $prefix := $ns/@id/string()
        let $namespace-uri := $ns/string()
        return util:declare-namespace($prefix, $namespace-uri)

    let $objects-xml := edwebapi:get-objects($app-target, $object-type)
    let $count := count($objects-xml)
    let $relations :=
        map:merge((
            if (not($with-filters))
            then ()
            else (
            for $f in $object-def/appconf:filters/appconf:filter[@type='relation']
            let $rel-type-name := $f/appconf:relation/@id/string()
            return
            map:entry(
                $rel-type-name,
                let $rel-perspective := $f/appconf:relation/@as/string()
                let $rel-target :=
                    switch($rel-perspective)
                    case "subject" return "object"
                    case "object" return "subject"
                    default return
                        error(xs:QName("edwebapi:get-object-list-002"),
                            "Invalid configuration parameter value, only 'subject' or 'object' allowed."
                        )
                for $r in edwebapi:get-relation-list($app-target, $rel-type-name, false(), $cache)?list?*
                return map:entry(
                    $r?($rel-perspective),
                    switch($f/appconf:label/string())
                    case "predicate" return $r?predicate
                    case "id" return $r?($rel-target)
                    case "id+predicate"
                    return $r?($rel-target)||"+"||$r?predicate
                    default return
                        error(xs:QName("edwebapi:get-object-list-003"),
                            "Invalid configuration parameter value, only 'id', 'predicate', and 'id+predicate' allowed."
                        )
                )
            ))
        ))

    let $objects :=
        for $object in $objects-xml
        let $object-map := edwebapi:eval-base-data-for-object($object-def, $object)
        let $filter-map := edwebapi:eval-filters-for-object($object-def, $object-map, $object, $relations)
        return
            map:entry(
                $object-map?id,
                map:merge((
                    $object-map,
                    $filter-map
                ))
            )

    let $filter :=
        map:merge((
            map:entry(
                "id",
                map:merge((
                        map:entry("id", "id"),
                        map:entry("name", "ID"),
                        map:entry("n", 0),
                        map:entry("type", "id"),
                        map:entry("depends", ""),
                        map:entry("xpath", $object-def/appconf:item/appconf:id),
                        map:entry(
                            "label-function", "function($string) { $string }"
                        )
                ))
            ),
            for $f at $pos in $object-def/appconf:filters/appconf:filter
            let $key := $f/@xml:id/string()
            return
                map:entry(
                    $key, 
                    map:merge((
                        map:entry("id", $key),
                        map:entry("name", $f/appconf:name/string()),
                        map:entry("n", $pos),
                        map:entry("type", $f/appconf:type/string()),
                        map:entry("depends", $f/@depends/string()),
                        map:entry("xpath", $f/appconf:xpath/string()),
                        map:entry(
                            "label-function", 
                            $f/appconf:label-function[@type='xquery']/normalize-space()
                        ),
                        if (not($f/appconf:type/string() = ("id", "string")))
                        then
                            map:entry("values", array { map:merge(( $objects ))?*?("filter")?($key)?* => distinct-values() => functx:sort() } )
                        else ()
                    ))
                )
        ))

    let $map :=
        map:merge((
            map:entry("date-time", current-dateTime()),
            map:entry("type", "objects"),
            map:entry("filter", $filter),
            map:entry("results-found", $count),
            map:entry("list", map:merge(( $objects )) )
        ))
    let $store := edwebapi:save-to-cache($app-target, $cache-file-name, $map, $cache)
    return $map

};

declare function edwebapi:get-object-list-with-search(
    $object-list as map(*),
    $app-target as xs:string,
    $object-type as xs:string,
    $search-xpath as xs:string?,
    $kwic-width as xs:string?,
    $search-query as xs:string?,
    $search-type as xs:string?,
    $slop as xs:string?
) as map(*)
{
    let $config := edwebapi:get-config($app-target)
    let $object-type := string($object-type)
    let $object-def := $config//appconf:object[@xml:id=$object-type]
    let $namespaces :=
        for $ns in $object-def/appconf:item/appconf:namespace
        let $prefix := $ns/@id/string()
        let $namespace-uri := $ns/string()
        return util:declare-namespace($prefix, $namespace-uri)
    let $objects-xml := edwebapi:get-objects($app-target, $object-type)
    let $kwic-width := 
        if ($kwic-width||"" = "")
        then "30"
        else $kwic-width
    let $search-xpath :=
        if ($search-xpath eq ".")
        then "("||string-join($object-def/appconf:lucene/appconf:text/@qname/string(), "|")||")"
        else $search-xpath
    let $query := edwebapi:build-search-query($search-query, $search-type, $slop)

    let $objects-xml := 
        if ($search-xpath||$search-query||"" != "")
        then
            let $init-indices := local:init-search-indices($app-target)
            return
                util:eval("$objects-xml[ft:query(.//"||$search-xpath||", $query)]")
        else $objects-xml
    let $object-id := $object-def/appconf:item/appconf:id/string()
    let $list := $object-list?list
    let $query-function := ".//"||$search-xpath||"[ft:query(., $query)]"  
    let $list :=
        for $object in $objects-xml
        let $id := string(util:eval-inline($object,$object-id))
        let $object-map := $list?($id)
        let $search-score := 
            if ($search-xpath||$search-query||"" != "")
            then ft:score($object)
            else 0.0
        let $search-hits := 
            if ($search-xpath||$search-query||"" != "")
            then util:eval-inline($object, $query-function)
            else ()
        return
            map:entry(
                $id,
                map:merge ((
                    $object-map,
                    map:entry(
                        "search-results",
                        if ($search-type = 'distance')
                        then ()
                        else if ($search-type = 'distance-all-matches')
                        then
                            let $wg1 := substring-before($search-query, '~')
                            let $wg2 := substring-after($search-query, '~')
                            return
                                let $query := "(("||$wg1||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg2||"))|(("||$wg2||")\S*(\s+\S+){1,"||$slop||"}?\s+("||$wg1||"))"
                                let $matches := functx:get-matches(normalize-space($object), $query)
                                return for $match in $matches
                                let $m-1 := functx:get-matches($match, $query)[1]
                                return
                                map:merge ((
                                    map:entry("keyword-1", substring-before($m-1, " ")),
                                    map:entry("context", $m-1),
                                    map:entry("keyword-2", functx:substring-after-last($m-1, " "))
                                ))
                        else
                        for $hit in $search-hits
                        let $kwic := kwic:summarize($hit, <config width="{$kwic-width}"/>)
                        (: TODO delete following line? :)
                        for $item at $pos in $kwic
                        return 
                            map:merge ((
                                map:entry("context-previous", $kwic[$pos]/span[@class='previous']/string()),
                                map:entry("keyword", $kwic[$pos]/span[@class='hi']/string()),
                                map:entry("context-following", $kwic[$pos]/span[@class='following']/string()),
                                map:entry("score", ft:score($hit))
                            ))
                    ),
                    map:entry("score", $search-score)
                ))
            )
    let $list := map:merge($list)
    let $object-list :=
        map:put($object-list, "list", $list)
    return $object-list
};

declare function local:get-matches($string as xs:string?, $regex as xs:string) as xs:string* {
   if (matches($string, $regex))
   then (
      let $match := replace($string, '^.*?('||$regex||').*', '$1')
      return (
         $match
         (: , :)
         (: local:get-matches(replace($string, '^.*?'||$match, ''), $regex) :)
      )
   )
   else ()
};

(:~
 : Retrieves a list of objects.
 :
 : @param $data-collection the path to the project data collection
 : @param $collection the path to the collection relative to the project data collection
 : @param $root a xpath expression to the object root.
 : @return a list of nodes.
 :)
declare function edwebapi:get-objects(
    $app-target as xs:string,
    $object-type as xs:string
) as node()*
{
    let $init-indices := local:init-search-indices($app-target)
    let $data-collection := edwebapi:data-collection($app-target)
    let $config := edwebapi:get-config($app-target)
    let $object-def := $config//appconf:object[@xml:id=$object-type]
    let $collection := $object-def/appconf:collection
    let $root := $object-def/appconf:item/appconf:root
    let $filters := $object-def/appconf:filters/appconf:filter/@xml:id/string()
    return
    if (xmldb:collection-available($data-collection||$collection))
    then
        util:eval("collection($data-collection||$collection)//"||$root||
        "[ft:query(.,'objecttype---"||$object-type||":true', map { 'fields': ('"||string-join(($object-type||'---id',$object-type||'---absolute-resource-id',$object-type||'---label', for $f in $filters return $object-type||"---"||$f, for $f in $object-def/appconf:filters/appconf:filter[./appconf:root[@type = 'label']]/@xml:id/string() return $object-type||"---label---"||$f), "','")||"') })]")
    else if (doc-available($data-collection||$collection))
    then
        util:eval("doc($data-collection||$collection)//"||$root||"[ft:query(.,(), map { 'fields': ('"||string-join(('id','absolute-resource-id','label', $filters), "','")||"') })]")
    else
        error(xs:QName("edwebapi:get-objects-002"), "Can't find collection or resource. data-collection: "
        ||$data-collection||", collection/resource: "||$collection)
};

(:~
 : Make fulltext index search
 :
 : @return map with search results
 :)
declare function edwebapi:get-search-results(
    $app-target as xs:string,
    $search-id as xs:string,
    $kwic-width as xs:string?,
    $search-query as xs:string,
    $search-type as xs:string?,
    $slop as xs:string?,
    $limit as xs:string?,
    $cache as xs:string?
) as map(*) 
{
    let $init-indices := local:init-search-indices($app-target)

    let $config := edwebapi:get-config($app-target)
    let $data-collection := edwebapi:data-collection($app-target)


    let $search-config := $config//appconf:search[@xml:id=$search-id]
    let $search-config := 
        if (empty($search-config)) 
        then error(xs:QName("edwebapi:get-search-results-001"), "There is no search object configured with the ID '" || $search-id || "'.")
        else $search-config

    let $objects :=
        for $target in $search-config//appconf:target
        
        let $object-type := $target/@object/string()
        let $search-xpath := $target/@xpath/string()

        (: Get object list with search :)
        let $object-list := edwebapi:get-object-list($app-target, $object-type, true(), $cache)
        return 
            edwebapi:get-object-list-with-search(
                $object-list, 
                $app-target, 
                $object-type, 
                $search-xpath, 
                $kwic-width, 
                $search-query,
                $search-type,
                $slop
            )?list?*

    let $objects :=
        for $object in $objects
        let $score as xs:float := $object?score
        order by $score descending
        return $object
    return
        map:merge ((
            map:entry("date-time", current-dateTime()),
            map:entry("type", "search"),
            map:entry("id", $search-id),
            map:entry("query", $search-query),
            map:entry("kwic-width", $kwic-width),
            map:entry("list", $objects)
        ))
};

(:~
 :
 :)
declare function edwebapi:order-items(
    $list as map(*)*,
    $order as xs:string?,
    $order-modifier as xs:string?
) as map(*)*
{
    if (not($order eq 'label'))
    then
        if (not($order-modifier = "descending")) then
            for $item in $list
            order by $item?filter?($order)?1
            return $item
        else
            for $item in $list
            order by $item?filter?($order)?1 descending
            return $item
    else
        let $long-list :=
            for $item in $list
            return
                for $label at $pos in $item?labels?* 
                return
                    map:merge((
                        $item,
                        map:entry(
                            "filter",
                            map:merge((
                                $item?filter,
                                map:merge((
                                    for $fk in map:keys($item?label-filter) return
                                        map:entry($fk, $item?label-filter?($fk)?*[$pos])
                                ))
                            ))
                        ),
                        map:entry("label-pos",$pos),
                        map:entry("label", $label)
                    )) 
        return
            if (not($order-modifier = "descending")) then
                for $item in $long-list
                order by $item?label
                return $item
            else
                for $item in $long-list
                order by $item?label descending
                return $item
};

(:~
 :
 :)
declare function local:get-part-map(
    $part as node(), 
    $prefix as xs:string, 
    $prepath as xs:string, 
    $separator as xs:string, 
    $depends as xs:string
) 
{
    let $xmlid := $part/@xml:id/string()
    let $part-prefix :=
        concat(
            if ($prepath != "") 
            then $prepath||$separator 
            else "",
            
            if ($part/@starts-with) 
            then $part/@starts-with||$prefix 
            else ""
        )
    let $root := $part/appconf:root/string()
    let $id := $part/appconf:id/string()
    let $parts := $part/appconf:part
    let $path := $part-prefix||"<"||$xmlid||">"
    return 
        (
            map:entry(
                $xmlid, 
                map:merge((
                    map:entry("xmlid", $xmlid),
                    map:entry("path", $path),
                    map:entry("root", $root),
                    map:entry("id", $id),
                    map:entry("depends", $depends)
                ))
            ),
            if (count($parts) > 0) 
            then
                for $p in $parts
                return local:get-part-map($p, $prefix, $path, $separator, $xmlid)
            else ()
        )
};

(:~
 : Retrieves relation triples from the data.
 :
 : @param $app-target the collection name where the app is installed, e.g. /db/apps/project.WEB
 : @param $relation-type-name the xml:id of the relation-type
 : @return a map which contains "date-time", "type"="relations", "subject-type", "object-type",
 : "name", "list" with an array of relation maps containing "subject", "object" "predicate".
 :)
declare function edwebapi:get-relation-list(
    $app-target as xs:string,
    $relation-type-name as xs:string,
    $show-full as xs:boolean,
    $cache as xs:string?
) as map(*)
{
    let $cache-file-name := translate("get-relation-list-"||$relation-type-name||"-"||$show-full||".json", '/','__')
    let $cache-map := edwebapi:map-from-cache($app-target, $cache-file-name, $cache)
    return if (exists($cache-map)) then $cache-map else

    let $config := edwebapi:get-config($app-target)
    let $relation-type := $config//appconf:relation[@xml:id=$relation-type-name]
    let $subject-type := $relation-type/@subject/string()
    let $object-type := $relation-type/@object/string()
    let $collection := $relation-type/appconf:collection
    let $root := $relation-type/appconf:item/appconf:root
    let $name := $relation-type/appconf:name/string()
    let $namespaces :=
        for $ns in $relation-type/appconf:item/appconf:namespace
            let $prefix := $ns/@id/string()
            let $namespace-uri := $ns/string()
            return util:declare-namespace($prefix, $namespace-uri)

    let $objects :=
        let $map := edwebapi:get-object-list($app-target, $object-type, false(), $cache)
        return
        map:merge ((
            if ($relation-type/appconf:object-condition/@type = "resource")
            then $map?list?* ! map:entry(.?absolute-resource-id, .)
            else if ($relation-type/appconf:object-condition/@type = "id")
            then $map?list
            else if ($relation-type/appconf:object-condition/@type = "id-type")
            then
                for $object in $map?list?*
                return for $filter in $object?filter?($relation-type/appconf:object-condition/@filter)?*
                return map:entry($filter, $object)
            else $map?list
        ))

    let $subjects :=
        let $map := edwebapi:get-object-list($app-target, $subject-type, false(), $cache)
        return
        map:merge ((
            if ($relation-type/appconf:subject-condition/@type = "resource")
            then $map?list?* ! map:entry(.?absolute-resource-id, .)
            else if ($relation-type/appconf:subject-condition/@type = "id")
            then $map?list
            else if ($relation-type/appconf:subject-condition/@type = "id-type")
            then
                for $subject in $map?list?*
                return for $filter in $subject?filter?($relation-type/appconf:subject-condition/@filter)?*
                return map:entry($filter, $subject)
            else $map?list
        ))
    let $data-collection := edwebapi:data-collection($app-target)
    let $relations :=
        if (xmldb:collection-available($data-collection||$collection))
        then
            util:eval("collection($data-collection||$collection)//"||$root
            ||"[ft:query(.,'relationtype---"||$relation-type-name||":true', map { 'fields': ('"||$relation-type-name||"---absolute-resource-id','"||$relation-type-name||"---internal-node-id','"||$relation-type-name||"---object','"||$relation-type-name||"---subject','"||$relation-type-name||"---label') })]"
            )
        else if (doc-available($data-collection||$collection))
        then
            util:eval("doc($data-collection||$collection)//"||$root)
        else
            error(xs:QName("edwebapi:get-objects-002"), "Can't find collection or resource. data-collection: "
            ||$data-collection||", collection/resource: "||$collection)

    let $relations :=
        for $rel in $relations
        let $subject :=
            if (exists($relation-type/appconf:subject-condition/@type))
            then
                let $key := ft:field($rel, $relation-type-name||"---subject")
                return
                    if ($show-full)
                    then $subjects?($key)
                    else $subjects?($key)?id
            else ("")
        let $object :=
            if (exists($relation-type/appconf:object-condition/@type))
            then
                let $key :=
                    ft:field($rel, $relation-type-name||"---object")
                return
                    if ($show-full)
                    then $objects?($key)
                    else $objects?($key)?id
            else ("")
        let $predicate := ft:field($rel, $relation-type-name||"---label")
        return
        if (not(exists($subject)) or not(exists($object)) or not(exists($predicate)))
        then ()
        else
            map:merge((
                map:entry("xml", serialize($rel)),
                map:entry("internal-node-id", ft:field($rel, $relation-type-name||"---internal-node-id")),
                map:entry("absolute-resource-id", ft:field($rel, $relation-type-name||"---absolute-resource-id")),
                map:entry("subject", $subject),
                map:entry("object", $object),
                map:entry( "predicate", $predicate)
            ))

    let $relations :=
            if (exists($relation-type/appconf:subject-condition/@type))
            then $relations
            else
                let $subject-function := util:eval($relation-type/appconf:subject-condition)
                for $r in $relations
                let $subject :=
                    for $s in $subjects?*
                    where $subject-function($r, $s)
                    return $s
                return
                    if (not(exists($subject)))
                    then ()
                    else
                        map:put($r, "subject",
                            if ($show-full)
                            then $subject
                            else $subject?id
                        )
    let $relations :=
            if (exists($relation-type/appconf:object-condition/@type))
            then $relations
            else
                let $object-function := util:eval($relation-type/appconf:object-condition)
                for $r in $relations
                let $object :=
                    for $o in $objects?*
                    where $object-function($r, $o)
                    return $o
                return
                    if (not(exists($object)))
                    then ()
                    else
                        map:put($r, "object",
                            if ($show-full)
                            then $object
                            else $object?id
                        )
    let $map :=
        map:merge((
            map:entry("date-time", string(current-dateTime())),
            map:entry("type", "relations"),
            map:entry("subject-type", $subject-type),
            map:entry("object-type", $object-type),
            map:entry("name", $name),
            map:entry("results-found", count($relations)),
            map:entry("list",  array { $relations } )
        ))

    let $store := edwebapi:save-to-cache($app-target, $cache-file-name, $map, $cache)
    return $map
};

(:~
 : Reads the path of the data collection from the appconf.xml.
 :
 : @param $app-target the collection name where the app is installed, e.g. /db/apps/project.WEB
 : @return the path of the data collection
 :)
declare function edwebapi:data-collection(
    $app-target as xs:string
) as xs:string
{
    let $config := edwebapi:get-config($app-target)
    let $path := $config//appconf:project/appconf:collection/normalize-space()
    return 
        if (starts-with($path, '/'))
        then $path
        else $app-target||"/"||$path
};

(:~
 : Creates new collection of indefinite depth recursively
 :
 : @param $path the path to the collection to be created
 : @return null
 :)
declare function local:create-collection-from-path(
    $path as xs:string
) 
{
    let $collection-path := functx:substring-before-last($path, "/")
    let $new-collection := functx:substring-after-last($path, "/")
    return
        if (not(xmldb:collection-available($collection-path)))
        then (
            local:create-collection-from-path($collection-path),
            xmldb:create-collection($collection-path, $new-collection)
        )
        else xmldb:create-collection($collection-path, $new-collection)
};

(:~
 : Updates collection configurations for search indices or creates new ones
 : where none are found.
 :)
declare function local:init-search-indices(
    $app-target as xs:string
)
{
    let $config := edwebapi:get-config($app-target)
    let $data-collection := edwebapi:data-collection($app-target)
    let $collections := distinct-values($config//(appconf:object|appconf:relation)/appconf:collection/string())
    (: let $xconf-root := 'xmldb:exist:///db/system/config' :)
    let $xconf-root := '/db/system/config'
    let $xconf-ns := "http://exist-db.org/collection-config/1.0"

    for $collection in $collections
    let $xconf-collection := $xconf-root || $data-collection || $collection
    (: Security check, because files only should be created within xconf-root.  :)
    where not($xconf-collection => contains('..'))
    return
    let $xconf-path := $xconf-collection ||'/collection.xconf'

    let $objects := $config//appconf:object[appconf:collection = $collection]

    let $relations := $config//appconf:relation[appconf:collection = $collection]

    let $lucene-index :=
        for $obj in $objects[appconf:lucene]
        return $obj/appconf:lucene/functx:change-element-ns-deep(., $xconf-ns, '')

    let $xconf :=

<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:util="http://exist-db.org/xquery/util" xmlns:tei="http://www.tei-c.org/ns/1.0">
    {
        for $namespace in $config//(appconf:object[appconf:collection = $collection]|appconf:relation[appconf:collection = $collection])/appconf:item/appconf:namespace
        let $prefix := $namespace/@id/string()
        group by $prefix
        return
            namespace {$prefix} {string($namespace[1])}
    }
        <fulltext default="none" attributes="false"/>
        <lucene>
        {   for $root in distinct-values(($objects/appconf:item/appconf:root, $relations/appconf:item/appconf:root))
            return
            <text qname="{$root}">
            {
            for $object-def in $objects[appconf:item/appconf:root = $root]
            let $object-type := $object-def/@xml:id/string()
            return
            (
                <field name="objecttype---{$object-type}" expression="{
                    if ($object-def/appconf:item/appconf:condition)
                    then 'not(not('||$object-def/appconf:item/appconf:condition||'))'
                    else 'true()'
                }"/>
                ,
                <field name="{$object-type}---id" expression="{$object-def/appconf:item/appconf:id/string()}" />
                ,
                    let $expression := 
                        if ($object-def/appconf:item/appconf:label[@type='xpath'])
                        then
                            $object-def/appconf:item/appconf:label[@type='xpath']
                        else if ($object-def/appconf:item/appconf:label[@type='xquery'])
                        then
                            "let $f := "||$object-def/appconf:item/appconf:label[@type='xquery']||" return $f(.)"
                        else ('<no-label-function-defined>')
                    return 
                        <field name="{$object-type}---label" expression="{$expression}"/>
                ,
                <field name="{$object-type}---absolute-resource-id" expression="util:absolute-resource-id(.)"/>
                ,
                    for $filter in $object-def/appconf:filters/appconf:filter[not(appconf:root/@type='label')]
                    let $expression := 
                        if ($filter/appconf:label-function[@type='xquery'])
                        then
                        "let $f := "||$filter/appconf:label-function[@type='xquery']||" for $node at $pos in "||$filter/appconf:xpath||" return $f($node)"
                        else $filter/appconf:xpath
                    return
                        <field name="{$object-type}---{$filter/@xml:id}" expression="{$expression}"/>
                ,
                    for $filter in $object-def/appconf:filters/appconf:filter[appconf:root/@type='label']
                    let $label-expression := 
                        if ($object-def/appconf:item/appconf:label[@type='xpath'])

                        then
                            $object-def/appconf:item/appconf:label[@type='xpath']
                        else if ($object-def/appconf:item/appconf:label[@type='xquery'])
                        then
                            "let $f := "||$object-def/appconf:item/appconf:label[@type='xquery']||" return $f(.)"
                        else ('<no-label-function-defined>')
                    let $expression := 
                        if ($filter/appconf:label-function[@type='xquery'])
                        then
                        "let $f := "||$filter/appconf:label-function[@type='xquery']||" for $node at $pos in "||$label-expression||" return $f($node)"
                        else $filter/appconf:xpath
                    return
                        <field name="{$object-type}---{$filter/@xml:id}" expression="{$expression}"/>
                ,
                    for $filter in $object-def/appconf:filters/appconf:filter[appconf:root/@type='label']
                    let $label-expression := 
                        if ($object-def/appconf:item/appconf:label[@type='xpath'])

                        then
                            $object-def/appconf:item/appconf:label[@type='xpath']
                        else if ($object-def/appconf:item/appconf:label[@type='xquery'])
                        then
                            "let $f := "||$object-def/appconf:item/appconf:label[@type='xquery']||" return $f(.)"
                        else ('<no-label-function-defined>')
                    let $expression := 
                        if ($filter/appconf:label-function[@type='xquery'])
                        then
                        "let $f := "||$filter/appconf:label-function[@type='xquery']||" for $node at $pos in "||$label-expression||" return for $item in $f($node) return $node||'---'||$item"
                        else $filter/appconf:xpath
                    return
                        <field name="{$object-type}---label---{$filter/@xml:id}" expression="{$expression}"/>
            )}
            {
            for $relation-type in $relations[appconf:item/appconf:root = $root]
            let $relation-type-name := $relation-type/@xml:id/string()
            return
            (
                <field name="relationtype---{$relation-type-name}" expression="{
                    if ($relation-type/appconf:item/appconf:condition)
                    then 'not(not('||$relation-type/appconf:item/appconf:condition||'))'
                    else 'true()'
                }"/>,
                <field name="{$relation-type-name}---label" expression="{
                    if ($relation-type/appconf:item/appconf:label[@type='xpath'])
                        then
                            $relation-type/appconf:item/appconf:label[@type='xpath']
                        else if ($relation-type/appconf:item/appconf:label[@type='xquery'])
                        then
                            "let $f := "||$relation-type/appconf:item/appconf:label[@type='xquery']||" return $f(.)"
                        else ('<no-label-function-defined>')
                }"/>,
                <field name="{$relation-type-name}---absolute-resource-id" expression="util:absolute-resource-id(.)"/>,
                <field name="{$relation-type-name}---internal-node-id" expression="util:node-id(.)"/>,
                <field name="{$relation-type-name}---subject" expression="{
                    if ($relation-type/appconf:subject-condition/@type = "resource")
                    then "util:absolute-resource-id(.)"
                    else if ($relation-type/appconf:subject-condition/@type = "id")
                    then $relation-type/appconf:subject-condition
                    else if ($relation-type/appconf:subject-condition/@type = "id-type")
                    then $relation-type/appconf:subject-condition
                    else ()
                }"/>,
                <field name="{$relation-type-name}---object" expression="{
                    if ($relation-type/appconf:object-condition/@type = "resource")
                    then "util:absolute-resource-id(.)"
                    else if ($relation-type/appconf:object-condition/@type = "id")
                    then $relation-type/appconf:object-condition
                    else if ($relation-type/appconf:object-condition/@type = "id-type")
                    then $relation-type/appconf:object-condition
                    else ()
                }"/>
            )}
            </text>
        }
            {$lucene-index/(*:analyzer|*:text|*:inline|*:ignore)}
        </lucene>
    </index>
</collection>

    let $index-updated :=
        (: IF INDEX FOUND UPDATE INDEX :)
        if (exists(doc($xconf-path))) 
        then
            let $weed-out :=
                for $node in doc($xconf-path)//*:lucene/(*:text|*:analyzer|*:inline|*:ignore)
                where not(functx:is-node-in-sequence-deep-equal($node, $xconf//*:lucene/(*:text|*:analyzer|*:inline|*:ignore)))
                return true()
            let $insert-new :=
                let $old-index := doc($xconf-path)//*:lucene/(*:text|*:analyzer|*:inline|*:ignore)
                for $text in $xconf//*:lucene/(*:text|*:analyzer|*:inline|*:ignore)
                where not(functx:is-node-in-sequence-deep-equal($text, $old-index))
                return true()
            return (true() = ($weed-out, $insert-new, false()))
        (: IF INDEX NOT FOUND CREATE NEW INDEX :)
        else true()
    let $store-index :=
        if ($index-updated)
        then
            let $create-xconf-collection :=
                if (not(xmldb:collection-available($xconf-collection))) 
                then local:create-collection-from-path($xconf-collection)
                else ()
            return xmldb:store($xconf-collection, 'collection.xconf', $xconf)
        else ()
    return
        if ($index-updated)
        then xmldb:reindex($data-collection || $collection)
        else (false())
};
