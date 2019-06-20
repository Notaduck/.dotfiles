 
```  
██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗  
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝  
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗  
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║  
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║  
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝                                                               
```
**THE SCREENSHOTS DOES NOT REFLECT THE CURRENT COLOR SCHEME (which is NORD)
In order to get the same colorscheme as the screenshot the terminal colorscheme should be changed with the following cmd `color PaperColour.fork` and vim's colorscheme should be changed as well.**

### Description

Some applications is crossed over, since I don't use them any more but the configuration files will still be in the repo.

> - Browser == `vivaldi` 
> - Compositor == `compton`
> - Network manager == `networkmanager_dmenu` 
> - Pdf viewer == `zathura`
> - Program launcher == `rofi` 
> - Terminal == `termite` 
> - Text editor == `neovim`
> - Window manager == ~~`i3wm`~~  `dwm`
> - Shell == `ZSH`


### Installation

The dotfiles are managed with stow and are thefore dead simple to install and uninstall again.  
If you aren't sure about what you are doing then please make a backup of your current dootfiles.  

#### Requirements
- [GNU stow](https://www.gnu.org/software/stow/)

First you will have to clone the repo.
```
git clone https://github.com/notaduck/.dotfiles.git ~/.dotfiles
```
Navigate to the newly cloned repo.
```
cd ~/.dotfiles
```
Now that you are in the dotfiles repository you simply have to rund the cmd:
```
stow <conf-dir>
```
Example:
```
stow neovim
```
you can now see that `init.vim` points to `.config/nvim/init.vim -> ../../.dotfiles/neovim/.config/nvim/init.vim`
and stow wil automaticly create symblinks to `~/.config/nvim/init.vim`, in order to uninstall the dotfiles again you can simply have to run:
```
stow -Dv <conf-dir>
```
where the `D` stands for delete and `v` is to increase the verbosity level, which you can change whitin an range from [0,1,2,3,4]

### Screenshots

#### dwm
![alt texxt](https://i.imgur.com/ixkxMAa.png)  
![alt texxt](https://i.imgur.com/lnlYrJi.png)  
![alt texxt](https://i.imgur.com/y0xOzLu.png)  
![alt texxt](https://i.imgur.com/pHEGg3i.png)  


#### i3

![alt text](https://i.imgur.com/CMjN0CF.jpg "Clean")
![alt text](https://i.imgur.com/sLYPCZQ.jpg "Zathura and ")
![alt text](https://i.imgur.com/cA3L5dw.jpg "Stow dir and neofetch")
![alt text](https://i.imgur.com/4p3Ikoj.jpg "Dotfiles and nvim conf")
