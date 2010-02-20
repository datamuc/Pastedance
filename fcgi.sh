#!/bin/sh

plackup --server FCGI --listen /tmp/pastedance.fcgi --nproc 5 --detach 1 \
        --pidfile /home/danielt/vc/git/Pastedance/paste.pid
