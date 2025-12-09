#!/usr/bin/env bash

SCR_PATH="pspath"
CACHE_PATH="pscache"

RESOURCES_PATH="$SCR_PATH/resources"
WINE_PREFIX="$SCR_PATH/prefix"
FILE_PATH=$(winepath -w "$1")

export WINEPREFIX="~/.WineApps/Adobe-Photoshop"

WINEPREFIX=~/.WineApps/Adobe-Photoshop DXVK_LOG_PATH=~/.WineApps/Adobe-Photoshop DXVK_STATE_CACHE_PATH=~/.WineApps/Adobe-Photoshop wine64 ~/.WineApps/Adobe-Photoshop/drive_c/Program\ Files/Adobe/Adobe\ Photoshop\ 2021/photoshop.exe $FILE_PATH
