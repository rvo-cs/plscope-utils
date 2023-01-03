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

-- Extract the C-style comment block following the WITH keyword in the text 
-- of the PLSCOPE_NAMING view, and turn it into a proper comment on that view.
declare
   co_view_name   constant user_views.view_name %type := 'PLSCOPE_NAMING';
   co_trim_chars  constant varchar2(2 char) := ' ' || chr(10);

   l_comment_text varchar2(4000 byte);
begin
   select regexp_substr(v.text_vc, '^with\s+(/\*.*\*/)\s+src as \(', 1, 1, 'n', 1)
     into l_comment_text
     from user_views v
    where v.view_name = co_view_name;

   execute immediate 'comment on table ' || co_view_name || ' is q''#'
      || rtrim(ltrim(regexp_replace(l_comment_text, '^.{0,8}', '', 1, 0, 'm'),
                     co_trim_chars), co_trim_chars)
      || '#''';
end;
/
