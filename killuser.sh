#!/bin/sh

ps -auxww -U $1 \
| grep -E "loginwindow" \
| tr -s ' ' \
| cut -d ' ' -f 2 \
| xargs -n 1 sudo kill -KILL

sleep 20

ps -auxww -U $1 \
| sed '1,1d' \
| tr -s ' ' \
| cut -d ' ' -f 2 \
| xargs -n 1 sudo kill -KILL
