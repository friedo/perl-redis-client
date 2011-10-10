#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 10;
use RedisClientTest;
use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;

    skip 'No Redis server available', 9 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';
    
    foreach my $key( 'foo', 'bar', 'baz' ) { 
        my $res = $redis->hset( 'perl_redis_test_hash', $key => 1 );
        is $res, 1;
    }

    my @keys = sort { $a cmp $b } $redis->hkeys( 'perl_redis_test_hash' );

    ok $keys[0] eq 'bar';
    ok $keys[1] eq 'baz';
    ok $keys[2] eq 'foo';

    ok $redis->del( 'perl_redis_test_hash' );
}

