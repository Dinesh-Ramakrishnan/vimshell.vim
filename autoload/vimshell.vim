"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Nov 2013.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:loaded_vimshell')
  runtime! plugin/vimshell.vim
endif

function! vimshell#version() "{{{
  return '1000'
endfunction"}}}

function! vimshell#echo_error(string) "{{{
  echohl Error | echo a:string | echohl None
endfunction"}}}

" Initialize. "{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
"}}}

" vimshell plugin utility functions. "{{{
function! vimshell#available_commands(...) "{{{
  call vimshell#init#_internal_commands(get(a:000, 0, ''))
  return vimshell#variables#internal_commands()
endfunction"}}}
function! vimshell#read(fd) "{{{
  if empty(a:fd) || a:fd.stdin == ''
    return ''
  endif

  if a:fd.stdout == '/dev/null'
    " Nothing.
    return ''
  elseif a:fd.stdout == '/dev/clip'
    " Write to clipboard.
    return @+
  else
    " Read from file.
    if vimshell#util#is_windows()
      let ff = "\<CR>\<LF>"
    else
      let ff = "\<LF>"
      return join(readfile(a:fd.stdin), ff) . ff
    endif
  endif
endfunction"}}}
function! vimshell#print(fd, string) "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string)
endfunction"}}}
function! vimshell#print_line(fd, string) "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#error_line(fd, string) "{{{
  return vimshell#interactive#error_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#print_prompt(...) "{{{
  return call('vimshell#view#_print_prompt', a:000)
endfunction"}}}
function! vimshell#print_secondary_prompt() "{{{
  return call('vimshell#view#_print_secondary_prompt', a:000)
endfunction"}}}
function! vimshell#get_command_path(program) "{{{
  " Command search.
  try
    return vimproc#get_command_name(a:program)
  catch /File ".*" is not found./
    " Not found.
    return ''
  endtry
endfunction"}}}
function! vimshell#start_insert(...) "{{{
  return call('vimshell#view#_start_insert', a:000)
endfunction"}}}
function! vimshell#get_prompt(...) "{{{
  return call('vimshell#view#_get_prompt', a:000)
endfunction"}}}
function! vimshell#get_secondary_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'secondary_prompt', get(g:, 'vimshell_secondary_prompt', '%% '))
endfunction"}}}
function! vimshell#get_user_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'user_prompt', get(g:, 'vimshell_user_prompt', ''))
endfunction"}}}
function! vimshell#get_right_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'right_prompt', get(g:, 'vimshell_right_prompt', ''))
endfunction"}}}
function! vimshell#get_cur_text() "{{{
  " Get cursor text without prompt.
  if &filetype !=# 'vimshell'
    return vimshell#interactive#get_cur_text()
  endif

  let cur_line = vimshell#get_cur_line()
  return cur_line[vimshell#get_prompt_length(cur_line) :]
endfunction"}}}
function! vimshell#get_cur_line() "{{{
  let cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c' . (mode() ==# 'i' ? '' : '.'))
  return cur_text
endfunction"}}}
function! vimshell#get_prompt_linenr() "{{{
  if b:interactive.type !=# 'interactive'
        \ && b:interactive.type !=# 'vimshell'
    return 0
  endif

  let [line, col] = searchpos(
        \ vimshell#get_context().prompt_pattern, 'nbcW')
  return line
endfunction"}}}
function! vimshell#check_prompt(...) "{{{
  if &filetype !=# 'vimshell' || !empty(b:vimshell.continuation)
    return call('vimshell#get_prompt', a:000) != ''
  endif

  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return line =~# vimshell#get_context().prompt_pattern
endfunction"}}}
function! vimshell#check_secondary_prompt(...) "{{{
  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#util#head_match(line, vimshell#get_secondary_prompt())
endfunction"}}}
function! vimshell#check_user_prompt(...) "{{{
  let line = a:0 == 0 ? line('.') : a:1
  if !vimshell#util#head_match(getline(line-1), '[%] ')
    " Not found.
    return 0
  endif

  while 1
    let line -= 1

    if !vimshell#util#head_match(getline(line-1), '[%] ')
      break
    endif
  endwhile

  return line
endfunction"}}}
function! vimshell#set_execute_file(exts, program) "{{{
  return vimshell#util#set_dictionary_helper(g:vimshell_execute_file_list,
        \ a:exts, a:program)
endfunction"}}}
function! vimshell#open(filename) "{{{
  call vimproc#open(a:filename)
endfunction"}}}
function! vimshell#get_program_pattern() "{{{
  return
        \'^\s*\%([^[:blank:]]\|\\[^[:alnum:]._-]\)\+\ze\%(\s*\%(=\s*\)\?\)'
endfunction"}}}
function! vimshell#get_argument_pattern() "{{{
  return
        \'[^\\]\s\zs\%([^[:blank:]]\|\\[^[:alnum:].-]\)\+$'
endfunction"}}}
function! vimshell#get_alias_pattern() "{{{
  return '^\s*[[:alnum:].+#_@!%:-]\+'
endfunction"}}}
function! vimshell#cd(directory) "{{{
  return vimshell#view#_cd(a:directory)
endfunction"}}}
function! vimshell#set_variables(variables) "{{{
  let variables_save = {}
  for [key, value] in items(a:variables)
    let save_value = exists(key) ? eval(key) : ''

    let variables_save[key] = save_value
    execute 'let' key '= value'
  endfor

  return variables_save
endfunction"}}}
function! vimshell#restore_variables(variables) "{{{
  for [key, value] in items(a:variables)
    execute 'let' key '= value'
  endfor
endfunction"}}}
function! vimshell#check_cursor_is_end() "{{{
  return vimshell#get_cur_line() ==# getline('.')
endfunction"}}}
function! vimshell#execute_current_line(is_insert) "{{{
  return &filetype ==# 'vimshell' ?
        \ vimshell#mappings#execute_line(a:is_insert) :
        \ vimshell#int_mappings#execute_line(a:is_insert)
endfunction"}}}
function! vimshell#next_prompt(context, ...) "{{{
  return call('vimshell#view#_next_prompt', [a:context] + a:000)
endfunction"}}}
function! vimshell#is_interactive() "{{{
  let is_valid = get(get(b:interactive, 'process', {}), 'is_valid', 0)
  return b:interactive.type ==# 'interactive'
        \ || (b:interactive.type ==# 'vimshell' && is_valid)
endfunction"}}}
function! vimshell#get_data_directory()
  if !isdirectory(g:vimshell_temporary_directory) && !vimshell#util#is_sudo()
    call mkdir(g:vimshell_temporary_directory, 'p')
  endif

  return g:vimshell_temporary_directory
endfunction
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...) "{{{
  return call('vimshell#helpers#execute', [a:cmdline] + a:000)
endfunction"}}}
function! vimshell#execute_async(cmdline, ...) "{{{
  return call('vimshell#helpers#execute_async', [a:cmdline] + a:000)
endfunction"}}}
function! vimshell#set_context(context) "{{{
  let context = vimshell#init#_context(a:context)
  let s:context = context
  if exists('b:vimshell')
    let b:vimshell.context = context
  endif
endfunction"}}}
function! vimshell#get_context() "{{{
  if exists('b:vimshell')
    return extend(copy(b:vimshell.context),
          \ get(b:vimshell.continuation, 'context', {}))
  elseif !exists('s:context')
    " Set context.
    let context = {
      \ 'has_head_spaces' : 0,
      \ 'is_interactive' : 0,
      \ 'is_insert' : 0,
      \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
      \}

    call vimshell#set_context(context)
  endif

  return s:context
endfunction"}}}
function! vimshell#set_alias(name, value) "{{{
  if !exists('b:vimshell')
    let b:vimshell = {}
  endif
  if !has_key(b:vimshell, 'alias_table')
    let b:vimshell.alias_table = {}
  endif

  if a:value == ''
    " Delete alias.
    call remove(b:vimshell.alias_table, a:name)
  else
    let b:vimshell.alias_table[a:name] = a:value
  endif
endfunction"}}}
function! vimshell#get_alias(name) "{{{
  return get(b:vimshell.alias_table, a:name, '')
endfunction"}}}
function! vimshell#set_galias(name, value) "{{{
  if !exists('b:vimshell')
    let b:vimshell = {}
  endif
  if !has_key(b:vimshell, 'galias_table')
    let b:vimshell.galias_table = {}
  endif

  if a:value == ''
    " Delete alias.
    call remove(b:vimshell.galias_table, a:name)
  else
    let b:vimshell.galias_table[a:name] = a:value
  endif
endfunction"}}}
function! vimshell#get_galias(name) "{{{
  return get(b:vimshell.galias_table, a:name, '')
endfunction"}}}
function! vimshell#set_syntax(syntax_name) "{{{
  let b:interactive.syntax = a:syntax_name
endfunction"}}}
function! vimshell#get_status_string() "{{{
  return !exists('b:vimshell') ? '' : (
        \ (!empty(b:vimshell.continuation) ? '[async] ' : '') .
        \ b:vimshell.current_dir)
endfunction"}}}

function! vimshell#complete(arglead, cmdline, cursorpos) "{{{
  let _ = []

  " Option names completion.
  try
    let _ += filter(vimshell#variables#options(),
          \ 'stridx(v:val, a:arglead) == 0')
  catch
  endtry

  " Directory name completion.
  let _ += filter(map(split(glob(a:arglead . '*'), '\n'),
        \ "isdirectory(v:val) ? v:val.'/' : v:val"),
        \ 'stridx(v:val, a:arglead) == 0')

  return sort(_)
endfunction"}}}
function! vimshell#vimshell_execute_complete(arglead, cmdline, cursorpos) "{{{
  " Get complete words.
  let cmdline = a:cmdline[len(matchstr(
        \ a:cmdline, vimshell#get_program_pattern())):]

  let args = vimproc#parser#split_args_through(cmdline)
  if empty(args) || cmdline =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  return map(vimshell#complete#helper#command_args(args), 'v:val.word')
endfunction"}}}
function! vimshell#get_prompt_length(...) "{{{
  return len(matchstr(get(a:000, 0, getline('.')),
        \ vimshell#get_context().prompt_pattern))
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
