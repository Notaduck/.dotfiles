""" Enable folding
" set foldmethod=indent
" set foldlevel=99 Run current Python file
"let python_highlight_all=1
" PEP8 indent
 au BufNewFile,BufRead *.py
     \ set tabstop=4
     \ set softtabstop=4
     \ set shiftwidth=4
     \ set textwidth=79
     \ set expandtab
     \ set autoindent
     \ set fileformat=unix

"" Flagging Unnecessary Whitespace
" au BufRead,BufNewFile *.py match BadWhitespace /\s\+$/

"set encoding=utf-8

""python with virtualenv support
"py << EOF
"import os
"import sys
"if 'VIRTUAL_ENV' in os.environ:
"  project_base_dir = os.environ['VIRTUAL_ENV']
"  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
"  execfile(activate_this, dict(__file__=activate_this))
"EOF

