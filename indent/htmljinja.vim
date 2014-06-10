if exists("b:did_indent")
  finish
endif
runtime! indent/html.vim

unlet! b:did_indent

if &l:indentexpr == ''
  if &l:cindent
    let &l:indentexpr = 'cindent(v:lnum)'
  else
    let &l:indentexpr = 'indent(prevnonblank(v:lnum-1))'
  endif
endif
let b:html_indentexpr = &l:indentexpr

let b:did_indent = 1

setlocal indentexpr=GetJinjaIndent()
setlocal indentkeys=o,O,*<Return>,{,},o,O,!^F,<>>

" Only define the function once.
if exists("*GetJinjaIndent")
  finish
endif

let b:tagstart = '.*' . '{%[+-]\=\s*'
let b:tagend = '.*-\=%}' . '.*'

let b:blocktags = '\(block\|for\|if\|with\|autoescape\|filter\|trans\|macro\|set\)'
let b:midtags = '\(else\|elif\|pluralize\)'


function! IndentLevel(lnum)
  return indent(a:lnum)
endfunction

function! GetMatchingStartTagLevel(lnum)
  let curline = getline(a:lnum)

  let start_tag_check = matchlist(curline, b:tagstart . '\(end' . b:blocktags . '\)' . b:tagend)

  if empty(start_tag_check)
    " possible midtag
    let is_midtag  = curline =~# b:tagstart . b:midtags . b:tagend

    if is_midtag
      let mid_tag_check = matchlist(curline, b:tagstart . b:midtags . b:tagend)
      if mid_tag_check[1] == 'pluralize'
        let start_tag = 'trans'
        let end_tag = 'endtrans'
      else
        let start_tag = 'if'
        let end_tag = 'endif'
      endif
    else
      " bail out
      return 0
    endif
  else
    let start_tag = start_tag_check[2]
    let end_tag = start_tag_check[1]
  endif

  let tlnum = a:lnum - 1
  let num_end_tags = 1
  while tlnum >= 0
    let ptb = getline(tlnum)

    let end_tag_found   = ptb =~# b:tagstart . end_tag . b:tagend
    let start_tag_found   = ptb =~# b:tagstart . start_tag . b:tagend

    if end_tag_found && start_tag_found
      let start_tag_found = 0
    elseif end_tag_found
      let num_end_tags = num_end_tags + 1
    elseif start_tag_found
      let num_end_tags = num_end_tags - 1
    endif

    if start_tag_found && num_end_tags == 0
      return IndentLevel(tlnum)
    endif
    let tlnum = tlnum - 1
  endwhile
  return 0
endfunction

function! GetJinjaIndent(...)
  if a:0 && a:1 == '.'
    let v:lnum = line('.')
  elseif a:0 && a:1 =~ '^\d'
    let v:lnum = a:1
  endif
  let vcol = col('.')

  call cursor(v:lnum,vcol)

  exe "let ind = ".b:html_indentexpr

  let lnum = prevnonblank(v:lnum-1)
  let pnb = getline(lnum)
  let cur = getline(v:lnum)

  let pnb_blockstart = pnb =~# b:tagstart . b:blocktags . b:tagend
  let pnb_blockend   = pnb =~# b:tagstart . 'end' . b:blocktags . b:tagend
  let pnb_blockmid   = pnb =~# b:tagstart . b:midtags . b:tagend

  let cur_blockstart = cur =~# b:tagstart . b:blocktags . b:tagend
  let cur_blockend   = cur =~# b:tagstart . 'end' . b:blocktags . b:tagend
  let cur_blockmid   = cur =~# b:tagstart . b:midtags . b:tagend

  if pnb_blockstart && !pnb_blockend
    let ind = ind + &sw
  elseif pnb_blockmid && !pnb_blockend
    let ind = ind + &sw
  endif

  if cur_blockend && !cur_blockstart
    let ind = GetMatchingStartTagLevel(v:lnum)
  elseif cur_blockmid
    let ind = GetMatchingStartTagLevel(v:lnum)
  endif

  return ind
endfunction
