#!/usr/bin/env bash

for conf in `ls .`;
do
    ( stow $conf )
done
