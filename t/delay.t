#!/usr/bin/perl

# Tests for ngx_http_delay_module.

###############################################################################

use warnings;
use strict;

use Test::More;
use Time::HiRes qw/ time /;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http ngx_http_delay_module/)->plan(6);

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        delay 80ms;

        location = /inherit {
            alias %%TESTDIR%%/ok;
        }

        location = /slow {
            delay 200ms;
            alias %%TESTDIR%%/ok;
        }

        location = /fast {
            delay 0;
            alias %%TESTDIR%%/ok;
        }
    }
}

EOF

$t->write_file('ok', 'ok');
$t->run();

###############################################################################

my ($response, $elapsed);

($response, $elapsed) = timed_get('/slow');
like($response, qr/200 OK/, 'delayed response');
cmp_ok($elapsed, '>=', 0.15, 'configured delay elapsed');

($response, $elapsed) = timed_get('/inherit');
like($response, qr/200 OK/, 'inherited delayed response');
cmp_ok($elapsed, '>=', 0.05, 'inherited delay elapsed');

($response, $elapsed) = timed_get('/fast');
like($response, qr/200 OK/, 'zero delay response');
cmp_ok($elapsed, '<', 0.15, 'zero delay has no material wait');

###############################################################################

sub timed_get {
	my ($uri) = @_;
	my $start = time();
	my $response = http_get($uri);
	return ($response, time() - $start);
}

###############################################################################
