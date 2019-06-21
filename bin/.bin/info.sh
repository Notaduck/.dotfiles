#!/bin/env sh

date(){
	command date +"%H:%M %a %d/%m-%y"
}

while true
do
	xsetroot -name " $(date)"
	sleep 1m
done 
