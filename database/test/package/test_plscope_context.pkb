create or replace package body test_plscope_context is
   
   --
   -- test_set_attr
   --
   procedure test_set_attr is
      l_actual sys.session_context.value%type;
      procedure test_set_valid_attr(in_name in varchar2) is
      begin
         plscope_context.set_attr(in_name => in_name, in_value => lower(in_name));
         l_actual := sys_context('PLSCOPE', in_name);
         ut.expect(l_actual).to_equal(lower(in_name));
      end test_set_valid_attr;
   begin
      test_set_valid_attr('ARRAY_TYPE_REGEX');
      test_set_valid_attr('CONSTANT_REGEX');
      test_set_valid_attr('CURSOR_PARAMETER_REGEX');
      test_set_valid_attr('CURSOR_REGEX');
      test_set_valid_attr('EXCEPTION_REGEX');
      test_set_valid_attr('GLOBAL_VARIABLE_REGEX');
      test_set_valid_attr('IN_OUT_PARAMETER_REGEX');
      test_set_valid_attr('IN_PARAMETER_REGEX');
      test_set_valid_attr('LOCAL_ARRAY_VARIABLE_REGEX');
      test_set_valid_attr('LOCAL_OBJECT_VARIABLE_REGEX');
      test_set_valid_attr('LOCAL_RECORD_VARIABLE_REGEX');
      test_set_valid_attr('LOCAL_VARIABLE_REGEX');
      test_set_valid_attr('OBJECT_NAME');
      test_set_valid_attr('OBJECT_TYPE');
      test_set_valid_attr('OUT_PARAMETER_REGEX');
      test_set_valid_attr('OWNER');
      test_set_valid_attr('RECORD_TYPE_REGEX');
      test_set_valid_attr('SUBTYPE_REGEX');
   end test_set_attr;
   
   --
   -- test_set_misspelled_attr
   --
   procedure test_set_misspelled_attr is
   begin
      plscope_context.set_attr(
         in_name => 'NO_SUCH_REGEX_NO_MATTER_WHAT', 
         in_value => 'Oops, wrong attribute name!'
      );
   end test_set_misspelled_attr;
   
   --
   -- test_remove_attr
   --
   procedure test_remove_attr is
      l_actual sys.session_context.value%type;
   begin
      plscope_context.set_attr(in_name => 'OWNER', in_value => 'xxx');
      plscope_context.remove_attr('OWNER');
      l_actual := sys_context('PLSCOPE', 'OWNER');
      ut.expect(l_actual).to_(be_null);
   end test_remove_attr;

   --
   -- test_remove_all
   --
   procedure test_remove_all is
      l_actual integer;
   begin
      plscope_context.set_attr(in_name => 'OWNER', in_value => 'xxx');
      plscope_context.set_attr(in_name => 'OBJECT_TYPE', in_value => 'yyy');
      plscope_context.set_attr(in_name => 'OBJECT_NAME', in_value => 'zzz');
      plscope_context.remove_all;
      select count(*)
        into l_actual
        from sys.session_context -- NOSONAR: avoid public synonym
       where namespace = 'PLSCOPE';
      ut.expect(l_actual).to_equal(0);
   end test_remove_all;
   
   --
   -- cleanup
   --
   procedure cleanup is
   begin
      plscope_context.remove_all;
   end cleanup;

end test_plscope_context;
/
