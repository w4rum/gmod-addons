#!/bin/bash

addon_dir=$1
addon_name=$(basename $addon_dir)
addon_icon="$addon_dir$addonName.jpg"
gmod_bin=$HOME/.steam/steam/steamapps/common/GarrysMod/bin
LD_LIBRARY_PATH=$gmod_bin $gmod_bin/gmpublish_linux create -addon $addon_dir$addon_name -icon $addon_icon
