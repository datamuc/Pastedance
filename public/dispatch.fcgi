#!/usr/bin/env perl
use Plack::Handler::FCGI;
use Dancer;

my $psgi = path(setting('appdir'), 'bin', 'app.pl');
my $app = do($psgi);

my $server = Plack::Handler::FCGI->new(nproc  => 5, detach => 1);
$server->run($app);
