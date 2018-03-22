filetype off                  " required
"let g:solarized_termcolors=256

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" Add all your plugins here (note older versions of Vundle used Bundle instead of Plugin)
Plugin 'scrooloose/nerdtree'
Plugin 'Yggdroot/indentLine'
Plugin 'jiangmiao/auto-pairs'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'NLKNguyen/papercolor-theme'
Plugin 'tpope/vim-fugitive'
Plugin 'thinca/vim-fontzoom'
Plugin 'airblade/vim-gitgutter'
Plugin 'matze/vim-move'
Plugin 'gelguy/Cmd2.vim'
Plugin 'mbbill/undotree'
"Plugin 'nightsense/office'
Plugin 'cj/vim-webdevicons'
Plugin 'powerline/fonts'
Plugin 'chrisbra/Colorizer'


" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
 
" PaperColor
let g:airline_theme='papercolor'
let g:PaperColor_Theme_Options = {
  \   'theme': {
  \     'default.light': {
  \       'override' : {
  \         'color00' : ['#dfddd5','']
  \       }
  \     }
  \   }
  \ }
colorscheme PaperColor
set background=light

set t_Co=256
"set bg=light
"color PaperColor
set clipboard=unnamed
set mouse=v "Enable mouse support
syntax on "Enable syntax
set number "Set line number

" AirLine settings
"!let g:airline_theme="solarized"
"!let g:airline_solarized_bg='dark'
let g:airline#extensions#tabline#formatter = 'default'
let g:airline#extensions#tabline#enabled = 1

" Nerdtree settings
"
" Open NERDTree when no file(s) is selectedd
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" Open NERDTree when a dir is opened
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p

" close vim if the only window left open is a NERDTree
map <C-n> :NERDTreeToggle<CR> " Open NERDTree with Ctrl+n

" vertical line indentation
let g:indentLine_color_term = 239
let g:indentLine_color_gui = '#09AA08'
let g:indentLine_char = '│'

" use 4 spaces for tabs
set tabstop=4 softtabstop=4 shiftwidth=4

" convert spaces to tabs when reading file
autocmd! bufreadpost * set noexpandtab | retab! 4

" convert tabs to spaces before writing file
autocmd! bufwritepre * set expandtab | retab! 4

" convert spaces to tabs after writing file (to show guides again)
autocmd! bufwritepost * set noexpandtab | retab! 4i

" fols settings
set foldmethod=indent
set foldnestmax=10
set nofoldenable
set foldlevel=2

" Auto close brackets, quotes ect.
let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'

let g:gitgutter_max_signs = 500  " default value

"""""""""""""""""""""""""""""""""""""""""""""""
"" Use Ctrl+j/k to easily move a line"""""
"""""""""""""""""""""""""""""""""""""""""""""""
let g:move_key_modifier = 'C'

