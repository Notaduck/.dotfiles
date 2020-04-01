"███╗ 	██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
"████╗	██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
"██╔██╗ ██║█████╗  ██║	 ██║██║   ██║██║██╔████╔██║
"██║╚██╗██║██╔══╝  ██║	 ██║╚██╗ ██╔╝██║██║╚██╔╝██║
"██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
"╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝ 		╚═╝

 " Plugin dependencies {{{

" Installs Plug if it isn't allready installed

if has('vim_starting')
	set runtimepath+=~/.config/nvim/plugged/vim-plug
	if !isdirectory(expand('$NVIM_HOME') . '/plugged/vim-plug')
		call system('mkdir -p ~/.config/nvim/plugged/vim-plug')
		call system('git clone https://github.com/junegunn/vim-plug.git ~/.config/nvim/plugged/vim-plug/autoload')
"		echo system('"Installing vim-plug"')
	end
endif


"" }}} 

 " Plugin section {{{

"required
call plug#begin('~/.local/share/nvim/plugged')

" Plug 'alvan/vim-closetag'

Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }

Plug 'ionide/Ionide-vim', {
      \ 'do':  'make fsautocomplete',
      \}

" Syntax support
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }
Plug 'vim-scripts/bash-support.vim' 
Plug 'mxw/vim-jsx'
Plug 'moll/vim-node'
Plug 'pearofducks/ansible-vim'
Plug 'moll/vim-node'
" Plug 'vim-illuminate'

" Utilities
Plug 'aserebryakov/vim-todo-lists'
Plug 'mhinz/vim-startify'
Plug 'kien/ctrlp.vim'
Plug 'lilydjwg/colorizer', {'do': 'make'} " colorize rgb rgba texts
Plug 'airblade/vim-gitgutter'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Text formatting
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'

" Writing 
Plug 'vim-pandoc/vim-pandoc' 
Plug 'vim-pandoc/vim-pandoc-after' 
Plug 'vim-pandoc/vim-pandoc-syntax' 
Plug 'lervag/vimtex'
Plug 'conornewton/vim-pandoc-markdown-preview' 
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'matze/vim-move'
Plug 'tpope/vim-fugitive'

" UI
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'junegunn/limelight.vim'
Plug 'junegunn/goyo.vim'
Plug 'scrooloose/nerdtree'


" Autocompletion and Code checker
Plug 'w0rp/ale' 
" Plug 'SirVer/ultisnips'
" Plug 'honza/vim-snippets'

" Themes {{{
	Plug 'joshdick/onedark.vim'
	Plug 'rakr/vim-one'
" }}}

" Initialize plugin system
call plug#end()


augroup ColorOverrides
	autocmd!
	autocmd ColorScheme nord highlight Conceal guibg=NONE ctermbg=NONE
augroup end

set laststatus=2

if (empty($TMUX))
  if (has("nvim"))
  "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  if (has("termguicolors"))
	set termguicolors
  endif
endif

colorscheme onedark

" }}}

" General settings {{{
" set runtimepath+=/home/$USER/.vim/deoplete

set directory^=$HOME/.vim/tmp// " Place all swap files under .vim/tmp
set clipboard=unnamedplus " Let vim use the systems clipboard
set mouse=a "Enable mouse support
syntax on "Enable syntax
set number "Set line number
set cursorline "Highligt currentline 
filetype plugin indent on  
set autowriteall ""automatically save any changes made to the buffer before it is hidden.

" setlocal spell
" set spelllang=da,en_us

"" Code Folding
set foldmethod=marker

" Maintain undo history between sessions
set undofile	
set undodir=~/.vim/undodir

cmap w!! call SudoWrite()

" let g:python_host_prog = "/usr/bin/python"
" let g:python3_host_prog = "/usr/bin/python3"

" Filteypes{{{
	" autocmd filetype *.sql set filetype=mysql 
"}}}

"Shortcuts {{{

	" space open/closes folds
	nnoremap <space> za

	"Run makefile
	noremap <Leader>m :make <CR>

	" open main.pdf with zathura
	noremap <Leader>p :! nohup zathura ./main.pdf &<CR><CR>

	" Set spell checking
	map <F5> :setlocal spell! spelllang=da,en_us<CR>
	" correct the error from left to right
	inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u

	inoremap <C-f> <Esc>: silent exec '.!inkscape-figures create "'.getline('.').'" "'.b:vimtex.root.'/figures/"'<CR><CR>:w<CR>
	nnoremap <C-f> : silent exec '!inkscape-figures edit "'.b:vimtex.root.'/figures/" > /dev/null 2>&1 &'<CR><CR>:redraw!<CR>

"}}}

" Indentation {{{

	set shiftwidth=2
	set softtabstop=2
	set tabstop=2

"}}}

" AutoGroup settings{{{

		" augroup AutoGroup
		" autocmd!
		" augroup END

		" command! -nargs=* Autocmd autocmd AutoGroup <args>
		" command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>


		augroup myvimrchooks
				au!
				autocmd bufwritepost init.vim source ~/.config/nvim/init.vim
		augroup END
		"}}}

	" }}}

" Plugin Settings {{{

let g:move_key_modifier = 'C' 

" ALE {{{

	let g:ale_enable = 1 
	let g:ale_completion_enabled = 1
	let g:ale_sign_column_always = 1 " Keeps the error column open

	" let g:ale_sign_error = '=>'
	let g:ale_sign_error = ''
	let g:ale_sign_warning = '>?'

	let g:ale_echo_msg_error_str = 'E'
	let g:ale_echo_msg_warning_str = 'W'
	let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'

	let g:ale_fix_on_save = 1

	let g:ale_linters = {
			\	'javascript': ['eslint'],
			\	'vim': ['vint'],
			\	'shell': ['sh', 'shellcheck'],
			\	'zsh': ['zsh'],
			\	'json' : ['prettier'],
			\}

	let g:ale_fixers = {
			\	'javascript': ['eslint','prettier_eslint'],
			\	'json' : ['prettier'],
			\	'sh' : ['shfmt'],
			\}
"  }} }
"}}}

" Airline {{{ 

let g:airline_theme='papercolor'
let g:airline_theme='onedark'

" air-line
let g:airline_powerline_fonts = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" " unicode symbols
" let g:airline_left_sep = '»'
" let g:airline_left_sep = '▶'
" let g:airline_right_sep = '«'
" let g:airline_right_sep = '◀'
" let g:airline_symbols.linenr = '␊'
" let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = ''
" let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
" let g:airline_symbols.paste = '∥'
" let g:airline_symbols.whitespace = 'Ξ'

" " airline symbols
" let g:airline_left_sep = ''
" let g:airline_left_alt_sep = ''
" let g:airline_right_sep = ''
" let g:airline_right_alt_sep = ''
" let g:airline_symbols.branch = ''
" let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''
" let g:airline_whitespace_disabled = 1
" let g:airline#extensions#tabline#formatter = 'default'
" let g:airline#extensions#tabline#enabled = 1
" let g:airline#extensions#ale#enabled = 1
" let g:airline#extensions#enabled = 'ale'
" let g:airline_powerline_fonts = 1


" }}}

" Autor Pair Gentle{{{

	let g:AutoPairsUseInsertedCount = 1

	let g:AutoPairsFlyMode = 0
	let g:AutoPairsShortcutBackInsert = '<M-b>'
	 "}}}

" Autoclose-tag {{{
	" let g:closetag_filenames = "*.html,*.xhtml,*.phtml,*.php,*.jsx,*.js"

" }}}

" coc {{{

  " Setup formatexpr specified filetype(s).
	" if hidden is not set, TextEdit might fail.
	set hidden

	" Some servers have issues with backup files, see #649
	set nobackup
	set nowritebackup
 
	" Better display for messages
	set cmdheight=2

	" You will have bad experience for diagnostic messages when it's default 4000.
	set updatetime=300

	" don't give |ins-completion-menu| messages.
	set shortmess+=c

	" always show signcolumns
	set signcolumn=yes

	command! -nargs=0 Prettier :CocCommand prettier.formatFile

	" Use tab for trigger completion with characters ahead and navigate.
	" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
	inoremap <silent><expr> <TAB>
				\ pumvisible() ? "\<C-n>" :
				\ <SID>check_back_space() ? "\<TAB>" :
				\ coc#refresh()
	inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

	function! s:check_back_space() abort
		let col = col('.') - 1
		return !col || getline('.')[col - 1]  =~# '\s'
	endfunction

	" Use <c-space> to trigger completion.
	inoremap <silent><expr> <c-space> coc#refresh()

	" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
	" Coc only does snippet and additional edit on confirm.
	inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
	" Or use `complete_info` if your vim support it, like:
	" inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
	"

	" Use `[g` and `]g` to navigate diagnostics
	nmap <silent> [g <Plug>(coc-diagnostic-prev)
	nmap <silent> ]g <Plug>(coc-diagnostic-next)

	" Remap keys for gotos
	nmap <silent> gd <Plug>(coc-definition)
	nmap <silent> gy <Plug>(coc-type-definition)
	nmap <silent> gi <Plug>(coc-implementation)
	nmap <silent> gr <Plug>(coc-references)

	" Use K to show documentation in preview window
	nnoremap <silent> K :call <SID>show_documentation()<CR>

	function! s:show_documentation()
		if (index(['vim','help'], &filetype) >= 0)
			execute 'h '.expand('<cword>')
		else
			call CocAction('doHover')
		endif
	endfunction

	" Highlight symbol under cursor on CursorHold
	autocmd CursorHold * silent call CocActionAsync('highlight')

	" Remap for rename current word
	nmap <leader>rn <Plug>(coc-rename)
	" Remap for format selected region
	xmap <leader>f  <Plug>(coc-format-selected)
	nmap <leader>f  <Plug>(coc-format-selected)

	augroup mygroup
		autocmd!
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
" nmap <leader>ac  <Plug>(coc-codeaction)
" Fix autofix problem of current line
" nmap <leader>qf  <Plug>(coc-fix-current)

" Create mappings for function text object, requires document symbols feature of languageserver.
" xmap if <Plug>(coc-funcobj-i)
" xmap af <Plug>(coc-funcobj-a)
" omap if <Plug>(coc-funcobj-i)
" omap af <Plug>(coc-funcobj-a)


" Use <C-d> for select selections ranges, needs server support, like: coc-tsserver, coc-python
" nmap <silent> <C-d> <Plug>(coc-range-select)
" xmap <silent> <C-d> <Plug>(coc-range-select)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
" command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" use `:OR` for organize import of current buffer
" command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add status line support, for integration with other plugin, checkout `:h coc-status`
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Using CocList
" Show all diagnostics
" nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" " Manage extensions
" nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" " Show commands
" nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" " Find symbol of current document
" nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" " Search workspace symbols
" nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" " Do default action for next item.
" nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" " Do default action for previous item.
" nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" " Resume latest coc list
" nnoremap <silent> <space>p  :<C-u>CocListResume<CR>
let g:LanguageClient_serverCommands = {
    \ 'fsharp': ['dotnet', '/home/daniel/.config/coc/extensions/coc-fsharp-data/server/FSharpLanguageServer.dll']
    \ }
" }}}

"{{{ Ctrl P
	let g:ctrlp_by_filename = 1
	" let g:ctrlp_match_window_bottom = 0
	" let g:ctrlp_match_window_reversed = 0
	 
	" Ignore some folders and files for CtrlP indexing
	let g:ctrlp_custom_ignore = {
		\ 'dir': 'node_modules\|DS_Store\|.git',
		\ 'file': '.class',
		\}
"}}}

" Gitgutter {{{
	
		" Keeps nvim snappy (disable gitgutter if a file has more than n changes)
		let g:gitgutter_max_signs = 500  " default value
		let g:gitgutter_sign_added = '|'
		let g:gitgutter_sign_removed = '|'
		let g:gitgutter_sign_modified = '|'
		let g:gitgutter_async = 1

" }}}

" {{{ Goyo
	function! s:goyo_enter()
		let b:quitting = 0
		let b:quitting_bang = 0
		autocmd QuitPre <buffer> let b:quitting = 1
		cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!
	endfunction

	function! s:goyo_leave()
		" Quit Vim if this is the only remaining buffer
		if b:quitting && len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
			if b:quitting_bang
				qa!
			else
				qa
			endif
		endif
	endfunction

	autocmd! User GoyoEnter call <SID>goyo_enter()
	autocmd! User GoyoLeave call <SID>goyo_leave()
" }}}

" NerdTree {{{

" Open NERDTree when no file(s) is selectedd
" autocmd StdinReadPre * let s:std_in=1
" autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" close vim if the only window left open is a NERDTree
" map <C-n> :NERDTreeToggle<CR> " Open NERDTree with Ctrl+n

" Quit nertree when a file is opened.
" let NERDTreeQuitOnOpen = 1

"}}}

" Startify {{{

    let g:startify_bookmarks = [
            \ { 'c': '~/.config/nvim/init.vim' },
            \ { 'p': '~/.config/polybar/config'},
						\ { 'i': '~/.i3/config'}
            \ ]
" }}}

" Pandoc {{{

let b:pandoc_command_latex_engine = 'pdflatex'
let g:pandoc#filetypes#handled = ["pandoc", "markdown"]
let g:pandoc#filetypes#pandoc_markdown = 0
augroup pandoc_syntax
        au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
    augroup END

		" Preview {{{
			let g:md_pdf_engine='pdflatex'	
			let g:md_pdf_viewer='zathura'
		" }}}
" }}}

 " UtilSnips {{{

" let g:UltiSnipsSnippetDirectories = ['/home/daniel/.vim/UltiSnips', 'UltiSnips']
" let g:UltiSnipsSnippetDirectories = ['~/.dotfiles/config/.config/nvim/UltiSnips', 'UltiSnips']

"  " Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.

"  let g:UltiSnipsExpandTrigger="<a-tab>"
" let g:UltiSnipsJumpForwardTrigger="<c-b>"
" let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" " If you want :UltiSnipsEdit to split your window.
" let g:UltiSnipsEditSplit="vertical"

	" }}}

"  Illuminate {{{
	" Time in millis (default 250)
	" let g:Illuminate_delay = 250

	" let g:Illuminate_ftHighlightGroups = {
      " \ 'vim': ['vimVar', 'vimString', 'vimLineComment',
      " \         'vimFuncName', 'vimFunction', 'vimUserFunc', 'vimFunc']
      " \ }

	" let g:Illuminate_ftblacklist = ['nerdtree']

" }}}

" Vimtex {{{
let g:vimtex_view_method = 'zathura'
let g:vimtex_compiler_progname = 'nvr'
let g:tex_flavor = 'latex'
set conceallevel=2
" let g:tex_conceal='abdmg'
	"}}}
	
	"{{{ OmniSharp
	
		" let g:OmniSharp_server_stdio = 1
		" let g:OmniSharp_selector_ui = 'ctrlp'  " Use ctrlp.vim
	
	"}}}

" {{{ Commentray
	autocmd FileType pgsql setlocal commentstring=--\ %s
	autocmd FileType sql setlocal commentstring=--\ %s
" }}}
" }}}
