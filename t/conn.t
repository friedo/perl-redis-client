#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 5;

use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;

    skip 4, 'No Redis server available' unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';
    
    my $result = $redis->echo( 'foobar' );
    
    is $result, 'foobar';

    eval { $redis->echo( 'too', 'many', 'args' ) };

    like $@, qr/requires 1 argument/;
}


