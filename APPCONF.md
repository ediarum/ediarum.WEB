# Structure of the appconf.xml

## 1. Structure

## 2. Definition of an object

### 2.1 Base information

### 2.2 Properties (filters)

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

#### Property

```xml
<filter xml:id="" depends="">
  <name>
  <type>
  <label-function type="xquery">
</filter>
```

#### Label property

```xml
<filter xml:id="">
    <root type="label"/>
</filter>
```

#### Relation properties

```xml
<filter xml:id="">
    <relation id="" as=""></relation>
    <label>id</label>
</filter>
```

- `relation/@id` the ID of the relation definition
- `relation/@as` defines if the current item is defined as 'object' or as 'subject' of the relation.
- `label` defines which should be used as label. Possible values are: 'id', 'predicate', and 'id+predicate'.

## 3. Definition of a relation