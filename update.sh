#!/bin/bash

addon_dir=$1
addon_name=$(basename $addon_dir)
addon_icon="$addon_dir$addonName.jpg"
gmod_bin=$HOME/.steam/steam/steamapps/common/GarrysMod/bin
workshop_id=$(cat "$addon_dir$addon_name.id")
LD_LIBRARY_PATH=$gmod_bin $gmod_bin/gmpublish_linux update -id $workshop_id -addon "$addon_dir$addon_name.gma" -icon $addon_icon
