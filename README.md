```  
██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗  
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝  
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗  
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║  
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║  
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝                                                               
```
### Description
> - Browser == `Firefox` 
> - Network manager == `networkmanager_dmenu` 
> - PDF viewer == `Zathura`
> - Program launcher == `dmenu` 
> - Terminal == `st` 
> - Text editor == `neovim`
> - Window manager == `dwm`
> - Shell == `ZSH`


### Installation

##

##

The dotfiles are managed with stow and are thefore dead simple to install and uninstall again.  
If you aren't sure about what you are doing then please make a backup of your current dootfiles.  
#### Requirements
- [GNU stow](https://www.gnu.org/software/stow/)

To clone this repository along with its submodules, run:
```
git clone --recursive https://github.com/notaduck/.dotfiles.git ~/.dotfiles
```
If you’ve already cloned the repository without the submodules, you can initialize and update them by running:
```sh
git submodule update --init --recursive
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
stow nvim
```
you can now see that `init.vim` points to `.config/nvim/init.vim -> ../../.dotfiles/neovim/.config/nvim/init.vim`
and stow wil automaticly create symblinks to `~/.config/nvim/init.vim`, in order to uninstall the dotfiles again you can simply have to run:
```
stow -Dv <conf-dir>
```
where the `D` stands for delete and `v` is to increase the verbosity level, which you can change whitin an range from [0,1,2,3,4]

### Screenshots

#### dwm
![alt texxt](https://i.imgur.com/ijEdETz.png)  
![alt texxt](https://i.imgur.com/ljf56Ka.png)  
![alt texxt](https://i.imgur.com/Yukl747.png)  
 <!-- ![alt texxt](https://i.imgur.com/pHEGg3i.png) -->


#### ~~i3~~
![alt text](https://i.imgur.com/CMjN0CF.jpg "Clean")
![alt text](https://i.imgur.com/sLYPCZQ.jpg "Zathura and ")
![alt text](https://i.imgur.com/cA3L5dw.jpg "Stow dir and neofetch")
![alt text](https://i.imgur.com/4p3Ikoj.jpg "Dotfiles and nvim conf")
