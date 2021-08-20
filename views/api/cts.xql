xquery version "3.1";

import module namespace edwebcontroller="http://www.bbaw.de/telota/software/ediarum/web/controller";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace cts="http://chs.harvard.edu/xmlns/cts/";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare function local:cts-get-passage(
    $urn as xs:string,
    $cts-object-id-type as xs:string
)
{
    let $cts-id := string-join(tokenize($urn,':')[5>position()],':')
    let $object := edwebcontroller:find-object-by-id($cts-object-id-type, $cts-id)
    let $object-type := $object?object-type
    let $object-id := $object?id
    let $part-id := tokenize($urn,':')[5]
    return
        try {
            edwebcontroller:api-get("/api/"||$object-type||"/"||$object-id||"/"||$part-id)
        }
        catch * {
            ()
        }
};

let $cts-object-id-type := request:get-attribute("cts-object-id-type")

let $request := request:get-parameter("request","")
let $result :=
    switch ($request)
    case "GetCapabilities"
    case "GetValidReff"
    case "GetPrevNextUrn"
    case "GetFirstUrn"
    case "GetLabel"
    case "GetPassagePlus" return
        <cts:CTSError>
            <cts:message>Request not implemented yet:{$request}</cts:message>
            <cts:code>7</cts:code>
        </cts:CTSError>
    case "GetPassage" return
        let $urn := request:get-parameter("urn",'')
        let $is-valid-urn := matches($urn, "urn:cts:.+:.+\..+\..+:.+")
        return
            if (not($is-valid-urn))
            then
                <cts:CTSError>
                    <cts:message>Invalid URN syntax:{$urn}</cts:message>
                    <cts:code>2</cts:code>
                </cts:CTSError>
            else
                let $passage := local:cts-get-passage($urn, $cts-object-id-type)
                return
                    if (not(empty($passage))) then
                        <cts:GetPassage>
                          <cts:request>
                            <cts:info>Data received via CTS-API of ediarum.WEB at {request:get-url()}</cts:info>
                          </cts:request>
                          <cts:reply>
                            <cts:urn>{$urn}</cts:urn>
                            <cts:passage>{$passage}</cts:passage>
                          </cts:reply>
                        </cts:GetPassage>
                    else
                        <cts:CTSError>
                            <cts:message>Invalid URN reference:{$urn}</cts:message>
                            <cts:code>3</cts:code>
                        </cts:CTSError>
    default return
        <cts:CTSError>
            <cts:message>Invalid request name:{$request}</cts:message>
            <cts:code></cts:code>
        </cts:CTSError>

return
    $result
