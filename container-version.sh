#!/usr/bin/sh
# Old version parser: /usr/bin/duplicity --version | awk -F ' ' '{print "${2}"}' 
/usr/bin/duplicity --version | awk '{print $2}'
