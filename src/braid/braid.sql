CREATE TABLE q (
 p INTEGER NOT NULL DEFAULT 1,
 r INTEGER PRIMARY KEY AUTOINCREMENT,
 c TEXT NOT NULL,
 d TEXT,
 FOREIGN KEY(p) REFERENCES q(r)
  ON DELETE CASCADE
  ON UPDATE CASCADE );

CREATE TABLE veqtor
    (stamp INTEGER DEFAULT (strftime('%s','now')),
    edge TEXT UNIQUE DEFAULT (hex(randomblob(8))),
    node TEXT NOT NULL,
    property TEXT NOT NULL,
    content TEXT NOT NULL,
    inclusion REAL NOT NULL DEFAULT 1,
    PRIMARY KEY (stamp, edge));
---
CREATE INDEX stamp_index ON veqtor(stamp);
---
CREATE INDEX node_index ON veqtor(node);
---
CREATE INDEX property_index ON veqtor(property);
---
CREATE VIEW row_count AS
   SELECT count(*)
      FROM veqtor;
---
CREATE VIEW nodes AS
    SELECT DISTINCT node
      FROM veqtor;
---
CREATE VIEW property_content
    AS SELECT datetime(stamp, 'unixepoch') AS DateTime,
       property AS Type,
       content AS Value
  FROM veqtor;
---
CREATE TRIGGER property_content_insert
    INSTEAD OF INSERT
    ON property_content
    FOR EACH ROW
    BEGIN
        INSERT INTO veqtor (
            node,
            property,
            content)
        VALUES (
            hex(randomblob(8) ),
            new.Type,
            new.Value);
    END;
---
INSERT INTO veqtor (node, property, content) VALUES ('root', 'root', 'root');


CREATE TABLE schema_objects(
uuid TEXT PRIMARY KEY,
object_type TEXT NOT NULL,
parent_uuid TEXT);

CREATE TABLE schema_properties(
uuid TEXT PRIMARY KEY,
schema_object_uuid NOT NULL,
property_type TEXT NOT NULL,
data_type TEXT NOT NULL,
FOREIGN KEY (schema_object_uuid)
REFERENCES schema_objects(uuid));

CREATE TABLE schema_attributes(
uuid TEXT PRIMARY KEY,
subject_uuid TEXT NOT NULL,
attribute_type TEXT NOT NULL,
attribute_value TEXT NOT NULL);

CREATE TABLE model_objects(
uuid TEXT PRIMARY KEY,
object_type TEXT NOT NULL,
parent_uuid TEXT);

CREATE TABLE model_properties(
uuid TEXT PRIMARY KEY,
property_type TEXT NOT NULL,
property_value TEXT,
model_object_uuid TEXT NOT NULL,
FOREIGN KEY (model_object_uuid)
REFERENCES model_objects(uuid));

-- views into root tables
-- schema views
CREATE VIEW
schema_object_properties
AS SELECT
o.object_type,
p.property_type,
p.data_type,
o.uuid AS object_uuid,
p.uuid AS property_uuid
FROM
schema_objects o,
schema_properties p
WHERE
p.schema_object_uuid = o.uuid;

CREATE VIEW
schema_object_properties_attributes
AS SELECT
sop.object_type,
sop.property_type,
sop.data_type,
a.attribute_type,
a.attribute_value,
sop.object_uuid,
sop.property_uuid,
a.uuid AS attribute_uuid
FROM
schema_object_properties sop,
schema_attributes a
WHERE
a.subject_uuid = sop.property_uuid;

CREATE VIEW
schema_object_attributes
AS SELECT
o.object_type,
a.attribute_type,
a.attribute_value,
o.uuid AS object_uuid,
a.uuid AS attribute_uuid
FROM
schema_objects o,
schema_attributes a
WHERE
a.subject_uuid = o.uuid;

CREATE VIEW schema_object_attribute_types
AS SELECT DISTINCT attribute_type
FROM schema_object_attributes
ORDER BY attribute_type;

CREATE VIEW schema_property_attribute_types
AS SELECT DISTINCT attribute_type
FROM schema_object_properties_attributes
ORDER BY attribute_type;

CREATE VIEW schema_roots
AS SELECT *
FROM schema_objects
WHERE parent_uuid = ''
order by object_type;

CREATE VIEW schema_object_data
AS select
object_type,
property_type,
attribute_type,
attribute_value
from
schema_object_properties_attributes
where
attribute_type != 'position'
order by
object_type,
property_type;

CREATE VIEW
schema_object_properties_position
AS SELECT
object_type,
property_type,
CAST(attribute_value AS number) AS position,
object_uuid,
property_uuid
FROM
schema_object_properties_attributes
WHERE attribute_type = 'position';

CREATE VIEW schema_object_properties_position_datatype
AS SELECT
p.object_type,
p.property_type,
p.position,
d.data_type,
p.object_uuid,
p.property_uuid
FROM
schema_object_properties_position p,
schema_object_properties d
WHERE p.property_uuid = d.property_uuid
ORDER BY p.object_type, p.position;

CREATE VIEW schema_object_property_types
AS SELECT object_type, property_type, data_type
FROM schema_object_properties_position_datatype;


