#!/bin/bash

addon_dir=$1
addon_name=$(basename $addon_dir)
gmod_bin=$HOME/.steam/steam/steamapps/common/GarrysMod/bin
$gmod_bin/gmad_linux create -folder $addon_dir -out $addon_dir$addon_name
