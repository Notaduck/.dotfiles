" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'jiangmiao/auto-pairs'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'NLKNguyen/papercolor-theme'
Plug 'matze/vim-move'
Plug 'cj/vim-webdevicons'
Plug 'tpope/vim-fugitive'
Plug 'w0rp/ale' 
Plug 'artur-shaik/vim-javacomplete2'
Plug 'airblade/vim-gitgutter'
Plug 'JamshedVesuna/vim-markdown-preview' 
Plug 'xuhdev/vim-latex-live-preview', { 'for': 'tex' }
Plug 'donRaphaco/neotex', { 'for': 'tex' }

if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif

" Initialize plugin system
call plug#end()

" PaperColor
let g:PaperColor_Theme_Options = {
  \   'theme': {
  \     'default.light': {
  \       'override' : {
  \         'color00' : ['#dfddd5',''],
  \         'linenumber_bg' : ['#dfddd5', '232'],
  \         'vertsplit_bg' : ['#dfddd5', '255'],
  \       }
  \     }
  \   }
  \ }
colorscheme PaperColor
set background=light

set termguicolors
set clipboard=unnamed " Let vim use the systems clipboard
set mouse=a "Enable mouse support
syntax on "Enable syntax
set number "Set line number
set guicursor= "cursor us always a bloc
let g:syntastic_java_checkstyle_classpath = "/home/daniel/Downloads/algs4.jar"

filetype plugin indent on  
set omnifunc=syntaxcomplete#Complete
let g:JavaComplete_LibsPath = "/home/daniel/Downloads/algs4.jar"
autocmd FileType java setlocal omnifunc=javacomplete#Complete

" Keeps nvim snappy (disable gitgutter if a file has more than n changes)
let g:gitgutter_max_signs = 500  " default value

" Deoplete settings
let g:deoplete#enable_at_startup = 1
let g:deoplete#enable_at_startup = 1
let g:deoplete#omni_patterns = {}
let g:deoplete#auto_completion_start_length = 2
let g:deoplete#omni_patterns.java = '[^. *\t]\.\w*'
let g:deoplete#sources = {}
let g:deoplete#sources._ = []
let g:deoplete#file#enable_buffer_path = 1
" by default, the indent is 2 spaces. 
set shiftwidth=2
set softtabstop=2
set tabstop=2

" for html/rb files, 2 spaces
autocmd Filetype html setlocal ts=2 sw=2 expandtab
autocmd Filetype ruby setlocal ts=2 sw=2 expandtab

" for js/coffee/jade files, 4 spaces
autocmd Filetype javascript setlocal ts=4 sw=4 sts=0 expandtab
autocmd Filetype coffeescript setlocal ts=2 sw=2 sts=0 expandtab
autocmd Filetype jade setlocal ts=2 sw=2 sts=0 expandtab

" Deoplete tab-completion
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"

" AirLine settings
let g:airline_theme='papercolor'
let g:airline#extensions#tabline#formatter = 'default'
let g:airline#extensions#tabline#enabled = 1

" Enable ALE for airline 
let g:airline#extensions#ale#enabled = 1

" Nerdtree settings
" Open NERDTree when no file(s) is selectedd
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" close vim if the only window left open is a NERDTree
map <C-n> :NERDTreeToggle<CR> " Open NERDTree with Ctrl+n

" use 4 spaces for tabs
set tabstop=4 softtabstop=4 shiftwidth=4

" convert spaces to tabs when reading file
autocmd! bufreadpost * set noexpandtab | retab! 4

" convert tabs to spaces before writing file
autocmd! bufwritepre * set expandtab | retab! 4

" convert spaces to tabs after writing file (to show guides again)
autocmd! bufwritepost * set noexpandtab | retab! 4i


" Auto close brackets, quotes ect.
let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'

" Autoformat .js on save
autocmd FileType javascript set formatprg=prettier\ --stdin
"""""""""""""""""""""""""""""""""""""""""""""""
"" Use Ctrl+j/k to easily move a line"""""
"""""""""""""""""""""""""""""""""""""""""""""""
let g:move_key_modifier = 'A'

" ALE settings
"highlight clear ALEErrorSign " otherwise uses error bg color (typically red)
"highlight clear ALEWarningSign " otherwise uses error bg color (typically red)
"let g:ale_sign_error = '>' " could use emoji
"let g:ale_sign_warning = '?>' " could use emoji
"let g:ale_statusline_format = ['X %d', '? %d', '']
" %linter% is the name of the linter that provided the message
" %s is the error or warning message
"let g:ale_echo_msg_format = '%linter% says %s'
" Map keys to navigate between lines with errors and warnings.
"nnoremap <leader>an :ALENextWrap<cr>
"nnoremap <leader>ap :ALEPreviousWrap<cr>
let vim_markdown_preview_toggle=2
let vim_markdown_preview_github=1



let g:livepreview_previewer = 'zathura'

let g:neotex_enabled = 1
let g:neotex_delay = 1000
let g:tex_flavor = 'latex'
