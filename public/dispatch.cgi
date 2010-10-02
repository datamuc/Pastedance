#!/usr/bin/env perl
use Plack::Runner;
use Dancer;

my $psgi = path(setting('appdir'), 'bin', 'app.pl');
Plack::Runner->run($psgi);
