#!/bin/sh
export TERM=xterm-256color
export COLORTERM=truecolor
exec difft --color=always "$@"
