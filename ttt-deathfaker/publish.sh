#!/bin/bash

gmod_bin=$HOME/.steam/steam/steamapps/common/GarrysMod/bin
gma="deathfaker.gma"
icon="workshop-icon.jpg"
LD_LIBRARY_PATH=$gmod_bin $gmod_bin/gmpublish_linux create -addon $gma -icon $icon
