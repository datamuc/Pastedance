#!/bin/sh
export LD_LIBRARY_PATH=/opt/python/2_007_000/lib
    /opt/perl/perls/perl-5.16.3/bin/starman \
        -D --preload-app --listen 127.0.0.1:6300 --workers 5 \
        -E production --pid $PWD/paste.pid bin/app.pl 2> logs/stderr.log
