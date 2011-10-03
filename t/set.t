#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 4;

use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;
    
    skip 'No Redis server available', 3 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';

    my $result = $redis->set( perl_redis_client_test => 'foobar' );
    
    is $result, 'OK';
}

