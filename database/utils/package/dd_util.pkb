create or replace package body dd_util is

   --
   -- resolve_synonym
   --
   function resolve_synonym(
      in_parse_user in varchar2,
      in_obj        in obj_type,
      in_in_depth   in number default 1
   ) return obj_type is
      o_obj obj_type;
      
      -- Resolve the target as an object in the schema specified as the "table owner"
      cursor c_lookup is
         select /*+ noparallel */
                obj_type(
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           from sys.dba_synonyms s -- NOSONAR: avoid public synonym
           join sys.dba_objects o -- NOSONAR: avoid public synonym
             on o.owner = s.table_owner
            and o.object_name = s.table_name
            and o.subobject_name is null
            and o.namespace = 1
          where s.owner = o_obj.owner
            and s.synonym_name = o_obj.object_name;
      
      -- Failing the above, resolve the target as a public synonym
      cursor c_lookup_pubsyn is
         select /*+ noparallel */
                obj_type(
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           from sys.dba_synonyms s -- NOSONAR: avoid public synonym
           join sys.dba_objects o -- NOSONAR: avoid public synonym
             on o.owner = 'PUBLIC'
            and o.object_name = s.table_name
            and o.subobject_name is null
            and o.namespace = 1
            and o.object_type = 'SYNONYM'
          where s.owner = o_obj.owner
            and s.synonym_name = o_obj.object_name;

      -- For loop detection
      subtype qualified_name_type is varchar2(261 char);
      type map_qualified_name_type is table of pls_integer index by qualified_name_type;
      l_map_syn_names map_qualified_name_type;
      l_qual_syn_name qualified_name_type;
   begin
      o_obj := get_object(in_parse_user => in_parse_user, in_obj => in_obj);
      if o_obj.object_type = 'SYNONYM' then
         l_qual_syn_name := '"' || o_obj.owner || '"."' || o_obj.object_name || '"';
         l_map_syn_names(l_qual_syn_name) := 1;
         <<resolve_syn_chain>>
         while o_obj.object_type = 'SYNONYM' loop
            open c_lookup;
            fetch c_lookup into o_obj;
            if c_lookup%notfound then
               open c_lookup_pubsyn;
               fetch c_lookup_pubsyn into o_obj;
            end if;
            if c_lookup%notfound and c_lookup_pubsyn%notfound then
               -- synonym of a non-existent object
               o_obj.owner := null;
               o_obj.object_type := null;
               o_obj.object_name := null;
            else
               l_qual_syn_name := '"' || o_obj.owner || '"."' || o_obj.object_name || '"';
               if l_map_syn_names.exists(l_qual_syn_name) then
                  -- synonym loop
                  o_obj.owner := null;
                  o_obj.object_type := null;
                  o_obj.object_name := null;
               else
                  l_map_syn_names(l_qual_syn_name) := 1;
               end if;
            end if;
            if c_lookup_pubsyn%isopen then
               close c_lookup_pubsyn;
            end if;
            close c_lookup;
            exit resolve_syn_chain when in_in_depth <> 1;
         end loop resolve_syn_chain;
      end if;
      return o_obj;
   end resolve_synonym;

   --
   -- get_object
   --
   function get_object(
      in_parse_user in varchar2,
      in_obj        in obj_type,
      in_namespace  in number default 1
   ) return obj_type is
      o_obj obj_type;
      cursor c_lookup is
         select obj_type(
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           from sys.dba_objects o -- NOSONAR: avoid public synonym
          where o.namespace = in_namespace
            and o.owner in (
                   -- if in_obj.owner is specified, the search is limited to that schema
                   -- otherwise the scope is the parsing schema and (possibly) public synonyms
                   coalesce(in_obj.owner, in_parse_user),
                   case
                      when in_obj.owner is null 
                         and (in_obj.object_type is null or in_obj.object_type = 'SYNONYM')
                      then 'PUBLIC'
                   end
                )
            and o.object_name = in_obj.object_name
            and o.subobject_name is null
            and (in_obj.object_type is null or o.object_type = in_obj.object_type)
          order by case o.owner
                     when in_obj.owner then
                        1
                     when in_parse_user then
                        2
                     else
                        3
                  end,
                case o.object_type
                   when in_obj.object_type then
                      1
                   when 'SYNONYM' then
                      3
                   else
                      2
                end;
   begin
      open c_lookup;
      fetch c_lookup into o_obj;
      close c_lookup;
      return o_obj;
   end get_object;

   --
   -- get_objects
   --
   function get_objects(
      in_parse_user in varchar2,
      in_t_obj      in t_obj_type,
      in_namespace  in number default 1
   ) return t_obj_type is
      o_obj obj_type;
      t_obj t_obj_type := t_obj_type();
      i     pls_integer;
   begin
      if in_t_obj is not null and in_t_obj.count > 0 then
         -- in_t_obj could be sparse
         i := in_t_obj.first;
         <<input_objects>>
         while (i is not null)
         loop
            o_obj := get_object(
                        in_parse_user => in_parse_user,
                        in_obj        => in_t_obj(i),
                        in_namespace  => in_namespace
                     );
            if o_obj.owner is not null then
               t_obj.extend;
               t_obj(t_obj.count) := o_obj;
            end if;
            i     := in_t_obj.next(i);
         end loop input_objects;
      end if;

      -- return final objects
      return type_util.dedup(in_t_obj => t_obj);
   end get_objects;

   --
   -- get_column_id
   --
   function get_column_id(
      in_owner       in varchar2,
      in_object_name in varchar2,
      in_column_name in varchar2
   ) return integer is
      l_column_id integer;
      cursor c_lookup is
         select column_id
           from sys.dba_tab_columns -- NOSONAR: avoid public synonym
          where owner = in_owner
            and table_name = in_object_name
            and column_name = in_column_name;
   begin
      open c_lookup;
      fetch c_lookup into l_column_id;
      close c_lookup;
      return l_column_id;
   end get_column_id;

   --
   -- get_view_source
   --
   function get_view_source(
      in_obj in obj_type
   ) return clob is
      l_source      long; -- NOSONAR, have to deal with LONG
      l_source_clob clob;
      cursor c_view_lookup is
         select text
           from sys.dba_views -- NOSONAR: avoid public synonym
          where owner = in_obj.owner
            and view_name = in_obj.object_name;
      cursor c_mview_lookup is
         select query
           from sys.dba_mviews -- NOSONAR: avoid public synonym
          where owner = in_obj.owner
            and mview_name = in_obj.object_name;
   begin
      case in_obj.object_type
         when 'VIEW' then
            open c_view_lookup;
            fetch c_view_lookup into l_source;
            close c_view_lookup;
            l_source_clob := l_source;
         when 'MATERIALIZED VIEW' then
            open c_mview_lookup;
            fetch c_mview_lookup into l_source;
            close c_mview_lookup;
            l_source_clob := l_source;
         else
            l_source := null;
      end case;
      return l_source_clob;
   end get_view_source;

end dd_util;
/