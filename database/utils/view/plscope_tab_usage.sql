/*
* Copyright 2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

CREATE OR REPLACE VIEW plscope_tab_usage AS
WITH
   dep AS (
      SELECT owner      AS owner,
             'TABLE'    AS type,
             table_name AS name,
             NULL AS referenced_owner,
             NULL AS referenced_type,
             NULL AS referenced_name
        FROM dba_tables
      UNION ALL
      SELECT owner,
             type,
             name,
             referenced_owner,
             referenced_type,
             referenced_name
        FROM dba_dependencies
       WHERE type IN ('VIEW', 'MATERIALIZED VIEW', 'SYNONYM')
   ),
   dep_graph AS (
      SELECT DISTINCT
             owner,
             type                   AS object_type,
             name                   AS object_name,
             connect_by_root(owner) AS ref_owner,
             connect_by_root(type)  AS ref_object_type,
             connect_by_root(name)  AS ref_object_name,
             level                  AS path_len
        FROM dep
      CONNECT BY  PRIOR dep.owner = dep.referenced_owner
              AND PRIOR dep.type  = dep.referenced_type
              AND PRIOR dep.name  = dep.referenced_name
   )
SELECT ids.owner,
       ids.object_type,
       ids.object_name,
       ids.line,
       ids.col,
       ids.procedure_name,
       CASE
          WHEN refs.type IS NOT NULL THEN
             refs.type
          ELSE
             ids.usage
       END AS operation,
       dep_graph.ref_owner,
       dep_graph.ref_object_type,
       dep_graph.ref_object_name,
       CASE
          WHEN dep_graph.path_len = 1 THEN
             'YES'
          ELSE
             'NO'
       END AS direct_dependency,
       ids.text
  FROM plscope_identifiers ids
  JOIN dep_graph
    ON dep_graph.owner           = ids.ref_owner
       AND dep_graph.object_type = ids.ref_object_type
       AND dep_graph.object_name = ids.ref_object_name
  LEFT JOIN sys.dba_synonyms syn
    ON dep_graph.ref_owner = syn.owner
       AND dep_graph.ref_object_name = syn.synonym_name
  LEFT JOIN sys.dba_objects obj
    ON obj.owner = syn.table_owner
       AND obj.object_name = syn.table_name
  LEFT JOIN dba_statements refs
    ON refs.signature = parent_statement_signature
 WHERE ids.type IN ('VIEW', 'TABLE', 'MATERIALIZED VIEW', 'SYNONYM')
   AND (obj.object_type IS NULL OR obj.object_type IN ('VIEW', 'TABLE', 'MATERIALIZED VIEW'));
