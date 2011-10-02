#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok 'Redis::Client';

my $redis = Redis::Client->new;

ok $redis;
isa_ok $redis, 'Redis::Client';

my $result = $redis->echo( 'foobar' );

is $result, 'foobar';

