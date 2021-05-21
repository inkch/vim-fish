function! s:IsString(lnum, col)
    " Returns "true" if syntax item at the given position is part of fishString.
    let l:stack = map(synstack(a:lnum, a:col), 'synIDattr(v:val, "name")')
    return len(filter(l:stack, 'v:val ==# "fishString"'))
endfunction

function! s:IsContinuedLine(lnum)
    " Returns "true" if the given line is a continued line.
    return getline(a:lnum - 1) =~ '\v\\$'
endfunction

function! s:IsInSubstitution(lnum)
    " Returns "true" if the given line is a continued line.
    return getline(a:lnum - 1) =~ '\v\($'
endfunction

function! s:FindPrevLnum(lnum)
    " Starting on the given line, search backwards for a line that is not
    " empty, not part of a string and not a continued line.
    if a:lnum < 1 || a:lnum > line('$')
        " First line or wrong value, follow prevnonblank() behaviour and
        " return zero.
        return 0
    endif
    let l:lnum = prevnonblank(a:lnum)
    while l:lnum > 0 && ( s:IsContinuedLine(l:lnum) || s:IsString(l:lnum, 1) )
        let l:lnum = prevnonblank(l:lnum - 1)
    endwhile
    return l:lnum
endfunction

function! s:IsSwitch(lnum)
    " Returns "true" if the given line is part of a switch block.
    let l:lnum = a:lnum
    let l:line = getline(l:lnum)
    let l:in_block = 0
    let l:stop_pat = '\v^\s*%(if|else|while|for|begin)>'
    let l:block_start_pat = '\v^\s*%(if|while|for|switch|begin)>'
    while l:lnum > 0
        let l:lnum = prevnonblank(l:lnum - 1)
        let l:line = getline(l:lnum)
        if l:line =~# '\v^\s*end>'
            let l:in_block += 1
        elseif l:in_block && l:line =~# l:block_start_pat
            let l:in_block -= 1
        elseif !l:in_block && l:line =~# l:stop_pat
            return 0
        elseif !l:in_block && l:line =~# '\v^\s*switch>'
            return 1
        endif
    endwhile
    return 0
endfunction

function! fish#Indent()
    let l:prevlnum = prevnonblank(v:lnum - 1)
    if l:prevlnum ==# 0
        return 0
    endif
    let l:prevline = getline(l:prevlnum)
    let l:line = getline(v:lnum)
    let l:shiftwidth = shiftwidth()
    let l:previndent = indent(l:prevlnum)
    let l:indent = l:previndent
    if l:prevline =~# '\v^\s*%(begin|if|else|while|for|function|switch|case)>'
        let l:indent += l:shiftwidth
    endif
    if l:line =~# '\v^\s*end>'
        let l:indent -= l:shiftwidth
        " If we're inside a case, dedent twice because it ends the switch.
        if l:prevline =~# '\v^\s*case>'
            " Previous line starts the case.
            let l:indent -= l:shiftwidth
        else
            " Scan back to a dedented line to find whether we're in a case.
            let l:i = l:prevlnum
            while l:i >= 1 && indent(l:i) >= l:previndent
                let l:i = prevnonblank(l:i - 1)
            endwhile
            if indent(l:i) < l:previndent && getline(l:i) =~# '\v^\s*case>'
                let l:indent -= l:shiftwidth
            endif
        endif
    elseif l:line =~# '\v^\s*else>'
        let l:indent -= l:shiftwidth
    elseif l:prevline !~# '\v^\s*switch>' && l:line =~# '\v^\s*case>'
        let l:indent -= l:shiftwidth
    endif
    if l:indent < 0
        return 0
    endif
    return l:indent
endfunction

function! fish#Format()
    if mode() =~# '\v^%(i|R)$'
        return 1
    else
        let l:command = v:lnum.','.(v:lnum+v:count-1).'!fish_indent'
        echo l:command
        execute l:command
        " Fix indentation and replace tabs with spaces if necessary.
        normal! '[=']
    endif
endfunction

function! fish#Fold()
    let l:line = getline(v:lnum)
    if l:line =~# '\v^\s*%(begin|if|while|for|function|switch)>'
        return 'a1'
    elseif l:line =~# '\v^\s*end>'
        return 's1'
    else
        return '='
    end
endfunction

function! fish#Complete(findstart, base)
    if a:findstart
        return getline('.') =~# '\v^\s*$' ? -1 : 0
    else
        if empty(a:base)
            return []
        endif
        let l:results = []
        let l:completions =
                    \ system('fish -c "complete -C'.shellescape(a:base).'"')
        let l:cmd = substitute(a:base, '\v\S+$', '', '')
        for l:line in filter(split(l:completions, '\n'), 'len(v:val)')
            let l:tokens = split(l:line, '\t')
            let l:term = l:tokens[0]
            if l:term =~? '^\V'.l:arg
                call add(l:results, {
                    \ 'word': l:cmd.l:term,
                    \ 'abbr': l:term,
                    \ 'menu': get(l:tokens, 1, ''),
                    \ 'dup': 1
                    \ })
            endif
        endfor
        return l:results
    endif
endfunction

function! fish#errorformat()
    return '%A<%t> fish: %m,%Efish: %m,%E%f (line %l): %m,%E%f (line %l):%.%#,%-Z%p^,%Ein %m,%Z	called on line %l of file %f,%Ein %m,%C%s,%-G%.%#'
endfunction

function! fish#Help(ref) abort
    let l:ref = a:ref
    if empty(a:ref)
        " let l:ref = &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>')
        let l:ref = expand('<cword>')
        if empty(l:ref)
            call s:fish_help_error('no identifier under cursor')
            return
        endif
    endif
    let l:output = systemlist('fish -c "man -w ' . shellescape(l:ref) . '"')
    if v:shell_error
        call s:fish_help_error(printf('command exited with code %d: %s', v:shell_error, join(l:output)))
        return
    endif
    aug ft_man_fish
        au FileType man
          \ setlocal nobuflisted
          \ | setlocal keywordprg=:FishHelp'
          \ | nnoremap <silent> <buffer> K :FishHelp<cr>
          \ | nnoremap <silent> <buffer> <C-]> :FishHelp<cr>
    aug END
    execute 'Man ' . l:output[0]
    silent aug! ft_man_fish
endfunction

function! s:fish_help_error(message)
    echohl ErrorMsg
    echon 'FishHelp: ' a:message
    echohl NONE
endfunction
