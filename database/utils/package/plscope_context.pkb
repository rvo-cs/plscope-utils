create or replace package body plscope_context is

   co_namespace constant sys.all_context.namespace%type := 'PLSCOPE';

   procedure assert_supported_attr(in_name in varchar2);

   --
   -- set_attr
   --
   procedure set_attr(
      in_name  in varchar2,
      in_value in varchar2
   ) is
   begin
      assert_supported_attr(in_name);
      sys.dbms_session.set_context(
         namespace => co_namespace,
         attribute => in_name,
         value     => in_value
      );
   end set_attr;
   
   --
   -- remove_attr
   --
   procedure remove_attr(
      in_name in varchar2
   ) is
   begin
      assert_supported_attr(in_name);
      sys.dbms_session.clear_context(
         namespace => co_namespace,
         attribute => in_name
      );
   end remove_attr;
   
   --
   -- remove_all
   --
   procedure remove_all is
   begin
      sys.dbms_session.clear_all_context(
         namespace => co_namespace
      );
   end remove_all;

   --
   -- assert_supported_attr
   --
   procedure assert_supported_attr(in_name in varchar2) is
   begin
      case in_name
         when 'ARRAY_TYPE_REGEX' then
            null;
         when 'CONSTANT_REGEX' then
            null;
         when 'CURSOR_PARAMETER_REGEX' then
            null;
         when 'CURSOR_REGEX' then
            null;
         when 'EXCEPTION_REGEX' then
            null;
         when 'GLOBAL_VARIABLE_REGEX' then
            null;
         when 'IN_OUT_PARAMETER_REGEX' then
            null;
         when 'IN_PARAMETER_REGEX' then
            null;
         when 'LOCAL_ARRAY_VARIABLE_REGEX' then
            null;
         when 'LOCAL_OBJECT_VARIABLE_REGEX' then
            null;
         when 'LOCAL_RECORD_VARIABLE_REGEX' then
            null;
         when 'LOCAL_VARIABLE_REGEX' then
            null;
         when 'OBJECT_NAME' then
            null;
         when 'OBJECT_TYPE' then
            null;
         when 'OUT_PARAMETER_REGEX' then
            null;
         when 'OWNER' then
            null;
         when 'RECORD_TYPE_REGEX' then
            null;
         when 'SUBTYPE_REGEX' then
            null;
         else
            raise_application_error(-20000, 'unsupported or misspelled attribute name');
      end case;
   end assert_supported_attr;

end plscope_context;
/
