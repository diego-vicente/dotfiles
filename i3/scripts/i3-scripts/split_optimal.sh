#!/bin/sh
xdotool getactivewindow getwindowgeometry | awk '/Geometry/{split($2, dim, "x"); if (dim[1] > dim[2]) {exit 1}}' && i3-msg split vertical || i3-msg split horizontal
