# Definition of research data with the appconf.xml

- [Definition of research data with the appconf.xml](#definition-of-research-data-with-the-appconfxml)
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
  - [4. Definition of a relation](#4-definition-of-a-relation)
    - [4.1 Base information](#41-base-information)
    - [4.2 Subject and object condition](#42-subject-and-object-condition)

## 1. Structure

In the manifest file `appconf.xml` is defined how to extract the relevant research data from the raw xml data of the database.
Two categories of research data can be defined: objects and relations.
The different atomic units of the digital edition can be understood as objects of different types.
E.g. a digital scholarly edition of letters can contain the following object types: letters, persons, places, keywords, etc.
Between the objects relations can be formed.
These relations are also of different kinds and should be defined.
E.g. a digital scholarly edition of letters defines the following relations: between person and letter (as sender or recipient), between person and place (as birthplace or place of residence), etc.

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
</config>
```

## 2. Project information

It must be defined how the project is name (serves as ID as well) and where to find the project data in the database.

- `name` defines the project name/ID.
- `status` defines the status of the current instance. It is be used to distinguish test instance, internal instance and public instance.
- `collection` a absolute path to the root collection of the project data in the database.

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
- `collection` a relative path to the collection where to search for objects.
- one or more `item/namespace` with `@id` defines a namespace used in the following XPath expressions. `@id` defines the ns prefix.
- `item/root` XPath expression of the root element of every object.
- `item/id` XPath expression where to find the ID of an object.
- `label` with `@type` a XPath or XQuery expression to define the label of the object. `@type` must be `xpath` or `xquery`. A XQuery is always a function with one string as parameter: `function($string) { ... }`.

```xml
<object xml:id="personen">
    <name>Personen</name>
    <collection>/Register/Personen</collection>
    <item>
        <namespace id="tei">http://www.tei-c.org/ns/1.0</namespace>
        <root>tei:TEI</root>
        <id>.//tei:publicationStmt/tei:idno</id>
        <label type="xpath">.//(tei:head[@type='entry']/tei:persName | tei:div[@subtype="otherNames"]//tei:p)/normalize-space()</label>
    </item>
    ...
</object>
```

### 3.2 Properties (filters)

Properties are defined within an object definition in a `<filters>` tag and can be used in the frontend as filters.

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

Alle property definitions share the following structure:

- `filter/@xml:id` the ID of the property.
- `name` the name of the property which can be shown as filter title in the frontend.
- `type` defines how a filter for this property should behave. Possibles values are
  - `single` only one property can be selected.
  - `union` multiple properties can be selected, items which have one of the selected properties are shown.
  - `intersect` multiple properties can be selected, items which have all of the selected properties are shown.
  - `greater-than` for numeric properties. Only items with values greater than a defined one are shown.
  - `lower-than` for numeric properties. Only item with values lower than a defined one are shown.
- `label-function` with `@type='xquery'` a XQuery function which can manipulate the property values further. It receives always one string: `function($string) { ... }`.

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

#### XPath Property

- `xpath` defines a XPath expression to get the property value.

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

- `root/@type` must be equal to `label`.

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

- `type` must be equal to `id`.

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

- `filter/@type` must be equal to `relation`.
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
- `item/root` XPath expression of the root element of every relation.
- `item/id` XPath expression where to find the ID of an object.
- `label` with `@type` a XPath or XQuery expression to define the label of the relation and is used as predicate in a relation expression. `@type` must be `xpath` or `xquery`. A XQuery is always a function with one string as parameter: `function($string) { ... }`.

```xml
<relation xml:id="msterms" subject="items" object="handschriften">
    <name>Enthaltene Sachbegriffe</name>
    <collection>/Handschriften</collection>
    <item>
        <namespace id="tei">http://www.tei-c.org/ns/1.0</namespace>
        <root>tei:term[@key]</root>
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
- `object-condition` a XQuery function which must return true if an entity is equal to the object of the relation.

Both XQuery function have the form:

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
