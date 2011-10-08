#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 5;
use RedisClientTest;
use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;

    skip 'No Redis server available', 4 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';
    
    my $res = $redis->lpush( perl_redis_test_list => 42 );

    is $res, 1;

    my $res2 = $redis->del( 'perl_redis_test_list' );

    is $res2, 1;
}
