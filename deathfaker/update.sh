#!/bin/bash

gmod_bin=$HOME/.steam/steam/steamapps/common/GarrysMod/bin
gma="deathfaker.gma"
icon="workshop-icon.jpg"
id=912181642
LD_LIBRARY_PATH=$gmod_bin $gmod_bin/gmpublish_linux update -id $id -addon $gma -icon $icon
