#!/bin/sh

ps -U "$1" -xww -o pid,user,command \
  | sed "1,1d" \
  | grep "loginwindow" \
  | awk "{ print \$1 }" \
  | xargs -n 1 sudo kill -9

sleep 20

ps -U "$1" -xww -o pid,user,command \
  | sed "1,1d" \
  | awk "{ print \$1 }" \
  | xargs -n 1 sudo kill -9

