# plscope-utils - Core Database Objects

## Introduction
This component of plscope-utils provides relational views and PL/SQL packages based on PL/Scope to simplify common source code analysis tasks.

## ToC

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Usage](#usage)
    * [Compile with PL/Scope](#compile-with-plscope)
    * [Set Session Context (optional)](#set-session-context-optional)
    * [View PLSCOPE\_IDENTIFIERS](#view-plscope_identifiers)
    * [View PLSCOPE\_STATEMENTS](#view-plscope_statements)
    * [View PLSCOPE\_TAB\_USAGE](#view-plscope_tab_usage)
    * [View PLSCOPE\_COL\_USAGE](#view-plscope_col_usage)
    * [View PLSCOPE\_NAMING](#view-plscope_naming)
    * [View PLSCOPE\_INS\_LINEAGE](#view-plscope_ins_lineage)
* [License](#license) 

## Prerequisites

* Oracle Database 12.2 or higher
* Oracle client (SQL*Plus, SQLcl or SQL Developer) to connect to the database

## Installation

1. Clone or download this repository; expand the downloaded zip file, if you have chosen the download option.

2. Open a terminal window and change to the directory containing this README.md file

    ```
    cd /path_to/plscope-utils/database
    ```

3. Create an oracle account to own the plscope-utils database objects. The default username is ```PLSCOPE``` (password: ```plscope```).

   * Optional: change username, password, and tablespace in the installation script: [utils/user/plscope.sql](utils/user/plscope.sql)

   * Connect as SYS to the target database:

        ```
        sqlplus / as sysdba
        ```

   * Execute the script [utils/user/plscope.sql](utils/user/plscope.sql)

        ```
        @utils/user/plscope.sql
        exit
        ```

4. Install plscope-utils objects

   * Connect as the user created in the previous step

        ```
        sqlplus plscope/plscope
        ```

   * Execute the script [install.sql](install.sql)

        ```
        @install.sql
        exit
        ```

## Usage

### Compile with PL/Scope

#### Enable PL/Scope in the current session

```sql
alter session set plscope_settings = 'identifiers:all, statements:all';
```

#### Create/compile a procedure

The following example is based on [demo tables](demo/table) installed by plscope-utils.

```sql
create or replace procedure load_from_tab is
begin
   insert into deptsal (dept_no, dept_name, salary)
   select /*+ordered */
          d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
     from dept d
     left join (
             select *
               from emp
              where hiredate > date '1980-01-01'
          ) e
       on e.deptno = d.deptno
    group by d.deptno, d.dname;
   commit;
end load_from_tab;
/
```
### Set Session Context (optional)

All views are filtered by the following session context attributes:

Attribute | Default Value | Predicate used in views
--------- | ------------- | -----------------------
OWNER | ```USER``` | ```owner LIKE nvl(sys_context('PLSCOPE', 'OWNER'), USER)```
OBJECT_TYPE | ```%``` | ```object_type LIKE nvl(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')```
OBJECT_NAME | ```%``` | ```object_name LIKE nvl(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')```

The filter is applied in the views as early as possible to improve runtime performance. You may set the ```OWNER``` attribute to ```%``` and filter the owner in the where clause, e.g. to analyse several schemas in one go. 

Here's an example to set the context to a chosen PL/SQL package of the [Alexandria PL/SQL Utility Library](https://github.com/mortenbra/alexandria-plsql-utils):

```sql
exec plscope_context.set_attr('OWNER', 'AX');
exec plscope_context.set_attr('OBJECT_TYPE', 'PACKAGE%');
exec plscope_context.set_attr('OBJECT_NAME', 'APEX_UTIL_PKG');
```

### [View PLSCOPE\_IDENTIFIERS](utils/view/plscope_identifiers.sql)

This view combines the ```dba_identifiers```, ```dba_statements``` and ```dba_source``` views. It provides all columns from ```dba_identifiers``` plus the following:

Column Name           | Description
--------------------- | -------------
```procedure_name```  | Name of the top-level function/procedure in a PL/SQL package or type; same as ```object_name``` for standalone procedures and functions
```procedure_scope``` | ```PRIVATE``` or ```PUBLIC``` scope of a function/procedure in a PL/SQL package or type; children inherit the procedure scope.
```name_usage```      | Name of the identifier, along with its type and usage, as a single column; indented according to context in order to represent the hierarchy of contexts/usages of identifiers
```name_path```       | Path formed by identifiers in the hierarchy, from the root identifier down to and including the present identifier
```path_len```        | Hierarchy level of the identifier (number of forward slashes in ```name_path```)
```module_name```     | In a procedure or function _definition_, the name of the present procedure or function, along with (if any) the names of all its parent procedures/functions down from the top-level unit, separated by dot (.) characters  
```ref_owner```       | ```owner``` of the object referenced by the ```signature``` column
```ref_object_type``` | ```object_type``` of the object referenced by the ```signature``` column
```ref_object_name``` | ```object_name``` of the object referenced by the ```signature``` column
```text``` | ```text``` of the referenced source code line
```parent_statement_type``` | ```type``` of the parent statement (```NULL``` if parent is not a SQL statement)
```parent_statement_signature``` | ```signature``` of the parent statement (```NULL``` if parent is not a SQL statement)
```parent_statement_path_len``` | ```path_len``` of the parent statement (```NULL``` if parent is not a SQL statement)
```is_used``` | Applies only to locally-declared identifiers (except labels) in stand-alone procedures/functions, package bodies, or type bodies; always ```NULL``` otherwise [^1]. The value is ```YES``` if the identifier is referenced locally, ```NO``` if it is only declared, but not referenced [^2]; ```NULL``` if not applicable.

[^1]: In particular, ```plscope_identifiers.is_used``` is always ```NULL``` for public declarations in package or type specifications.
[^2]: Basically, the aim is that such unused identifiers could be removed, in principle.

#### Query

```sql
select procedure_name,
       line,
       col,
       name_usage,
       name,
       type,
       usage,
       ref_owner,
       ref_object_type,
       ref_object_name,
       text,
       name_path,
       path_len,
       parent_statement_type,
       parent_statement_signature,
       signature,
       usage_id,
       usage_context_id,
       is_fixed_context_id
  from plscope_identifiers
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;
```
#### Result

```
PROCEDURE_NAME   LINE  COL NAME_USAGE                                    NAME           TYPE       USAGE        REF_OWNER  REF_OBJECT_TYPE REF_OBJECT_NAME TEXT                                                              NAME_PATH                                                 PATH_LEN PARENT_STATEMENT_TYPE PARENT_STATEMENT_SIGNATURE       SIGNATURE                          USAGE_ID USAGE_CONTEXT_ID IS_FIXED_CONTEXT_ID
--------------- ----- ---- --------------------------------------------- -------------- ---------- ------------ ---------- --------------- --------------- ----------------------------------------------------------------- ------------------------------------------------------- ---------- --------------------- -------------------------------- -------------------------------- ---------- ---------------- -------------------
LOAD_FROM_TAB       1   19 LOAD_FROM_TAB (procedure declaration)         LOAD_FROM_TAB  PROCEDURE  DECLARATION  PLSCOPE    PROCEDURE       LOAD_FROM_TAB   procedure         load_from_tab is                                /LOAD_FROM_TAB                                                   1                                                        95BB10518161E6977D1AAAE904795B9B          1                0                    
LOAD_FROM_TAB       1   19   LOAD_FROM_TAB (procedure definition)        LOAD_FROM_TAB  PROCEDURE  DEFINITION   PLSCOPE    PROCEDURE       LOAD_FROM_TAB   procedure         load_from_tab is                                /LOAD_FROM_TAB/LOAD_FROM_TAB                                     2                                                        95BB10518161E6977D1AAAE904795B9B          2                1                    
LOAD_FROM_TAB       3    4     INSERT statement (sql_id: 56gspgc3bathk)  56gspgc3bathk  INSERT     EXECUTE                                                    insert into deptsal (dept_no, dept_name, salary)               /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk                       3                                                        0F66407F96683E82288B47C4A3692141          3                2                    
LOAD_FROM_TAB       3   16       DEPTSAL (table reference)               DEPTSAL        TABLE      REFERENCE    PLSCOPE    TABLE           DEPTSAL            insert into deptsal (dept_no, dept_name, salary)               /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPTSAL               4 INSERT                0F66407F96683E82288B47C4A3692141 842CE56AC592888B175F02BB44BD5B94         14                3                    
LOAD_FROM_TAB       3   25       DEPT_NO (column reference)              DEPT_NO        COLUMN     REFERENCE    PLSCOPE    TABLE           DEPTSAL            insert into deptsal (dept_no, dept_name, salary)               /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPT_NO               4 INSERT                0F66407F96683E82288B47C4A3692141 0E36BB98CA1380341FCA76D468AC332C         17                3                    
LOAD_FROM_TAB       3   34       DEPT_NAME (column reference)            DEPT_NAME      COLUMN     REFERENCE    PLSCOPE    TABLE           DEPTSAL            insert into deptsal (dept_no, dept_name, salary)               /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPT_NAME             4 INSERT                0F66407F96683E82288B47C4A3692141 4C400D0DF6CC5BD98ADBFEF88EEBC69D         16                3                    
LOAD_FROM_TAB       3   45       SALARY (column reference)               SALARY         COLUMN     REFERENCE    PLSCOPE    TABLE           DEPTSAL            insert into deptsal (dept_no, dept_name, salary)               /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/SALARY                4 INSERT                0F66407F96683E82288B47C4A3692141 8F86A093162D45F0949E56BA145A1FE3         15                3                    
LOAD_FROM_TAB       5   13       DEPTNO (column reference)               DEPTNO         COLUMN     REFERENCE    PLSCOPE    TABLE           DEPT                      d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPTNO                4 INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC         13                3                    
LOAD_FROM_TAB       5   23       DNAME (column reference)                DNAME          COLUMN     REFERENCE    PLSCOPE    TABLE           DEPT                      d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DNAME                 4 INSERT                0F66407F96683E82288B47C4A3692141 FECE4914A162E52126C5E631734692DA         12                3                    
LOAD_FROM_TAB       5   36       SAL (column reference)                  SAL            COLUMN     REFERENCE    PLSCOPE    TABLE           EMP                       d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/SAL                   4 INSERT                0F66407F96683E82288B47C4A3692141 60535C7D73128F4E1E99B404D740FE16         11                3                    
LOAD_FROM_TAB       5   42       NVL (function call)                     NVL            FUNCTION   CALL         SYS        PACKAGE         STANDARD                  d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/NVL                   4 INSERT                0F66407F96683E82288B47C4A3692141 CCEED76FB11809FB7868E4288F0CF03D         18                3                    
LOAD_FROM_TAB       5   48         COMM (column reference)               COMM           COLUMN     REFERENCE    PLSCOPE    TABLE           EMP                       d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/NVL/COMM              5 INSERT                0F66407F96683E82288B47C4A3692141 0DD90A25A7835C18B4B81A9F4C6FB6BA         19               18                    
LOAD_FROM_TAB       6   11       DEPT (table reference)                  DEPT           TABLE      REFERENCE    PLSCOPE    TABLE           DEPT                 from dept d                                                  /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPT                  4 INSERT                0F66407F96683E82288B47C4A3692141 26739DBA3E26CBADF8B2E1FBB35428F5          6                3                    
LOAD_FROM_TAB       9   21       EMP (table reference)                   EMP            TABLE      REFERENCE    PLSCOPE    TABLE           EMP                            from emp                                           /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/EMP                   4 INSERT                0F66407F96683E82288B47C4A3692141 68FD9773CC24CA5C61FCE1CE2F27D0F8          4                3                    
LOAD_FROM_TAB      10   21       HIREDATE (column reference)             HIREDATE       COLUMN     REFERENCE    PLSCOPE    TABLE           EMP                           where hiredate > date '1980-01-01'                  /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/HIREDATE              4 INSERT                0F66407F96683E82288B47C4A3692141 7FDA2E553A30FF9773C84EBED43A686E          5                3                    
LOAD_FROM_TAB      12   13       DEPTNO (column reference)               DEPTNO         COLUMN     REFERENCE    PLSCOPE    TABLE           EMP                    on e.deptno = d.deptno                                     /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPTNO                4 INSERT                0F66407F96683E82288B47C4A3692141 B99231DD1C6931BB3728106289DDBE98          8                3                    
LOAD_FROM_TAB      12   24       DEPTNO (column reference)               DEPTNO         COLUMN     REFERENCE    PLSCOPE    TABLE           DEPT                   on e.deptno = d.deptno                                     /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPTNO                4 INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC          7                3                    
LOAD_FROM_TAB      13   16       DEPTNO (column reference)               DEPTNO         COLUMN     REFERENCE    PLSCOPE    TABLE           DEPT                group by d.deptno, d.dname;                                   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DEPTNO                4 INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC         10                3                    
LOAD_FROM_TAB      13   26       DNAME (column reference)                DNAME          COLUMN     REFERENCE    PLSCOPE    TABLE           DEPT                group by d.deptno, d.dname;                                   /LOAD_FROM_TAB/LOAD_FROM_TAB/56gspgc3bathk/DNAME                 4 INSERT                0F66407F96683E82288B47C4A3692141 FECE4914A162E52126C5E631734692DA          9                3                    
LOAD_FROM_TAB      14    4     COMMIT statement                          COMMIT         COMMIT     EXECUTE                                                    commit;                                                        /LOAD_FROM_TAB/LOAD_FROM_TAB/COMMIT                              3                                                        53B72DCFF9CB795BD122D459A43013E0         20                2                    

20 rows selected. 
```

### [View PLSCOPE\_STATEMENTS](utils/view/plscope_statements.sql)

This view is based on the ```dba_statements``` view and adds a ```is_duplicate``` column.

The [etl](demo/package/etl.pkb) package body contains various variants to load the ```deptsal``` target table. And the reported duplicate insert statement is used there as well.

#### Query

```sql
select line, col, type, sql_id, is_duplicate, full_text
  from plscope_statements s
 where object_name = 'LOAD_FROM_TAB'
 order by owner, object_type, object_name, line, col;
```
#### Result

```
LINE  COL TYPE      SQL_ID        IS_DUPLICATE FULL_TEXT                                       
---- ---- --------- ------------- ------------ -------------------------------------------------
   3    4 INSERT    3nyyhcpmwxcgz YES          INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
                                               SELECT /*+ordered */ D.DEPTNO, D.DNAME, SUM(E.SAL
                                               + NVL(E.COMM, 0)) AS SAL FROM DEPT D LEFT JOIN (
                                               SELECT * FROM EMP WHERE HIREDATE > DATE '1980-01-
                                               01') E ON E.DEPTNO = D.DEPTNO GROUP BY D.DEPTNO,
                                               D.DNAME

  12    4 COMMIT                  NO           
```

### [View PLSCOPE\_TAB\_USAGE](utils/view/plscope_tab_usage.sql)

This view reports table usages. It is based on the views ```dba_tables```, ```dba_dependencies``` and ```plscope_identifiers```. Usages of synonyms and views are resolved and reporteded with a ```NO``` in the column ```DIRECT_DEPENDENCY```.

#### Query

```sql
select *
  from plscope_tab_usage
 where procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner, object_type, object_name, line, col, direct_dependency;
```

#### Result

```
OWNER   OBJECT_TYPE  OBJECT_NAME     PROCEDURE_NAME       PROCEDURE_SCOPE  LINE  COL OPERATION  REF_OWNER  REF_OBJECT_TYPE REF_OBJECT_NAME DIRECT_DEPENDENCY TEXT                                                                        IS_BASE_OBJECT   PATH_LEN   USAGE_ID SIGNATURE                        PROCEDURE_SIGNATURE             
------- ------------ --------------- -------------------- --------------- ----- ---- ---------- ---------- --------------- --------------- ----------------- --------------------------------------------------------------------------- -------------- ---------- ---------- -------------------------------- --------------------------------
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             14   19 INSERT     PLSCOPE    TABLE           DEPTSAL         YES                     insert into deptsal (dept_no, dept_name, salary)                      YES                     0         26 842CE56AC592888B175F02BB44BD5B94 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             16   14 INSERT     PLSCOPE    TABLE           DEPT            YES                       from dept d                                                         YES                     0         18 26739DBA3E26CBADF8B2E1FBB35428F5 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             17   34 INSERT     PLSCOPE    TABLE           EMP             YES                       left join (select * from emp where hiredate > date '1980-01-01') e  YES                     0         16 68FD9773CC24CA5C61FCE1CE2F27D0F8 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             47   19 INSERT     PLSCOPE    TABLE           DEPTSAL         YES                     insert into deptsal  -- no column list NOSONAR G-3110                 YES                     0         67 842CE56AC592888B175F02BB44BD5B94 E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           DEPT            NO                        from source_syn t;                                                                          2         66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           EMP             NO                        from source_syn t;                                                                          2         66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    VIEW            SOURCE_VIEW     NO                        from source_syn t;                                                  YES                     1         66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    SYNONYM         SOURCE_SYN      YES                       from source_syn t;                                                                          0         66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              3   16 INSERT     PLSCOPE    TABLE           DEPTSAL         YES                  insert into deptsal (dept_no, dept_name, salary)                         YES                     0         14 842CE56AC592888B175F02BB44BD5B94 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              6   11 INSERT     PLSCOPE    TABLE           DEPT            YES                    from dept d                                                            YES                     0          6 26739DBA3E26CBADF8B2E1FBB35428F5 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              9   21 INSERT     PLSCOPE    TABLE           EMP             YES                              from emp                                                     YES                     0          4 68FD9773CC24CA5C61FCE1CE2F27D0F8 95BB10518161E6977D1AAAE904795B9B

11 rows selected.
```

### [View PLSCOPE\_COL\_USAGE](utils/view/plscope_col_usage.sql)

This view reports column usages. It is based on the views ```plscope_identifiers```, ```plscope_tab_usage```, ```dba_synonyms```, ```dba_objects``` and ```dba_tab_columns```. Column-less table/view/synonym accesses are resolved and reporteded with a ```NO``` in the column ```DIRECT_DEPENDENCY```.

#### Query

```sql
select *
  from plscope_col_usage
 where procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner, object_type, object_name, line, col, direct_dependency;
```
#### Result

```
OWNER   OBJECT_TYPE  OBJECT_NAME     PROCEDURE_NAME       PROCEDURE_SCOPE  LINE  COL OPERATION  REF_OWNER  REF_OBJECT_TYPE REF_OBJECT_NAME COLUMN_NAME  DIRECT_DEPENDENCY TEXT                                                                               USAGE_ID SIGNATURE                        PROCEDURE_SIGNATURE             
------- ------------ --------------- -------------------- --------------- ----- ---- ---------- ---------- --------------- --------------- ------------ ----------------- -------------------------------------------------------------------------------- ---------- -------------------------------- --------------------------------
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             14   28 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NO      YES                     insert into deptsal (dept_no, dept_name, salary)                                   29 0E36BB98CA1380341FCA76D468AC332C 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             14   37 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NAME    YES                     insert into deptsal (dept_no, dept_name, salary)                                   28 4C400D0DF6CC5BD98ADBFEF88EEBC69D 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             14   48 INSERT     PLSCOPE    TABLE           DEPTSAL         SALARY       YES                     insert into deptsal (dept_no, dept_name, salary)                                   27 8F86A093162D45F0949E56BA145A1FE3 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             15   30 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                     select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal         25 884839C0945B76EF500949A1737CDBEC 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             15   40 INSERT     PLSCOPE    TABLE           DEPT            DNAME        YES                     select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal         24 FECE4914A162E52126C5E631734692DA 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             15   53 INSERT     PLSCOPE    TABLE           EMP             SAL          YES                     select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal         23 60535C7D73128F4E1E99B404D740FE16 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             15   65 INSERT     PLSCOPE    TABLE           EMP             COMM         YES                     select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal         31 0DD90A25A7835C18B4B81A9F4C6FB6BA 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             17   44 INSERT     PLSCOPE    TABLE           EMP             HIREDATE     YES                       left join (select * from emp where hiredate > date '1980-01-01') e               17 7FDA2E553A30FF9773C84EBED43A686E 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             18   16 INSERT     PLSCOPE    TABLE           EMP             DEPTNO       YES                         on e.deptno = d.deptno                                                         20 B99231DD1C6931BB3728106289DDBE98 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             18   27 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                         on e.deptno = d.deptno                                                         19 884839C0945B76EF500949A1737CDBEC 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             19   19 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                      group by d.deptno, d.dname;                                                       22 884839C0945B76EF500949A1737CDBEC 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_TAB        PUBLIC             19   29 INSERT     PLSCOPE    TABLE           DEPT            DNAME        YES                      group by d.deptno, d.dname;                                                       21 FECE4914A162E52126C5E631734692DA 7AD7143AA5730E585B087FBB98F62585
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             47   19 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NO      NO                      insert into deptsal  -- no column list NOSONAR G-3110                              67 842CE56AC592888B175F02BB44BD5B94 E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             47   19 INSERT     PLSCOPE    TABLE           DEPTSAL         SALARY       NO                      insert into deptsal  -- no column list NOSONAR G-3110                              67 842CE56AC592888B175F02BB44BD5B94 E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             47   19 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NAME    NO                      insert into deptsal  -- no column list NOSONAR G-3110                              67 842CE56AC592888B175F02BB44BD5B94 E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           EMP             SAL          NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           EMP             COMM         NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    TABLE           DEPT            DNAME        NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    VIEW            SOURCE_VIEW     DEPT_NO      NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    VIEW            SOURCE_VIEW     SALARY       NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PACKAGE BODY ETL             LOAD_FROM_SYN_WILD   PUBLIC             49   14 INSERT     PLSCOPE    VIEW            SOURCE_VIEW     DEPT_NAME    NO                        from source_syn t;                                                               66 B9E2FC1CB97DB43BE947ED5CD91BF50F E9CB9066FCE059A32B4DBB946E95A893
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              3   25 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NO      YES                  insert into deptsal (dept_no, dept_name, salary)                                      17 0E36BB98CA1380341FCA76D468AC332C 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              3   34 INSERT     PLSCOPE    TABLE           DEPTSAL         DEPT_NAME    YES                  insert into deptsal (dept_no, dept_name, salary)                                      16 4C400D0DF6CC5BD98ADBFEF88EEBC69D 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              3   45 INSERT     PLSCOPE    TABLE           DEPTSAL         SALARY       YES                  insert into deptsal (dept_no, dept_name, salary)                                      15 8F86A093162D45F0949E56BA145A1FE3 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              5   13 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                         d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal                          13 884839C0945B76EF500949A1737CDBEC 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              5   23 INSERT     PLSCOPE    TABLE           DEPT            DNAME        YES                         d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal                          12 FECE4914A162E52126C5E631734692DA 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              5   36 INSERT     PLSCOPE    TABLE           EMP             SAL          YES                         d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal                          11 60535C7D73128F4E1E99B404D740FE16 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC              5   48 INSERT     PLSCOPE    TABLE           EMP             COMM         YES                         d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal                          19 0DD90A25A7835C18B4B81A9F4C6FB6BA 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC             10   21 INSERT     PLSCOPE    TABLE           EMP             HIREDATE     YES                             where hiredate > date '1980-01-01'                                          5 7FDA2E553A30FF9773C84EBED43A686E 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC             12   13 INSERT     PLSCOPE    TABLE           EMP             DEPTNO       YES                      on e.deptno = d.deptno                                                             8 B99231DD1C6931BB3728106289DDBE98 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC             12   24 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                      on e.deptno = d.deptno                                                             7 884839C0945B76EF500949A1737CDBEC 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC             13   16 INSERT     PLSCOPE    TABLE           DEPT            DEPTNO       YES                   group by d.deptno, d.dname;                                                          10 884839C0945B76EF500949A1737CDBEC 95BB10518161E6977D1AAAE904795B9B
PLSCOPE PROCEDURE    LOAD_FROM_TAB   LOAD_FROM_TAB        PUBLIC             13   26 INSERT     PLSCOPE    TABLE           DEPT            DNAME        YES                   group by d.deptno, d.dname;                                                           9 FECE4914A162E52126C5E631734692DA 95BB10518161E6977D1AAAE904795B9B

34 rows selected. 
```
    
### [View PLSCOPE\_NAMING](database/utils/view/plscope_naming.sql)

This view checks if PL/SQL identifier names comply to the [Trivadis PL/SQL & SQL Coding Guidelines Version 3.2](https://www.salvis.com/download/guidelines/PLSQL_and_SQL_Coding_Guidelines_3_2.pdf). This view provides chosen columns from ```dba_identifiers``` plus the following:

Column Name           | Description
--------------------- | -------------
```procedure_name```  | Name of the function/procedure in a PL/SQL package (same as ```object_name``` for standalone procedures and functions)
```message```  | Result of the check. Error message or ```OK``` if check was successful.
```text``` | ```text``` of the referenced source code line

A prefix or suffix is defined for every group of identifiers listed in the table below. By default these naming conventions are applied. However, it is possible to override the default behaviour via session context variables.

Identifier Group | (P)refix / (S)uffix | Example | Session Context Attribute | Default Regular Expression 
-----------|---------------------|---------| -------------- | -----
Global Variable | P: g | ```g_version``` | ```GLOBAL_VARIABLE_REGEX``` | ```^g_.*```
Local Record Variable | P: r | ```r_employee``` | ```LOCAL_RECORD_VARIABLE_REGEX``` | ```^r_.*```
Local Array/Table Variable | P: t | ```t_employees``` | ```LOCAL_ARRAY_VARIABLE_REGEX``` | ```^t_.*```
Local Cursor Variable| P: c | ```c_employees``` | ```LOCAL_CURSOR_VARIABLE_REGEX``` | ```^c_.*```
Local Object Variable| P: o | ```o_employee``` | ```LOCAL_OBJECT_VARIABLE_REGEX``` | ```^o_.*```
Other Local Variable | P: l | ```l_version``` | ```LOCAL_VARIABLE_REGEX``` | ```^l_.*```
Cursor | P: c | ```c_employees``` | ```CURSOR_REGEX``` | ```^c_.*```
Cursor Parameter | P: p | ```p_empno``` | ```CURSOR_PARAMETER_REGEX``` | ```^p_.*```
In Parameter | P: in | ```in_empno``` | ```IN_PARAMETER_REGEX``` | ```^in_.*```
Out Parameter | P: out | ```out_ename``` | ```OUT_PARAMETER_REGEX``` | ```^out_.*```
In/Out Parameter | P: io | ```io_employee``` | ```IN_OUT_PARAMETER_REGEX``` | ```^io_.*```
Record Type | P: r / S: type | ```r_employee_type``` | ```RECORD_TYPE_REGEX``` | ```^r_.*_type$```
Array/Table Type | P: t / S: type | ```t_employees_type``` | ```ARRAY_TYPE_REGEX``` | ```^t_.*_type$\|^.*_ct$``` 
Ref Cursor Type | P: c / S: type | ```c_employees_type``` | ```REFCURSOR_TYPE_REGEX``` | ```^c_.*_type$```
Exception | P: e | ```e_employee_exists``` | ```EXCEPTION_REGEX``` | ```^e_.*```
Constant | P: co | ```co_empno``` | ```CONSTANT_REGEX``` | ```^co_.*```
Subtype | S: type | ```big_string_type``` | ```SUBTYPE_REGEX``` | ```.*_type$```

#### Example PL/SQL Package

The identfiers in tis PL/SQL package are used to demonstrate the functionality of the view.

```sql
create or replace package pkg is
   g_global_variable integer := 0;
   g_global_constant constant varchar2(10) := 'PUBLIC';

   procedure p(p_1 in  integer,
               p_2 out integer);
end pkg;
/

create or replace package body pkg is
   m_global_variable  integer               := 1;
   co_global_constant constant varchar2(10) := 'PRIVATE';

   function f(in_1 in integer) return integer is
      l_result integer;
   begin
      l_result := in_1 * in_1;
      return l_result;
   end f;

   procedure p(p_1 in  integer,
               p_2 out integer) is
   begin
      p_2 := f(in_1 => p_1);
   end p;
end pkg;
/
```

#### Query

Use the following query to check results of package created above.

```sql
select object_type, procedure_name, type, name, message, line, col, text
  from plscope_naming
 where object_name = 'PKG'
 order by object_type, line, col;
```

If you are interested in naming convention violations only extend the where clause by ```AND message != 'OK'```.

#### Result Using Default Naming Conventions

```
OBJECT_TYPE  PRO TYPE       NAME               MESSAGE                                       LINE  COL TEXT                                                     
------------ --- ---------- ------------------ --------------------------------------------- ---- ---- ---------------------------------------------------------
PACKAGE          VARIABLE   G_GLOBAL_VARIABLE  OK                                               2    4    g_global_variable INTEGER := 0;                       
PACKAGE          CONSTANT   G_GLOBAL_CONSTANT  Constant does not match regex "^co_.*".          3    4    g_global_constant CONSTANT VARCHAR2(10) := 'PUBLIC';  
PACKAGE      P   FORMAL IN  P_1                IN parameter does not match regex "^in_.*".      5   16    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER);         
PACKAGE      P   FORMAL OUT P_2                OUT parameter does not match regex "^out_.*".    5   32    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER);         
PACKAGE BODY     VARIABLE   M_GLOBAL_VARIABLE  Global variable does not match regex "^g_.*".    2    4    m_global_variable  INTEGER := 1;                      
PACKAGE BODY     CONSTANT   CO_GLOBAL_CONSTANT OK                                               3    4    co_global_constant CONSTANT VARCHAR2(10) := 'PRIVATE';
PACKAGE BODY F   FORMAL IN  IN_1               OK                                               5   15    FUNCTION f(in_1 IN INTEGER) RETURN INTEGER IS         
PACKAGE BODY F   VARIABLE   L_RESULT           OK                                               6    7       l_result INTEGER;                                  
PACKAGE BODY P   FORMAL IN  P_1                IN parameter does not match regex "^in_.*".     12   16    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER) IS       
PACKAGE BODY P   FORMAL OUT P_2                OUT parameter does not match regex "^out_.*".   12   32    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER) IS       

10 rows selected. 
```

#### Changing Naming Conventions

```sql
begin
   plscope_context.set_attr('GLOBAL_VARIABLE_REGEX', '^(g|m)_.*');
   plscope_context.set_attr('CONSTANT_REGEX', '^(co|g)_.*');
   plscope_context.set_attr('IN_PARAMETER_REGEX', '^(in|p)_.*');
   plscope_context.set_attr('OUT_PARAMETER_REGEX', '^(out|p)_.*');
end;
/
```

#### Result after Changing Naming Conventions

```
OBJECT_TYPE  PRO TYPE       NAME               MESSAGE                                       LINE  COL TEXT                                                     
------------ --- ---------- ------------------ --------------------------------------------- ---- ---- ---------------------------------------------------------
PACKAGE          VARIABLE   G_GLOBAL_VARIABLE  OK                                               2    4    g_global_variable INTEGER := 0;                       
PACKAGE          CONSTANT   G_GLOBAL_CONSTANT  OK                                               3    4    g_global_constant CONSTANT VARCHAR2(10) := 'PUBLIC';  
PACKAGE      P   FORMAL IN  P_1                OK                                               5   16    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER);         
PACKAGE      P   FORMAL OUT P_2                OK                                               5   32    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER);         
PACKAGE BODY     VARIABLE   M_GLOBAL_VARIABLE  OK                                               2    4    m_global_variable  INTEGER := 1;                      
PACKAGE BODY     CONSTANT   CO_GLOBAL_CONSTANT OK                                               3    4    co_global_constant CONSTANT VARCHAR2(10) := 'PRIVATE';
PACKAGE BODY F   FORMAL IN  IN_1               OK                                               5   15    FUNCTION f(in_1 IN INTEGER) RETURN INTEGER IS         
PACKAGE BODY F   VARIABLE   L_RESULT           OK                                               6    7       l_result INTEGER;                                  
PACKAGE BODY P   FORMAL IN  P_1                OK                                              12   16    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER) IS       
PACKAGE BODY P   FORMAL OUT P_2                OK                                              12   32    PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER) IS       

10 rows selected.     
```

#### Resetting Naming Conventions to Default Behaviour

```sql
exec plscope_context.remove_all;
```

### [View PLSCOPE\_INS\_LINEAGE](database/utils/view/plscope_ins_lineage.sql)

**_Experimental_**

This view reports the [where-lineage](http://ilpubs.stanford.edu:8090/918/1/lin_final.pdf) of insert statements. It is based on the view ```plscope_identifiers``` and the PL/SQL package ```lineage_util```. Behind the scenes insert statements are processed using the undocumented PL/SQL package procedure ```sys.utl_xml.parsequery```. This procedures supports select statements quite well including Oracle 12.2 grammar enhancements. However, it does not support PL/SQL at all, not even as part of the with_clause. Hence, not all select statements produce a parse-tree. Furthermore other statements such as insert, update, delete and merge produce incomplete parse-trees, which is somehow expected for a procedure called ```ParseQuery```. However, they are still useful to e.g. identify the target tables of an insert statement.

Even if this view produces quite good results on wide range of `INSERT ... SELECT` statements, it is considered experimental. To produce reliable, more complete results a PL/SQL and SQL parser is required.

Nonetheless this view shows the power of PL/Scope and its related database features.

The example below shows that the ```salary``` column in the table ```deptsal``` is based on the columns ```sal``` and ```comm``` of the table ```emp```. Similar as in the view ```plscope_col_usage``` synonyms and view columns are resolved recursively. You may control the behaviour in the view by calling the ```lineage_util.set_recursive``` procedure before executing the query.

#### Query

```sql
select *
  from plscope_ins_lineage
 where object_name in ('ETL', 'LOAD_FROM_TAB')
   and procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;
```

#### Result (default)

```
OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     FROM_OWNER FROM_OBJECT_TYPE FROM_OBJECT_NAME FROM_COLUMN_NAME TO_OWNER TO_OBJECT_TYPE TO_OBJECT_NAME TO_COLUMN_NAME
------- ------------ ------------- ---- ---- ------------------ ---------- ---------------- ---------------- ---------------- -------- -------------- -------------- --------------
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NAME        PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NO          PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      SALARY           PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        

15 rows selected. 
```

#### Result (recursion disabled)

Recursive resolution of view columns may be disabled by calling: ```lineage_util.set_recursive(0);```
```
OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     FROM_OWNER FROM_OBJECT_TYPE FROM_OBJECT_NAME FROM_COLUMN_NAME TO_OWNER TO_OBJECT_TYPE TO_OBJECT_NAME TO_COLUMN_NAME
------- ------------ ------------- ---- ---- ------------------ ---------- ---------------- ---------------- ---------------- -------- -------------- -------------- --------------
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NAME        PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NO          PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      SALARY           PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        

11 rows selected. 
```

## License

plscope-utils is licensed under the Apache License, Version 2.0.

You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
