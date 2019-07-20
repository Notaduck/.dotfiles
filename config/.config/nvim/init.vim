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
call plug#begin('~/local/share/nvim/plugged')


" Syntax support
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }
Plug 'vim-scripts/bash-support.vim' 
Plug 'mxw/vim-jsx'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'aklt/plantuml-syntax'

" Utilities
Plug 'aserebryakov/vim-todo-lists'
Plug 'mhinz/vim-startify'
Plug 'kien/ctrlp.vim'
Plug 'z0mbix/vim-shfmt', { 'for': 'sh' }
Plug 'lilydjwg/colorizer', {'do': 'make'} " colorize rgb rgba texts
Plug 'airblade/vim-gitgutter'
Plug 'weirongxu/plantuml-previewer.vim'
Plug 'tyru/open-browser.vim'

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
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'fsharp/vim-fsharp', {
			\ 'for': 'fsharp',
			\ 'do':  'make fsautocomplete',
			\}
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
" Plug 'ternjs/tern_for_vim', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'othree/jspc.vim', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'artur-shaik/vim-javacomplete2'
Plug 'deoplete-plugins/deoplete-jedi'

" Themes {{{
Plug 'NLKNguyen/papercolor-theme'
Plug 'chriskempson/base16-vim'
Plug 'arcticicestudio/nord-vim'
Plug	'ajh17/Spacegray.vim'
Plug 'joshdick/onedark.vim'
" }}}

" Initialize plugin system
call plug#end()

 "}}}

" Colours and UI {{{

 " PaperColor
 " let g:PaperColor_Theme_Options = {
	" \	'theme': {
	" \		'default.light': {
	" \		  'override' : {
	" \			'color00' : ['#dfddd5',''],
	" \			'linenumber_bg' : ['#dfddd5', '232'],
	" \			'vertsplit_bg' : ['#dfddd5', '255'],
	" \		  }
	" \		}
	" \	}
	" \ }
" colorscheme PaperColor
" colorscheme nord

augroup ColorOverrides
	autocmd!
	autocmd ColorScheme nord highlight Conceal guibg=NONE ctermbg=NONE
augroup end

set laststatus=2
"Credit joshdick
"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)

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
" set background=dark " for the dark version
" set background=light " for the light version

" }}}

" General settings {{{
set runtimepath+=/home/$USER/.vim/deoplete
set runtimepath+=/home/$USER/.vim/deoplete-fsharp

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

" " use 4 spaces for tabs
set tabstop=2 softtabstop=2 shiftwidth=2

"" Code Folding
set foldmethod=marker

" Maintain undo history between sessions
set undofile	
set undodir=~/.vim/undodir



" Filteypes{{{
	autocmd filetype *.sql set filetype=mysql 
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
" by default, the indent is 2 spaces. 
set shiftwidth=2
set softtabstop=2
set tabstop=2

" for html/js files, 2 spaces
au BufNewFile,BufRead *.js, *.html, *.css
    \ set tabstop=2
    \ set softtabstop=2
    \ set shiftwidth=2

" for java files, 4 spaces
autocmd Filetype java setlocal ts=4 sw=4 sts=0 expandtab
"}}}

" AutoGroup settings{{{

		augroup AutoGroup
		autocmd!
		augroup END

		command! -nargs=* Autocmd autocmd AutoGroup <args>
		command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>


		augroup myvimrchooks
				au!
				autocmd bufwritepost init.vim source ~/.config/nvim/init.vim
		augroup END
		" }}}

	" }}}

" Plugin Settings {{{
"
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

" Deoplete Python
AutocmdFT python let g:deoplete#sources#jedi#enable_cache = 1
AutocmdFT python let g:deoplete#sources#jedi#statement_length = 0
AutocmdFT python let g:deoplete#sources#jedi#short_types = 0
AutocmdFT python let g:deoplete#sources#jedi#show_docstring = 1
AutocmdFT python let g:deoplete#sources#jedi#worker_threads = 4
AutocmdFT python call deoplete#custom#source('jedi', 'disabled_syntaxes', ['Comment'])
AutocmdFT python call deoplete#custom#source('jedi', 'matchers', ['matcher_fuzzy'])



"let g:ale_java_javac_classpath = [String], to load aditional classes
" let g:ale_java_javac_classpath = "~/java/algs4.jar"
let g:ale_java_javac_classpath = "/usr/local/algs4/algs4.jar"

let g:ale_linters = {
		\	'javascript': ['eslint'],
		\	'java': ['javac','javac-algs4'],
		\	'php': ['php', 'phpcs', 'phpmd'],
		\	'go': ['go build', 'gometalinter'],
		\	'rust': ['rustc'],
		\	'html': ['tidy', 'htmlhint'],
		\	'c': ['clang', 'uncrustify'],
		\	'cpp': ['clang++'],
		\	'css': ['csslint', 'stylelint'],
		\	'nim': ['nim', 'nimsuggest'],
		\	'vim': ['vint'],
		\	'python': ['flake8','pylint'],
		\	'shell': ['sh', 'shellcheck'],
		\	'zsh': ['zsh'],
		\	'swift': ['swiftc'],
		\	'json' : ['prettier'],
		\	'yml' : ['prettier'],
		\	'yaml' : ['prettier'],
		\}

let g:ale_fixers = {
		\	'javascript': ['eslint','prettier_eslint'],
		\	'java': ['uncrustify','google_java_format'],
		\	'json' : ['prettier'],
		\	'sh' : ['shfmt'],
		\ 'python' : ['autopep8']
		\}
"  }} }
"}}}

" Airline {{{ 

" let g:airline_theme='papercolor'
let g:airline_theme='onedark'
let g:airline_whitespace_disabled = 1
let g:airline#extensions#tabline#formatter = 'default'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#enabled = 'ale'
let g:airline_powerline_fonts = 1


" }}}

" Autor Pair Gentle{{{

	let g:AutoPairsUseInsertedCount = 1

let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'
	 "}}}

" Autoclose-tag {{{

	let g:closetag_filenames = "*.html,*.xhtml,*.phtml,*.php,*.jsx,*.js"

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

" Deoplete {{{ 
set omnifunc=syntaxcomplete#Complete
autocmd FileType java setlocal omnifunc=javacomplete#Complete
  " Use deoplete.
	let g:deoplete#enable_at_startup = 1
	let g:deoplete#enable_at_startup = 1
	" let g:deoplete#omni_patterns.java = '[^. *\t]\.\w*'
	let g:deoplete#auto_completion_start_length = 2
	let g:deoplete#sources = {}
	let g:deoplete#sources._ = []
	let g:deoplete#file#enable_buffer_path = 1
	let g:deoplete#omni_patterns = {}

	"Add extra filetypes
	let g:deoplete#sources#ternjs#filetypes = [
									\ 'jsx',
									\ 'javascript.jsx',
									\ ]
	" }}}

" Gitgutter {{{
	
		" Keeps nvim snappy (disable gitgutter if a file has more than n changes)
		let g:gitgutter_max_signs = 500  " default value
		let g:gitgutter_sign_added = '|'
		let g:gitgutter_sign_removed = '|'
		let g:gitgutter_sign_modified = '|'
		let g:gitgutter_async = 1

" }}}

" {{{
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

" JavaComplete {{{

set omnifunc=syntaxcomplete#Complete
let g:JavaComplete_LibsPath = "~/java/algs4.jar"
autocmd FileType java setlocal omnifunc=javacomplete#Complete

nmap <F4> <Plug>(JavaComplete-Imports-AddSmart)

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

" Mysql pipe {{{
" MySQL
" let g:dbext_default_profile_mysql_local = 'type=MYSQL:user=root:dbname=sports'
" }}}

 " UtilSnips {{{

" let g:UltiSnipsSnippetDirectories = ['/home/daniel/.vim/UltiSnips', 'UltiSnips']
let g:UltiSnipsSnippetDirectories = ['~.dotfiles/neovim/.config/nvim/UltiSnips', 'UltiSnips']

 " Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.

" let g:UltiSnipsExpandTrigger="<a-tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

	" }}}

"  Illuminate {{{
	" Time in millis (default 250)
	let g:Illuminate_delay = 250

	let g:Illuminate_ftHighlightGroups = {
      \ 'vim': ['vimVar', 'vimString', 'vimLineComment',
      \         'vimFuncName', 'vimFunction', 'vimUserFunc', 'vimFunc']
      \ }

	let g:Illuminate_ftblacklist = ['nerdtree']

" }}}

" Vimtex {{{
let g:vimtex_view_method = 'zathura'
let g:vimtex_compiler_progname = 'nvr'
let g:tex_flavor = 'latex'
set conceallevel=2
" let g:tex_conceal='abdmg'
	"}}}
	

" }}}
