# Definition of research data with the appconf.xml

- [1. Structure](#1-structure)
- [2. Project information](#2-project-information)
- [3. Definition of an object / entity](#3-definition-of-an-object--entity)
  - [3.1 Base information](#31-base-information)
  - [3.2 Properties (filters)](#32-properties-filters)
    - [Base information](#base-information)
    - [XPath Property](#xpath-property)
    - [Label property](#label-property)
    - [ID property](#id-property)
    - [Relation property](#relation-property)
    - [JSON Property](#json-property)
  - [3.3 Views / XSLTs](#33-views--xslts)
    - [Base information](#base-information-1)
  - [3.4 Parts and reference points](#34-parts-and-reference-points)
    - [Main definition](#main-definition)
    - [Base information](#base-information-2)
  - [3.5 Search index](#35-search-index)
    - [Base information](#base-information-3)
- [4. Definition of a relation](#4-definition-of-a-relation)
  - [4.1 Base information](#41-base-information)
  - [4.2 Subject and object condition](#42-subject-and-object-condition)
- [5. Definition of a search routine](#5-definition-of-a-search-routine)
  - [5.1 Base information](#51-base-information)

## 1. Structure

In the manifest file `appconf.xml` is defined how to extract the relevant research data from the raw xml data of the database.
Two categories of research data can be defined: objects and relations.
The different atomic units of the digital edition can be understood as objects of different types.
E.g. a digital scholarly edition of letters can contain the following object types: letters, persons, places, keywords, etc.
Between the objects relations can be formed.
These relations are also of different kinds and should be defined.
E.g. a digital scholarly edition of letters defines the following relations: between person and letter (as sender or recipient), between person and place (as birthplace or place of residence), etc.

Besides objects and relations it is also possible to define search indexes.

The structure of the `appconf.xml` is as follows:

```xml
<config xmlns="http://www.bbaw.de/telota/software/ediarum/web/appconf">
    <project>
        ...
    </project>
    <object> ... </object>
    <object> ... </object>
    ...
    <relation> ... </relation>
    <relation> ... </relation>
    ...
    <search> ... </search>
    <search> ... </search>
    ...
</config>
```

## 2. Project information

It must be defined how the project is name (serves as ID as well) and where to find the project data in the database.

- `name` defines the project name/ID.
- `status` defines the status of the current instance. It is be used to distinguish test instance, internal instance and public instance.
- `collection` a absolute path or a path relative to the appconf.xml to the root collection of the project data in the database.

```xml
<project>
    <name>project-name</name>
    <status>intern</status>
    <collection>/db/projects/project-name/data</collection>
</project>
```

## 3. Definition of an object / entity

The digital edition can be understood as objects of different types. Every object type is defined in the `appconf.xml`:

```xml
<config>
    ...
    <object> ... </object>
    <object> ... </object>
    ...
</config>
```

### 3.1 Base information

The basic information for an object type defines where to find the objects in the data and how to label them.

- `object/@xml:id` ID of the object type.
- `name` name of the object type. Can be used in the frontend.
- `collection` a relative path to the collection or to a resource where to search for objects. It mustn't contain an upward pointing path like `/../`. **Attention:** If this collection is a subcollection of another defined object-type, this collection is excluded from the other object-type. That is, no items of the other object-type inside this collection will be found. To avoid this behaviour set here the same collection as for the other object-type. If a collection is unset here, one has to manually remove the `collection.xconf` file from the corresponding collection `/db/system/config/my-project-collection-path/my-unset-object-collection-path/collection.xconf` and reindex.
- one or more `item/namespace` with `@id` defines a namespace used in the following XPath expressions. `@id` defines the ns prefix.
- `item/root` QName expression of the root element of every object. It only must contain a qualified name, e.g. `tei:TEI`.
- `item/condition` optional XPath expression of type boolean to define only some of the defined nodes as objects.
- `item/id` XPath expression where to find the ID of an object. This is also used as a ID property (see below).
- `item/label` with `@type` a XPath or XQuery expression to define the label of the object. `@type` must be `xpath` or `xquery`. A XQuery is always a function with one node as parameter: `function($node) { ... }`.

```xml
<object xml:id="personen">
    <name>Personen</name>
    <collection>/Register/Personen</collection>
    <item>
        <namespace id="tei">http://www.tei-c.org/ns/1.0</namespace>
        <root>tei:TEI</root>
        <condition>@type = 'person'</condition>
        <id>.//tei:publicationStmt/tei:idno</id>
        <label type="xpath">.//(tei:head[@type='entry']/tei:persName | tei:div[@subtype="otherNames"]//tei:p)/normalize-space()</label>
    </item>
    ...
</object>
```

It is also possible to parse a JSON file instead of XML nodes. The JSON file are not indexed, so it doesn't support searches. For this use the following definitions:

- `object/@xml:id` ID of the object type.
- `name` name of the object type. Can be used in the frontend.
- `json-file` a relative path to the json file containing all objects.
- `item/id` with `@type="json"` a map expression where to find the ID of an object. This is also used as a ID property (see below). Due to the use of ID in the URL all `:` and `/` in the ID are replaced with `-` resp. `/`.
- `item/label` with `@type="json"` a map expression to define the label of the object.
- optional `item/label-function` with `@type="xquery"` a XQuery function which can manipulate the property values further. It receives always one string: `function($string) { ... }`.

*Map expressions are the following: `.` for the whole map; `key` or `key?subkey` for single entries; `*` for all entries*

```xml
 <object xml:id="persons">
    <name>Personen</name>
    <json-file>/Register/Personen.json</json-file>
    <item>
        <id type="json">PersonID</id>
        <label type="json">.</label>
        <label-function type="xquery">
            function($map) { string-join(($map?forename?*?eng, $map?surname?*?eng),' ') }
        </label-function>
    </item>
</object>
```

### 3.2 Properties (filters)

Properties are defined within an object definition in a `<filters>` tag and can be used in the frontend as filters.

*Important: The ID is always be included as property and don't has to be defined again.*

Example, where to define a property:

```xml
<object>
    ...
    <filters>
        <filter>...</filter>
        <filter>...</filter>
        ...
    </filters>
</object>
```

#### Base information

All property definitions share the following structure:

- `filter/@xml:id` the ID of the property.
- `name` the name of the property which can be shown as filter title in the frontend.
- `type` defines how a filter for this property should behave. Possibles values are
  - `single` only one property can be selected.
  - `union` multiple properties can be selected, items which have one of the selected properties are shown.
  - `intersect` multiple properties can be selected, items which have all of the selected properties are shown.
  - `greater-than` for numeric properties. Only items with values greater than a defined one are shown.
  - `lower-than` for numeric properties. Only item with values lower than a defined one are shown.
- optional `label-function` with `@type='xquery'` a XQuery function which can manipulate the property values further. It receives always one string: `function($string) { ... }`.

Example:

```xml
<filter xml:id="group">
    <name>Gruppe</name>
    <type>single</type>
    <xpath>.//tei:head[@type='entry']/@subtype||''</xpath>
    <label-function type="xquery">
        function($string) { $string }
    </label-function>
</filter>
```

Or for a JSON file:

```xml
<filter xml:id="forename-eng">
    <name>Name</name>
    <type>string</type>
    <json>forename?*?eng</json>
</filter>
```

#### XPath Property

- `xpath` defines a XPath expression to get the property value. Doesn't work with JSON files.

Example:

```xml
<filter xml:id="group">
    <name>Gruppe</name>
    <type>single</type>
    <xpath>.//tei:head[@type='entry']/@subtype||''</xpath>
    <label-function type="xquery">
        function($string) { $string }
    </label-function>
</filter>
```

#### Label property

- `root/@type` must be equal to `label`. Doesn't work with JSON files.

Example:

```xml
<filter xml:id="alphabet">
    <name>alphabetisch</name>
    <type>single</type>
    <root type="label"/>
    <label-function type="xquery">
        function($string) {substring(replace(normalize-space($string), '^\(', ''),1,1)}
    </label-function>
</filter>
```

#### ID property

- `type` must be equal to `id`. Doesn't work with JSON files.

Example:

```xml
<filter xml:id="gnd">
    <name>GND</name>
    <type>id</type>
    <xpath>.//tei:persName/@key/tokenize(.,' ')[contains(.,'gnd:')]</xpath>
    <label-function type="xquery">
        function($string) { substring-after($string, 'gnd:')||"" }
    </label-function>
</filter>
```

#### Relation property

- `filter/@type` must be equal to `relation`. Doesn't work with JSON files.
- `relation/@id` the ID of the relation definition.
- `relation/@as` defines if the current item is defined as 'object' or as 'subject' of the relation.
- `label` defines which should be used as label. Possible values are: 'id', 'predicate', and 'id+predicate'.

Example:

```xml
<filter xml:id="role" type="relation">
    <name>Kontextrolle</name>
    <type>intersect</type>
    <relation id="roles" as="subject"/>
    <label>predicate</label>
    <label-function type="xquery">
        function($string) {$string}
    </label-function>
</filter>
```

#### JSON Property

- for JSON objects use `json` the map expression where to find the property values.

```xml
<filter xml:id="name-eng">
    <name>Name</name>
    <type>string</type>
    <json>forename?eng</json>
    <label-function type="xquery">
        function($map) { string-join(($map?forename, $map?surname), " ") }
    </label-function>
</filter>
```

### 3.3 Views / XSLTs

With a view it is possible to generate different outputs for an object. 
For this the XML-object is transformed with a project specific XSLT. 
The views are defined within an object definition in a `<views>` tag.

Example, where to define a view:

```xml
<object>
    ...
    <views>
        <view>...</view>
        <view>...</view>
        ...
    </views>
</object>
```

#### Base information

The basic information for a view defines where to find the XSLT for the transformation.

- `view/@id` ID of the view used by api calls.
- `label` label of the view, can be shown in the frontend.
- `xslt` relative path (from app root) to the XSLT. 
- `xslt/@params` possible XSLT parameters are specified here. Multiple parameters must be separated with a whitespace.

```xml
<view id="default">
    <label>Standard</label>
    <xslt params="highlight status">resources/xslt/text_detail.xsl</xslt>
</view>
```

*Related API call*

```
/api/<object-type>/<object-id>
```

*Related functions*

- [edweb:add-view-list ($node, $model)](https://github.com/ediarum/ediarum.WEB/blob/a741f090864a41239f8a1c8c049fa2e3cd76cfdb/content/edweb.xql#L443-L458)
- [edweb:add-view-list ($node, $model, $views, $selected)](https://github.com/ediarum/ediarum.WEB/blob/a741f090864a41239f8a1c8c049fa2e3cd76cfdb/content/edweb.xql#L460-L496)
- [edweb:add-view-nav ($node, $model)](https://github.com/ediarum/ediarum.WEB/blob/a741f090864a41239f8a1c8c049fa2e3cd76cfdb/content/edweb.xql#L498-L520)
- [edweb:add-view-nav ($node, $model, $views, $selected)](https://github.com/ediarum/ediarum.WEB/blob/a741f090864a41239f8a1c8c049fa2e3cd76cfdb/content/edweb.xql#L522-L548)

### 3.4 Parts and reference points

It can be defined how to reference parts of an object. By this, the parts can be referenced and retrieved. Different types of object parts can be defined, eg. sections, pages, and anchors. Nesting of parts is possible, eg. pages and lines.

Example, where to define the parts:

```xml
<object>
    ...
    <parts separator="" prefix="">
        <part>...</part>
        <part>...</part>
        ...
    </parts>
</object>
```

The following attributes must be declared within `<parts>`:

- `parts/@separator` defines how to parts and subparts in case of nesting must be separated, see examples, e.g. `.`: `34.12`.
- `prefix` defines how to separate the namespaces (`starts-with`) from the value, e.g. `-`: `page-23`.

Examples:

How to define page and linebreaks aa reference points:

```xml
<parts separator="." prefix="">
    <part>...</part>
    <part>...</part>
</parts>
```

#### Main definition

#### Base information

All part definitions share the following structure:

- `part/@xml:id` the ID of the part. *Important: The ID values must only contain literals and/or numbers.*
- `part/@starts-with` optional prefix which the ID values must match, e.g. `line-`
- `root` element which is root of the part. *Important: no paths are allowed. Write `tei:div[parent::tei:div]` instead of `tei:div/tei:div`*
- `id` *Important: The ID values must only contain literals and/or numbers.*
- zero or more `part` definitions of nested parts

Example:

Reference an TEI document by pagebreaks and linebreaks:

```xml
<part xml:id="page">
    <root>tei:pb</root>
    <id>@n</id>
    <part xml:id="line">
        <root>tei:lb</root>
        <id>@n</id>
    </part>
</part>
```

### 3.5 Search index

For each object type it is possible to define an search index. For objects from JSON files searches are not supported.

Example, where to define an index:

```xml
<object>
    ...
    <lucene>
        ...
    </lucene>
</object>
```

#### Base information

The basic information for a lucene index contains the xml-structure which should be used by eXist-db, for details see [http://exist-db.org/exist/apps/doc/lucene.xml](http://exist-db.org/exist/apps/doc/lucene.xml).

- one or more `analyzer` defining the used analyzers.
- one or more `text` defining which index should be created.
- one or more `inline` defining which elements doesn't insert word boundaries like `br`.
- one or more `ignore` defining which elements should be ignored for search.

```xml
<lucene>
    <analyzer class="org.apache.lucene.analysis.standard.StandardAnalyzer"/>
    <analyzer id="ws" class="org.apache.lucene.analysis.core.WhitespaceAnalyzer"/>
    <text qname="TITLE" analyzer="ws"/>
    <text qname="p">
        <inline qname="em"/>
    </text>
    <text match="//foo/*"/>
    <!-- "inline" and "ignore" can be specified globally or per-index as shown above -->
    <inline qname="b"/>
    <ignore qname="note"/>
</lucene>
```

*Related API call*

```
/api/search/<search-id>
/api/<object-type>?show=list&search=<query>
```

## 4. Definition of a relation

One main aspect of a digital scholarly edition is to make the relations of different objects explicit. 
This can be used to navigate from one object to another through links or to support analysis of the data.
Like object types relations of differend kinds are defined in the `appconf.xml`:

```xml
<config>
    ...
    <relation> ... </relation>
    <relation> ... </relation>
    ...
</config>
```

### 4.1 Base information

The basic information for an relation type defines where to find the relations in the data and how to label them.

- `relation/@xml:id` ID of the relation type used by api calls.
- `@subject` ID of the object type which serves as subject in a relation expression.
- `@object` ID of the object type which serves as object in a relation expression.
- `name` Label of the relation type.
- `collection` a relative path to the collection where to search for relations.
- one or more `item/namespace` with `@id` defines a namespace used in the following XPath expressions. `@id` defines the ns prefix.
- `item/root` QName of the root element of every relation.
- `item/id` XPath expression where to find the ID of an object.
- `item/condition` optional XPath expression of type boolean to define only some of the defined nodes as relations. **Attention:** The XPath expression is relative to the root, it must contain `.` to address the root. E.g. `./@key` instead of `/@key`.
- `label` with `@type` a XPath or XQuery expression to define the label of the relation and is used as predicate in a relation expression. `@type` must be `xpath` or `xquery`. A XQuery is always a function with one string as parameter: `function($string) { ... }`.

```xml
<relation xml:id="msterms" subject="items" object="handschriften">
    <name>Enthaltene Sachbegriffe</name>
    <collection>/Handschriften</collection>
    <item>
        <namespace id="tei">http://www.tei-c.org/ns/1.0</namespace>
        <root>tei:term</root>
        <condition>./@key</condition>
        <label type="xquery">
            function ($node as node()) {
            'Enthaltener Begriff'
            }
        </label>
    </item>
    <subject-condition>
        ...
    </subject-condition>
    <object-condition>
        ...
    </object-condition>
</relation>
```

### 4.2 Subject and object condition

The subject and object conditions are used to define how to link a specific subject and object to a relation:

- `subject-condition` a XQuery function which must return true if an entity is equal to the subject of the relation.
  - `subject-condition@type` optional with following values:
    - `id` define a xpath-expression of the relation to compare with the subject ids.
    - `id-type` define a xpath-expression of the relation to compare with subject id properties. Requires `@filter` to be set.
    - `resource` defines that the relation node is contained by the same resource as the subject.
  - `subject-condition@filter` to be used with `id-type` to specify which filter property is used.
- `object-condition` a XQuery function which must return true if an entity is equal to the object of the relation.
  - `object-condition@type` optional with following values:
    - `id` define a xpath-expression of the relation to compare with the object ids.
    - `id-type` define a xpath-expression of the relation to compare with object id properties. Requires `@filter` to be set.
    - `resource` defines that the relation node is contained by the same resource as the subject.
  - `object-condition@filter` to be used with `id-type` to specify which filter property is used.

*Attention:* If possible always some of the above conditions (with `@type`) should be used. Because then the eXist-db indexes are used and performance is better.

Both XQuery functions (if `@type` is omitted) have the form:

```
function ($this as map(*), $subject as map(*)) as xs:boolean
```

The parameter are the following:

- `$this` represents the found relation. The map contains `$this?xml` the xml of the found relation and $this?absolute-resource-id the internal id of the resource in which it is found.
- `$subject` and `$object` represent the entities which could be subject or object to a relation and defined in `relation/@subject` and `relation/@object`. The map contains the map of the entity with `$subject?id` and `$subject?filter` etc.

```xml
<relation>
    <subject-condition>
        function ($this as map(*), $subject as map(*)) {
            $this?xml/@key = $subject?id
        }
    </subject-condition>
    <object-condition>
        function ($this as map(*), $object as map(*)) {
            $this?absolute-resource-id = $object?absolute-resource-id
        }
    </object-condition>
</relation>
```

## 5. Definition of a search routine

It is possible to define search routines which can search within multiple object types. All objects with hits are returned ordered by the search score, see [http://exist-db.org/exist/apps/doc/lucene.xml#query](http://exist-db.org/exist/apps/doc/lucene.xml#query). Searches don't work with objects from JSON files.

```xml
<config>
    ...
    <search> ... </search>
    <search> ... </search>
    ...
</config>
```

### 5.1 Base information

The basic information for a search defines ...

- `search/@xml:id` ID of the search routine used by api calls.
- one or more `target` define where to search for.
- `target/@object` defines the object type to be searched.
- `target/xpath` defines a xpath expression where to search within the objects.

```xml
<search xml:id="letters">
    <target object="letters" xpath="tei:p"/>
</search>
```

*Related API call*

```
/api/search/<search-id>?q=<query>
```
