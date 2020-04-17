xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

sm:chmod(xs:anyURI($target||"/views/api/object-list.xql"), "rwxr-sr-x"),
sm:chmod(xs:anyURI($target||"/views/api/object-xml.xql"), "rwxr-sr-x"),
sm:chmod(xs:anyURI($target||"/views/api/object-json.xql"), "rwxr-sr-x"),
sm:chmod(xs:anyURI($target||"/views/api/object-part.xql"), "rwxr-sr-x"),
sm:chmod(xs:anyURI($target||"/views/api/all-list.xql"), "rwxr-sr-x"),
sm:chmod(xs:anyURI($target||"/views/api/show-config.xql"), "rwxr-sr-x")
