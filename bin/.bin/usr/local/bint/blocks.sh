#!/bin/sh
#
# colorbars - smpte color bars in sh
# http://git.io/colorbars 

blocks() {
    echo
    for i in {0..7}; do echo -n "\e[4${i}m  \e[0m ";    done
    echo
    for i in {0..7}; do echo -n "\e[10${i}m  \e[0m ";    done
    echo -e "\n"
}
