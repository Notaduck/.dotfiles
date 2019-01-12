
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

if !has('python') && !has('pip')
	call system('pip install --upgrade pip')
	call system('pip install neovim --upgrade')
	"echo system('Installing upgrade pip and install neovim')
endif

if !has('python3') && !has('pip3')
	call system('pip3 install --upgrade pip')
	call system('pip3 install neovim --upgrade')
	"echo system('Installing upgrade pip3 and install neovim')
endif

if !has('~/.vim/tmp/')
	call system('mkdir -p ~/.vim/tmp')
endif

"if !has('npm')
"	call system('sudo pacman -S nodejs npm')
	"echo system('installing nodejs and npm')
"endif

"if !has('eslint')
"	call system('sudo npm install -g eslint')
	"echo system('installing eslint')
"endif

let g:python_host_skip_check = 1
let g:python2_host_skip_check = 1
let g:python3_host_skip_check = 1

if executable('python2.7')
	"let g:python_host_prog = system('which python')
	let g:python_host_prog = "/usr/bin/python2.7"
endif

if executable('python3')
	"let g:python3_host_prog = system('which python3')
	let g:python3_host_prog = "/usr/bin/python3"
endif

" }}} 

 " Plugin section {{{
" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'

"required
call plug#begin('~/local/share/nvim/plugged')
Plug 'epilande/vim-es2015-snippets'
Plug 'epilande/vim-react-snippets'
Plug 'mattn/emmet-vim'
Plug 'jiangmiao/auto-pairs'
Plug 'mhinz/vim-startify'
Plug 'honza/vim-snippets'
Plug 'junegunn/goyo.vim'
Plug 'kien/ctrlp.vim'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-after'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'junegunn/limelight.vim'
"Plug 'lervag/vimtex', { 'for': 'latex' }
Plug 'lervag/vimtex'
Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'matze/vim-move'
Plug 'tpope/vim-fugitive'
Plug 'w0rp/ale' 
Plug 'artur-shaik/vim-javacomplete2', { 'for': 'java' } 
Plug 'airblade/vim-gitgutter'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'SirVer/ultisnips'
Plug 'zchee/deoplete-jedi', {'for': ['python', 'python3','djangohtml'], 'do': 'pip install jedi;pip3 install jedi'}
Plug 'lilydjwg/colorizer', {'do': 'make'} " colorize rgb rgba texts
Plug 'scrooloose/nerdtree'
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif

" Themes {{{
Plug 'NLKNguyen/papercolor-theme'
Plug	'ajh17/Spacegray.vim'
" }}}


" Initialize plugin system
call plug#end()

 "}}}

" Colours and UI {{{

 " PaperColor
 let g:PaperColor_Theme_Options = {
	\	'theme': {
	\		'default.light': {
	\		  'override' : {
	\			'color00' : ['#dfddd5',''],
	\			'linenumber_bg' : ['#dfddd5', '232'],
	\			'vertsplit_bg' : ['#dfddd5', '255'],
	\		  }
	\		}
	\	}
	\ }
set laststatus=2
colorscheme PaperColor
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


colorscheme PaperColor 
" set background=dark " for the dark version
set background=light " for the light version



" }}}

" General settings {{{
set directory^=$HOME/.vim/tmp// " Place all swap files under .vim/tmp
set clipboard=unnamedplus " Let vim use the systems clipboard
set mouse=a "Enable mouse support
syntax on "Enable syntax
set number "Set line number
set cursorline "Highligt currentline 
filetype plugin indent on  
set autowriteall ""automatically save any changes made to the buffer before it is hidden.

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
" Run current Python file
nnoremap <Leader>p :exec '!python' shellescape(@%, 1)<cr>
" space open/closes folds
nnoremap <space> za

"Run makefile
noremap <Leader>m :make <CR>

" open main pdf
noremap <Leader>p :! nohup zathura ./main.pdf &<CR><CR>

" Set spell checking
map <F5> :setlocal spell! spelllang=da,en_us<CR>
"}}}

" Indentation {{{
" by default, the indent is 2 spaces. 
set shiftwidth=2
set softtabstop=2
set tabstop=2

" for html/js files, 2 spaces
autocmd Filetype html setlocal ts=2 sw=2 expandtab
autocmd Filetype javascript setlocal ts=2 sw=2 sts=0 expandtab

" for java/python files, 4 spaces
autocmd Filetype python setlocal ts=4 sw=4 sts=0 expandtab
autocmd Filetype java setlocal ts=4 sw=4 sts=0 expandtab
"}}}

" AutoGroup settings{{{

		augroup AutoGroup
		autocmd!
		augroup END

		command! -nargs=* Autocmd autocmd AutoGroup <args>
		command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>

		" }}}

	" }}}
	
 " Settings for various plugins {{{


" Use Alt+j/k to easily move a line
let g:move_key_modifier = 'A' 
" ALE {{{

let g:ale_enable = 1 
let g:ale_completion_enabled = 1
let g:ale_sign_column_always = 1 " Keeps the error column open

let g:ale_sign_error = '=>'
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
let g:ale_java_javac_classpath = "/home/daniel/java/algs4.jar"

let g:ale_linters = {
		\	'javascript': ['eslint'],
		\	'java': ['javac','javac-algs4'],
		\	'php': ['php', 'phpcs', 'phpmd'],
		\	'go': ['go build', 'gometalinter'],
		\	'rust': ['rustc'],
		\	'html': ['tidy', 'htmlhint'],
		\	'c': ['clang'],
		\	'cpp': ['clang++'],
		\	'css': ['csslint', 'stylelint'],
		\	'nim': ['nim', 'nimsuggest'],
		\	'vim': ['vint'],
		\	'python': ['autopep8'],
		\	'shell': ['sh', 'shellcheck'],
		\	'zsh': ['zsh'],
		\	'swift': ['swiftc'],
		\	'json' : ['prettier'],
		\	'yml' : ['prettier'],
		\	'yaml' : ['prettier'],
		\}

let g:ale_fixers = {
		\	'javascript': ['eslint','prettier_eslint'],
		\	'java': ['google_java_format'],
		\	'json' : ['prettier'],
		\}
"  }} }
"}}}

" Airline {{{ 

let g:airline_theme='papercolor'
let g:airline#extensions#tabline#formatter = 'default'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#enabled = 'ale'


" }}}

" Autor Pair Gentle{{{

	let g:AutoPairsUseInsertedCount = 1

let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'
	 "}}}

" Autoclose-tag {{{

	let g:closetag_filenames = "*.html,*.xhtml,*.phtml,*.php,*.jsx,*.js"

" }}}

" CtrlP{{{
	let g:ctrlp_by_filename = 1
	" let g:ctrlp_match_window_bottom = 0
	" let g:ctrlp_match_window_reversed = 0
	 
	" Ignore some folders and files for CtrlP indexing
	let g:ctrlp_custom_ignore = {
		\ 'dir': 'node_modules\|DS_Store\|.git'
		\ }
"}}}

" Deoplete {{{

let g:deoplete#enable_at_startup = 1
let g:deoplete#omni_patterns = {}
let g:deoplete#auto_completion_start_length = 1
let g:deoplete#omni_patterns.java = '[^. *\t]\.\w*'
let g:deoplete#sources = {}
let g:deoplete#sources._ = []
let g:deoplete#file#enable_buffer_path = 1

let g:deoplete#sources#ternjs#types = 1
let g:deoplete#sources#ternjs#types = 1
let g:deoplete#sources#ternjs#sort = 0

" Binary path to your flow, defaults to your $PATH flow 
let g:deoplete#sources#flow#flow_bin = 'flow' 
"call deoplete#custom#set('ultisnips', 'matchers', ['matcher_fuzzy'])
"call deoplete#custom#set('_', 'sorters', ['sorter_word'])
"call deoplete#custom#set('ultisnips', 'rank', 9999)

call deoplete#custom#source('ultisnips', 'matchers', ['matcher_fuzzy'])
call deoplete#custom#source('_', 'sorters', ['sorter_word'])
call deoplete#custom#source('ultisnips', 'rank', 9999)

" Deoplete tab-completion
" inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"

	" }}}

" Gitgutter {{{
	
		" Keeps nvim snappy (disable gitgutter if a file has more than n changes)
		let g:gitgutter_max_signs = 500  " default value
		let g:gitgutter_sign_added = '|'
		let g:gitgutter_sign_removed = '|'
		let g:gitgutter_sign_modified = '|'
		let g:gitgutter_async = 1

" }}}

" JavaComplete {{{

set omnifunc=syntaxcomplete#Complete
let g:JavaComplete_LibsPath = "/home/daniel/java/algs4.jar"
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

" }}}

" Mysql pipe {{{
" MySQL
" let g:dbext_default_profile_mysql_local = 'type=MYSQL:user=root:dbname=sports'
" }}}

 " UtilSnips {{{

" let g:UltiSnipsSnippetDirectories = ['/home/daniel/.vim/UltiSnips', 'UltiSnips']
let g:UltiSnipsSnippetDirectories = ['/home/daniel/.dotfiles/neovim/.config/nvim/UltiSnips', 'UltiSnips']

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
	"}}}
	
	" WhichKey {{{

	" }}}
