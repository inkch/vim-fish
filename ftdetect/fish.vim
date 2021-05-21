autocmd BufRead,BufNewFile *.fish setfiletype fish

" Set filetype when using funced.
autocmd BufRead fish_funced.* setfiletype fish

" Move cursor to first empty line when using funced.
" autocmd BufRead fish_funced_*_*.fish call search('^$')

" Universal variable storages should not be hand edited.
autocmd BufRead,BufNewFile ~/.config/fish/fishd.* setlocal readonly

" Fish histories are YAML documents.
autocmd BufRead,BufNewFile ~/.config/fish/fish_{read_,}history setfiletype yaml

" Detect fish scripts by the shebang line.
autocmd BufRead *
            \ if getline(1) =~# '\v^#!%(\f*/|/usr/bin/env\s*<)fish>' |
            \     setlocal filetype=fish |
            \ endif

" Mimic `funced` when manually creating functions.
autocmd BufNewFile ~/.config/fish/functions/*.fish
            \ call append(0, ['function '.expand('%:t:r'),
                             \'',
                             \'end']) |
            \ 2
