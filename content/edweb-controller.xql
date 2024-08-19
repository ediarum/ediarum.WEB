xquery version "3.1";

(:~
 : The generalized functions for generating the content of ediarum.web.
 :)
module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";

(: import module namespace console="http://exist-db.org/xquery/console"; :)
import module namespace functx = "http://www.functx.com";

declare namespace appconf="http://www.bbaw.de/telota/software/ediarum/web/appconf";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace http="http://expath.org/ns/http-client";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace map="http://www.w3.org/2005/xpath-functions/map";

declare variable $edwebcontroller:controller := "/ediarum.web";
declare variable $edwebcontroller:edweb-path := "/db/apps/ediarum.web";
declare variable $edwebcontroller:allowed-pattern-chars := "[.@:_\-\p{L}0-9]+";

(:~
 : This function implements the routing for the api.
 :
 : @param $function two functions are allowed: local:api-get-from-pattern and 
 :        local:generate-api-path
 : @param $params the params for the views
 :
 :)
declare function local:api-routing(
    $function as xs:string, 
    $params as xs:string?
) as item()*
{
    let $f := function-lookup(xs:QName($function), 3)
    return (
        if (request:get-parameter("id", request:get-attribute("id"))||"" != "") 
        then $f("/api", "api/all-list.xql", $params)
        else if (request:get-parameter("id-type", request:get-attribute("id-type"))||"" != "") 
        then $f("/api", "api/all-list.xql", $params)
        else $f("/api", "api/show-config.xql", $params),

        (: Search:)
        $f("/api/search/<search-id>", "api/search.xql", $params),

        (: List objects and relations :)
        $f("/api/<object-type>", "api/object-list.xql", $params),

        (: Get the object as XML :)
        if (request:get-parameter("output", request:get-attribute("output")) eq 'xml') 
        then $f("/api/<object-type>/<object-id>", "api/object-xml.xql", $params)
        (: Get the object as HTML :)
        else if (request:get-parameter("output", request:get-attribute("output")) eq 'html') 
        then $f("/api/<object-type>/<object-id>", "api/object-html.xql", $params)
        (: Get the object as Text :)
        else if (request:get-parameter("output", request:get-attribute("output")) eq 'text') 
        then $f("/api/<object-type>/<object-id>", "api/object-text.xql", $params)
        (: Get object information as JSON :)
        else $f("/api/<object-type>/<object-id>", "api/object-json.xql", $params),

        (: Get a part of the object as XML :)
        $f("/api/<object-type>/<object-id>/<object-part>", "api/object-part.xql", $params)
    )
};

(:~
 : This function gets the results of an API request without sending an http request but using
 : directly the API xqueries. All query parameters are set as request:attributes. See also 
 : edwebcontroller:generate-api().
 :
 : @param $api-path the uri part of the api, e.g. /api/letters?show=list.
 : @return the result of the API request as xml, json or text.
 :)
declare function edwebcontroller:api-get(
    $api-path as xs:string
) as item()*
{
    try {
        (: console:log("api-get","Request: "||$api-path) :)
        (: , :)
        let $store-attributes := 
            for $att in request:attribute-names()
            let $value := request:get-attribute($att)
            where not(contains($att, "exist"))
            return (
                (: console:log("Before: "||$att||":"||$value), :)
                map:entry($att, $value),
    	        request:set-attribute($att, "")
            )
        let $store-attributes := map:merge( $store-attributes )
        let $result := (
            (: app-target :)
            request:set-attribute(
                "app-target", 
                substring-after(edwebcontroller:get-exist-root(), "xmldb:exist://")
                    ||edwebcontroller:get-exist-controller()
            )
            ,
            (: get-params :)
            for $param in tokenize(substring-after($api-path, "?"), "&amp;")
            return 
                request:set-attribute(substring-before($param, "="), substring-after($param, "="))
            ,
            local:api-routing("local:api-get-from-pattern", $api-path)
        )
        return (
            (: restore-attributes :)
            map:for-each($store-attributes, function ($key as xs:string, $value as xs:string) {
                (: console:log("After: "||$key||":"||$value), :)
                request:set-attribute($key, $value)
            })
            ,
            $result
        )
    } catch * {
        error(xs:QName("edwebcontroller:api-get-001"), "Error with the api request: "||$api-path)
    }
};

(:~
 :
 :)
declare function local:api-get-from-pattern(
    $api-pattern as xs:string, 
    $xquery as xs:string, 
    $api-path as xs:string
) as item()*
{
    let $allowed-pattern-chars := $edwebcontroller:allowed-pattern-chars
    let $path := 
        if (contains($api-path, "?")) 
        then substring-before($api-path, "?") 
        else $api-path
    let $get-params := substring-after($api-path, "?")
    return
        if (edwebcontroller:path-equals-pattern($path, $api-pattern, $allowed-pattern-chars)) 
        then (
            (: params :)
            for $att in edwebcontroller:read-path-variables(
                $api-path,
                $api-pattern,
                $allowed-pattern-chars
            )
            let $att-name := $att/@key/string()
            let $att-value := $att/@value/string()
            return request:set-attribute($att-name, $att-value)
            ,
            for $att in tokenize($get-params, "&amp;")
            let $att-name := substring-before($att, "=")
            let $att-value := substring-after($att, "=")
            return request:set-attribute($att-name, $att-value)
            ,
            let $uri-string := $edwebcontroller:edweb-path||"/views/"||$xquery||"?"||$get-params
            let $result := util:eval(xs:anyURI($uri-string), false())
            return (
                (: clear-query-atts :)
                for $att in tokenize($get-params, "&amp;")
                let $att-name := substring-before($att, "=")
                return request:set-attribute($att-name, "")
                ,
                $result
            )
        )
        else ()
};

declare function edwebcontroller:base-url(
) as xs:string
{
    substring-before(request:get-uri(), edwebcontroller:get-exist-controller())
                ||edwebcontroller:get-exist-controller()
};

(:~
 : This function activates the API paths and is used in a controller.xql. Every API http request is 
 : forwarded to ediarum.WEB and the results are returned. It uses the path and query paramters of
 : the http request, e.g. /api/letters?show=list. See also edwebcontroller:api-get().
 :
 : @return the result of the API request as xml, json or text.
 :)
declare function edwebcontroller:generate-api(
) as item()*
{
    (: request:set-attribute("project", edwebcontroller:get-project()), :)
    request:set-attribute(
        "app-target", 
        substring-after(edwebcontroller:get-exist-root(), "xmldb:exist://")
            ||edwebcontroller:get-exist-controller()
    ),
    local:api-routing("local:generate-api-path", ())
};

(:~
 :
 :)
declare function local:generate-api-path(
    $path-pattern as xs:string, 
    $view as xs:string, 
    $params as xs:string?
) as item()*
{ 
    local:generate-api-path(
        $path-pattern, 
        $view, 
        edwebcontroller:is-pass-through(), 
        edwebcontroller:get-exist-path()
    ) 
};

(:~
 :
 :)
declare
    %test:args("/api/<object-type>/<object-id>/<object-part>", "part.xml", "true", "/api/") 
    %test:assertEmpty
    
    %test:args(
        "/api/<object-type>/<object-id>/<object-part>", 
        "api/part.xml", 
        "true", 
        "/api/ObjectType/ID/PART"
    ) 
    %test:assertEquals(
        '<dispatch xmlns="http://exist.sourceforge.net/NS/exist"><forward url="/ediarum.web/views/api/part.xml"><set-attribute name="object-type" value="ObjectType"/><set-attribute name="object-id" value="ID"/><set-attribute name="object-part" value="PART"/></forward></dispatch>'
    )

    %test:args(
        "/api/<object-type>/<object-id>/<object-part>",
        "api/part.xml", 
        "true", 
        "/api/ObjectType/ID/PART.SUBPART"
    ) 
    %test:assertEquals(
        '<dispatch xmlns="http://exist.sourceforge.net/NS/exist"><forward url="/ediarum.web/views/api/part.xml"><set-attribute name="object-type" value="ObjectType"/><set-attribute name="object-id" value="ID"/><set-attribute name="object-part" value="PART.SUBPART"/></forward></dispatch>'
    )

    %test:args(
        "/api/<object-type>/<object-id>/<object-part>",
        "api/<object-type>.xml", 
        "true", 
        "/api/ObjectType/ID/PART.SUBPART"
    ) 
    %test:assertEquals(
        '<dispatch xmlns="http://exist.sourceforge.net/NS/exist"><forward url="/ediarum.web/views/api/ObjectType.xml"><set-attribute name="object-type" value="ObjectType"/><set-attribute name="object-id" value="ID"/><set-attribute name="object-part" value="PART.SUBPART"/></forward></dispatch>'
    )

    %test:args(
        "/api/<object-type>/<object-id>", 
        "api/object-json.xql", 
        "true", 
        "/api/handschriften/diktyon-71816"
    )
    %test:assertEquals(
        '<dispatch xmlns="http://exist.sourceforge.net/NS/exist"><forward url="/ediarum.web/views/api/object-json.xql"><set-attribute name="object-type" value="handschriften"/><set-attribute name="object-id" value="diktyon-71816"/></forward></dispatch>'
    )

    %test:args(
        "/api/<object-type>/<object-id>",
        "api/object-json.xql",
        "true",
        "/api/urn:cts:myproject/my-file:with.dot"
    )
    %test:assertEquals(
        '<dispatch xmlns="http://exist.sourceforge.net/NS/exist"><forward url="/ediarum.web/views/api/object-json.xql"><set-attribute name="object-type" value="urn:cts:myproject"/><set-attribute name="object-id" value="my-file:with.dot"/></forward></dispatch>'
    )
    (: TODO: weiteren Zugang legen nach DTS Spezi :)
    (: %test:args(
        "/api/document/?id=<object-id>",
        "api/object-json.xql",
        "true",
        "/api/document/?id=https://papyri.info/ddbdp/bgu;11;2029/source"
    ) :)
function local:generate-api-path(
    $path-pattern as xs:string, 
    $view as xs:string, 
    $is-pass-through as xs:boolean, 
    $exist-path as xs:string
) as item()*
{
    edwebcontroller:generate-path(
        $path-pattern, 
        $view, 
        $is-pass-through, 
        $exist-path, 
        $edwebcontroller:controller, 
        false()
    )
};

(:~
 :
 :)
declare function edwebcontroller:generate-path(
    $path-pattern as xs:string, 
    $view as xs:string
) as item()*
{
    edwebcontroller:generate-path(
        $path-pattern,
        $view,
        edwebcontroller:is-pass-through(),
        edwebcontroller:get-exist-path(),
        edwebcontroller:get-exist-controller(),
        true()
    )
};

(:~
 :
 :)
declare function edwebcontroller:generate-path(
    $path-pattern as xs:string, 
    $view as xs:string, 
    $is-pass-through as xs:boolean, 
    $exist-path as xs:string, 
    $controller as xs:string, 
    $as-view as xs:boolean
) as item()*
{
    let $allowed-pattern-chars := $edwebcontroller:allowed-pattern-chars
    let $exist-path := xmldb:decode($exist-path)
        (: if ($exist-path||"" != "")
        then error(xs:QName("edwebcontroller"), $exist-path)
        else $exist-path :)
    return
    if (
        $is-pass-through 
        and 
        edwebcontroller:path-equals-pattern($exist-path, $path-pattern, $allowed-pattern-chars)
    ) 
    then (
        local:set-pass-through-false()
        ,
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            { local:set-pass-through-false() }
            <forward url="{$controller}/views/{
                local:get-view-path(
                    $view, 
                    edwebcontroller:read-path-variables(
                        $exist-path, 
                        $path-pattern, 
                        $allowed-pattern-chars
                    )
                )
            }"> { 
                    for $att in 
                        edwebcontroller:read-path-variables(
                            $exist-path, 
                            $path-pattern, 
                            $allowed-pattern-chars
                        )
                    let $att-name := $att/@key/string()
                    let $att-value := $att/@value/string()
                    return
                        <set-attribute name="{$att-name}" value="{$att-value}"/>
                }
                { for $att in request:attribute-names()
                    let $att-value := request:get-attribute($att)
                    return
                        <set-attribute name="{$att}" value="{$att-value}"/>
                }
                </forward>
            {   
                if ($as-view) 
                then
                    <view>
                        <forward url="{$controller}/modules/view.xql"/>
                    </view>
                else ()
            }
        </dispatch>
    )
    else ()
};

(:~
 :
 :)
declare function edwebcontroller:generate-routing(
    $list-page as xs:string,
    $detail-page as xs:string
) as item()*
{
    if (starts-with(edwebcontroller:get-exist-path(), "/api"))
    then ()
    else
    let $object-types := edwebcontroller:api-get("/api")//appconf:object/@xml:id
    return
        for $object-type in $object-types
        return (
            edwebcontroller:view-with-feed(
                "/"||$object-type||"/index.html", 
                $list-page, 
                "object-type/"||$object-type
            ),
            edwebcontroller:view-with-feed(
                "/"||$object-type||"/", 
                $detail-page, 
                "object-type/"||$object-type||"/id/")
        )
};

(:~
 : Retrieves the project name from the request. TODO: To disable, change to app-target
 :
 : @return the project name.
 :)
(: declare function edwebcontroller:get-project(
) as xs:string 
{
    request:get-attribute("project")
}; :)

(:~
 :
 :)
declare function local:get-view-path(
    $view as xs:string, 
    $vars as node()*
) as xs:string 
{
    let $param-regex := "<([^>]+?)>"
    let $path-parts :=
        for $part in functx:get-matches-and-non-matches($view, $param-regex)
            return if ($part/self::non-match) then
                $part/string()
            else if ($part/self::match) then
                let $key := replace($part, $param-regex, "$1")
                return $vars[@key = $key]/@value/string()
            else ()
    return string-join(($path-parts), '')
};

(:~
 : Enables the API according to the CTS specifications, see
 : <https://github.com/cite-architecture/cts_spec/blob/master/md/specification.md>.
 : It must be used together with edwebcontroller:generate-api() in the
 : controller.xql.
 :
 :)
declare function edwebcontroller:include-cts-api(
    $cts-object-id-type as xs:string
) as item()*
{
    request:set-attribute("cts-object-id-type", $cts-object-id-type),
    edwebcontroller:generate-path("/api/cts", "api/cts.xql", edwebcontroller:is-pass-through(), edwebcontroller:get-exist-path(), $edwebcontroller:controller, false())
};

(:~
 : Sets request attributes for the exist variables of the current request.
 :
 : @param $exist-path
 : $param $exist-resource
 : @param $exist-controller
 : @param $exist-prefix
 : @param $exist-root 
 :)
declare function edwebcontroller:init-exist-variables(
    $exist-path as xs:string, 
    $exist-resource as xs:string, 
    $exist-controller as xs:string, 
    $exist-prefix as xs:string, 
    $exist-root as xs:string
) as item()*
{
    request:set-attribute("exist-path", $exist-path),
    request:set-attribute("exist-resource", $exist-resource),
    request:set-attribute("exist-controller", $exist-controller),
    request:set-attribute("exist-prefix", $exist-prefix),
    request:set-attribute("exist-root", $exist-root),
    local:set-pass-through-true()
};

(:~
 : Tests if the attribute "pass-through" is set to true. This attribute is used to mark if a 
 : routing command for the current request is set already.
 :)
declare function edwebcontroller:is-pass-through(
) as xs:boolean 
{
    request:get-attribute("pass-through") = "true"
};

(:~
 : Returns the $exist:controller variable from request. I.e.
 : The part of the URI leading to the current controller script. For example, if the request path 
 : is /xquery/test.xql and the controller is in the xquery directory, $exist:controller would 
 : contain /xquery.
 :)
declare function edwebcontroller:get-exist-controller(
) as xs:string 
{
    request:get-attribute("exist-controller")
};

(:
 : Returns the $exist:path variable from request. I.e.:
 : The last part of the request URI after the section leading to the controller. If the resource 
 : example.xml resides within the same directory as the controller query, $exist:path will be 
 : /example.xml.
 :)
declare function edwebcontroller:get-exist-path(
) as xs:string 
{
    request:get-attribute("exist-path")
};

(:~
 : Returns the $exist:prefix variable from request. I.e.
 : If the current controller hierarchy is mapped to a certain path prefix, $exist:prefix returns 
 : that prefix. For example, the default configuration maps the path /tools to a collection in the 
 : database (see below). In this case, $exist:prefix would contain /tools.
 :)
declare function edwebcontroller:get-exist-prefix(
) as xs:string 
{
    request:get-attribute("exist-prefix")
};

(:~
 : Returns the $exist:resource variable from request. I.e.
 : The section of the URI after the last /, usually pointing to a resource, e.g. example.xml.
 :)
declare function edwebcontroller:get-exist-resource(
) as xs:string 
{
    request:get-attribute("exist-resource")
};

(:~
 : Returns the $exist:root variable from request. Which is set by 
 : edwebcontroller:init-exist-variables. I.e.
 : The root of the current controller hierarchy. This may either point to the file system or to a 
 : collection in the database. Use this variable to locate resources relative to the root of the 
 : application. For example, assume you want to process a request through stylesheet db2xhtml.xsl, 
 : which could either be stored in the /stylesheets directory in the root of the webapp or - if the
 : app is running from within the db - the corresponding /stylesheets collection. You want your app
 : to be able to run from either location. The solution is to use exist:root.
 :)
declare function edwebcontroller:get-exist-root(
) as xs:string 
{
    if (request:get-attribute("exist-root")) 
    then request:get-attribute("exist-root")
    else "/db/apps"
};

(: Load media files ('css', 'js', 'svg', 'png', 'jpg'). Should be included in controller.xql to avoid loading times. Because otherwise not found resources are forwarded to the error page.
 :
 : @param $media-abbrev an individual media suffix can be added.
 :)
declare function edwebcontroller:load-media(
    $media-abbrev as xs:string?
) as item()*
{
    if (
        edwebcontroller:is-pass-through()
        and
        (
            matches(edwebcontroller:get-exist-path(), ".*\.(css|js|svg|png|jpg)")
            or
            ends-with(edwebcontroller:get-exist-path(), "."||$media-abbrev)
        )
    )
    then (
        local:set-pass-through-false()
        ,
       <dispatch xmlns="http://exist.sourceforge.net/NS/exist"></dispatch>
    )
    else ()
};

(:~
 : Forwards the request to a view and set a feed without id, e.g. "/texts/index.html"
 :
 : @param $object-type the object-type for which the view is set.
 : @param $view name of the view in the directory "/views/data-pages".
 :)
declare function edwebcontroller:object-view(
    $object-type as xs:string, 
    $view as xs:string
) as item()*
{
    edwebcontroller:view-with-feed(
        "/"||$object-type||"/index.html", 
        "data-pages/"||$view, 
        "object-type/"||$object-type
    )
};

(:~ 
 : Forwards the request to a view and sets a feed which retrieves the id from the URL. E.g. 
 : "/texts/id123".
 :
 : @param $object-type the object-type for which the view is set.
 : @param $view name of the view in the directory "/views/data-pages".
 :)
declare function edwebcontroller:object-detail-view(
    $object-type as xs:string, 
    $view as xs:string
) as item()*
{
    edwebcontroller:view-with-feed(
        "/"||$object-type||"/", 
        "data-pages/"||$view, 
        "object-type/"||$object-type||"/id/"
    )
};

(:~
 : Tests if the path matches the path pattern.
 :
 : @param $path-pattern the pattern with $(var-name) as marker
 : @param $path the url path
 : @return true or false
 :)
declare
    %test:args("/api/texts/t001","/api/<object-type>/<object-id>", "[.@:\w\d]+") 
    %test:assertTrue

    %test:args("/api/texts/t001/p5","/api/<object-type>/<object-id>", "[.@:\w\d]+") 
    %test:assertFalse

    %test:args("/api/texts/t001/p5.1","/api/<object-type>/<object-id>/<object-part>", "[.@:\w\d]+") 
    %test:assertTrue

    %test:args("cmg:13.4", "cmg:<page>.<line>", "[\w\d]+") 
    %test:assertTrue

    %test:args("cmg:13.4", "cmg:<page>", "[\w\d]+") 
    %test:assertFalse

    %test:args("cmg:13", "cmg:<page>.<line>", "[\w\d]+") 
    %test:assertFalse

    %test:args("cmg:123", "cmg:<page>.<line>", "[\w\d]+") 
    %test:assertFalse
function edwebcontroller:path-equals-pattern(
    $path as xs:string, 
    $path-pattern as xs:string, 
    $variable-pattern as xs:string
) as xs:boolean 
{
    let $param-regex := "<([^>]+?)>"
    let $path-regex-parts := 
        for $part in functx:get-matches-and-non-matches($path-pattern, $param-regex)
        return 
            if ($part/self::non-match) 
            then functx:escape-for-regex($part/string())
            else if ($part/self::match) 
            then $variable-pattern
            else ()
    let $path-regex := string-join(("^",$path-regex-parts,"$"))
    return matches($path, $path-regex)
};

(:~
 : A routing command which passes everything to the standard output.
 :)
declare function edwebcontroller:pass-through(
) as item()*
{
    if (edwebcontroller:is-pass-through()) 
    then (
        local:set-pass-through-false()
        ,
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <error-handler>
                <forward url="{edwebcontroller:get-exist-controller()}/views/static-pages/error-page.html" method="get"/>
                <forward url="{edwebcontroller:get-exist-controller()}/modules/view.xql"/>
            </error-handler>
        </dispatch>
    )
    else ()
};

(:~
 : Reads an url path and a pattern and returns the variables with values of the path. The values 
 : may only contain word and numeric characters ([\w\d]+).
 :
 : @param $path-pattern the pattern with $(var-name) as marker
 : @param $path the url path
 : @return the variables as sequence of <param key="var-name" value="var-value"/>
 :)
declare
    %test:args("/api/texts/t001","/api/<object-type>/<object-id>", "[.@:\w\d]+") 
    %test:assertEquals(
        "<param key='object-type' value='texts'/>", 
        "<param key='object-id' value='t001'/>"
    )
function edwebcontroller:read-path-variables(
    $path as xs:string, 
    $path-pattern as xs:string, 
    $variable-pattern as xs:string
) as node()* 
{
    let $param-regex := "<([^>]+?)>"
    let $path-regex-parts := 
        for $part in functx:get-matches-and-non-matches($path-pattern, $param-regex)
        return if ($part/self::non-match) then
            [functx:escape-for-regex($part/string()), ()]
        else if ($part/self::match) then
            let $key := replace($part, $param-regex, "$1")
            return [$variable-pattern, $key]
        else ()
    let $matches := for $part at $pos in $path-regex-parts
        let $path-tail := if (fn:count($path-regex-parts) eq 1) then ($path) else (replace($path, "^"||string-join(for $p in subsequence($path-regex-parts, 1, $pos -1) return $p(1)), ""))
        let $match := functx:get-matches($path-tail, $part(1))[1]
        return <match>{$match}</match>
    let $params := for $p at $pos in $path-regex-parts return
        if (exists($p(2))) then
            <param key="{$p(2)}" value="{$matches[$pos]/string()}"/>
        else ()
    return ($params)
};

(:~
 : Redirects the URI.
 :
 : @param $equals if the exist-path is equal to this the request will be redirected.
 : @param $redirect Where to redirect the request.
 :)
declare function edwebcontroller:redirect(
    $equals as xs:string, 
    $redirect as xs:string
) as item()*
{
    if (edwebcontroller:is-pass-through() and edwebcontroller:get-exist-path() = $equals) 
    then (
        local:set-pass-through-false()
        ,
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="{$redirect}"/>
        </dispatch>
    )
    else ()
};

(:~ 
 : Searches an object with an ID property and redirects to it.
 :
 : @param $starts-with if the request starts with this it is redirected. Everything after will be mapped to the id property.
 : @param $id-type the name of the id property.
 :)
declare function edwebcontroller:redirect-to-id(
    $starts-with as xs:string,
    $id-type as xs:string
) as item()*
{
  if (edwebcontroller:is-pass-through() and starts-with(edwebcontroller:get-exist-path(), $starts-with)) 
    then (
       local:set-pass-through-false()
        ,
        try {
        let $base-url := substring-before(request:get-uri(), edwebcontroller:get-exist-controller())
                ||edwebcontroller:get-exist-controller()
        let $id := substring-after(edwebcontroller:get-exist-path(), $starts-with)
        let $object := edwebcontroller:find-object-by-id($id-type, $id)
        let $object-type := $object?object-type
        let $object-id := $object?id
        let $redirect := $base-url||"/"||$object-type||"/"||$object-id
        return
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <redirect url="{$redirect}"/>
            </dispatch>
        } catch * {
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <error-handler>
                    <forward url="{edwebcontroller:get-exist-controller()}/views/static-pages/error-page.html" method="get"/>
                    <forward url="{edwebcontroller:get-exist-controller()}/modules/view.xql"/>
                </error-handler>
            </dispatch>
        }
    )
    else ()
};

declare function edwebcontroller:find-object-by-id(
    $id-type as xs:string,
    $id as xs:string
) as map(*)
{
    try {
        let $link-list := edwebcontroller:api-get("/api?id-type="||$id-type)
        let $object := $link-list[?filter?($id-type) = $id][1]
        return
            $object
    }
    catch err:XPTY0004 {
        error(xs:QName("edwebcontroller:find-object-by-id-001"), "No object found with request: /api?id-type="||$id-type||"")
    }
};

(:~
 : Saves the project name in the request.
 :
 : @param $project-name the name of the project.
 :)
declare function edwebcontroller:set-project(
    $project-name as xs:string
) as item()
{
    request:set-attribute("project", $project-name)
};

(:~ 
 : Forwards the request to a view and set a feed. The feed is a string with alternativ key value 
 : pairs, e.g. "id/1234/type/person".
 :
 : @param $starts-with if the request starts with this it is forwarded. Everything after appended to 
 :        the feed.
 : @param $view the path to the view.
 : @param $feed an addition to the standard feed of the URL.
 :)
declare function edwebcontroller:view-with-feed(
    $starts-with as xs:string, 
    $view as xs:string, 
    $feed as xs:string
) as item()*
{
    if (edwebcontroller:is-pass-through() and starts-with(edwebcontroller:get-exist-path(), $starts-with)) 
    then (
        local:set-pass-through-false()
        ,
        local:set-feed($feed||substring-after(edwebcontroller:get-exist-path(), $starts-with))
        ,
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{edwebcontroller:get-exist-controller()}/views/{$view}"/>
            <view>
                <forward url="{edwebcontroller:get-exist-controller()}/modules/view.xql"> {
                    for $att in request:attribute-names()
                    let $att-value := request:get-attribute($att)
                    return <set-attribute name="{$att}" value="{$att-value}"/>
                } </forward>
            </view>
            <error-handler>
                <forward url="{edwebcontroller:get-exist-controller()}/views/static-pages/error-page.html" 
                         method="get"/>
                <forward url="{edwebcontroller:get-exist-controller()}/modules/view.xql"/>
            </error-handler>
        </dispatch>
    )
    else ()
};

(:~
 : Sets the attribute "pass-through" to false. This attribute is used to mark if a routing command 
 : for the current request is set already.
 :)
declare function local:set-pass-through-false(
) as item()*
{
    request:set-attribute("pass-through", "false")
};

(:~
 : Sets the attribute "pass-through" to true. This attribute is used to mark if a routing command 
 : for the current request is set already.
 :)
declare function local:set-pass-through-true(
) as item()*
{
    request:set-attribute("pass-through", "true")
};

(:~
 : Saves the feed as key, value pairs as attributes to the request.
 :
 : @param $feed a "/" separated string with alternating keys and values
 :)
declare function local:set-feed(
    $feed as xs:string
) as item()*
{
    let $feed-items := tokenize($feed, "/")
    for $param at $pos in $feed-items
    return
        if ($pos mod 2 = 0) 
        then ()
        else
            request:set-attribute($param, $feed-items[$pos+1])
};

