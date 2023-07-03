xquery version "3.1";

import module namespace edwebapi="http://www.bbaw.de/telota/software/ediarum/web/api";
import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
            
(:
    Version 1.0 -- 7 Feb 2005 -- David Sewell
    Usage: The first two parameters are the starting and ending milestone elements in a
    document or document fragment. Example: $doc//pb[@n='1'], $doc//pb[@n='2'].
    The third parameter should initially be an element that is a parent or
    ancestor of all the milestones, like $doc//body or $doc//text. (This
    parameter is the only one that varies as the function is called
    recursively.)

    The function returns only a single node containing the content between the
    two milestones. To return, for example, all the pages in a book, call the
    function repeatedly by reiterating over every <pb>, where $ms2 will be
    either the following <pb> or, for the last one, the final node() in the
    document or document fragment.

    English-language explanation of the function operation:

    Test for node type. For an element, if it is (1) an ancestor or self of one
    of the two milestones, use the "element" function to return an element of
    the same name, with its content created by recursing over any child nodes. If
    it is (2) an element in between the two milestones, return the element. If
    it is (3) anything else, return null.  For an attribute node, return the
    entire attribute. For a text node, return it if it is between the
    milestones; otherwise return null.
 :)    
declare function local:milestone-chunk($ms1 as node(), $ms2 as node(), $node as node()) as node()* {
    typeswitch ($node)
        case element() return
            if ($node is $ms1) then
                $node
            else if (some $n in $node/descendant::* satisfies ($n is $ms1 or $n is $ms2)) then
                element {node-name($node)} {
                    for $i in ( $node/@* )
                        return local:milestone-chunk($ms1, $ms2, $i),
                    for $i in ( $node/node() )
                        return local:milestone-chunk($ms1, $ms2, $i)
                }
            else if ( $node >> $ms1 and $node << $ms2 ) then
                $node
            else ()
        case attribute() return
            attribute { name($node) } { data($node)  }
        default return
            if ( $node >> $ms1 and $node << $ms2 ) then 
                $node
            else ()
};

declare function local:milestone-chunk($ms1 as node(), $node as node()) as node()* {
    typeswitch ($node)
        case element() return
            if ($node is $ms1) then
                $node
            else if (some $n in $node/descendant::* satisfies ($n is $ms1)) then
                element {node-name($node)} {
                    for $i in ( $node/@* )
                        return local:milestone-chunk($ms1, $i),
                    for $i in ( $node/node() )
                        return local:milestone-chunk($ms1, $i)
                }
            else if ( $node >> $ms1) then
                $node
            else ()
        case attribute() return
            attribute { name($node) } { data($node)  }
        default return
            if ( $node >> $ms1) then 
                $node
            else ()
};

declare function local:get-part($map as map(*), $object as node(), $parts as node()+) {
    let $xmlid := $parts[1]/@key/string()
    let $root := $map?parts?($xmlid)?root
    let $id := $map?parts?($xmlid)?id
    let $value := $parts[1]/@value/string()
    let $xpath := ".//" || $root || "[" || $id || " eq '" || $value || "' ]"
    let $ms1 := util:eval-inline($object, $xpath)
    let $following-xpath := $xpath || "/following::" || $root || "[1]"
    let $ms2 := util:eval-inline($object, $following-xpath)
    let $chunk := 
        if ($ms2) then
            local:milestone-chunk($ms1, $ms2, $object)    
        else 
            local:milestone-chunk($ms1, $object)
    return
        if ($parts[2]) then 
            local:get-part($map, $chunk, subsequence($parts, 2))
        else
            $chunk
};

let $app-target := request:get-parameter("app-target", request:get-attribute("app-target"))
let $object-type := request:get-parameter("object-type", request:get-attribute("object-type"))
let $object-id := request:get-parameter("object-id", request:get-attribute("object-id"))
let $object-part := request:get-parameter("object-part", request:get-attribute("object-part"))


let $search-query := request:get-parameter("search", request:get-attribute("search"))
let $search-type := request:get-parameter("search-type", request:get-attribute("search-type"))
let $search-xpath := request:get-parameter("search-xpath", request:get-attribute("search-xpath"))

let $slop := request:get-parameter("slop", request:get-attribute("slop"))
let $kwic-width := request:get-parameter("kwic-width", request:get-attribute("kwic-width"))

let $map :=
    if ($search-query||"" != "")
    then
        edwebapi:get-object-with-search($app-target, $object-type, $object-id, (), $kwic-width, $search-xpath, $search-query, $search-type, $slop)
    else
        edwebapi:get-object($app-target, $object-type, $object-id)
let $object := $map("xml")

let $parts :=
    for $part in $map?parts?*
        let $path-pattern := $part?path
        let $matches := edwebcontroller:path-equals-pattern($object-part, $path-pattern, "[\w\d]+")
        return
            if ($matches) then (
                edwebcontroller:read-path-variables($object-part, $path-pattern, "[\w\d]+")
            ) else ()

return local:get-part($map, $object, $parts)


