#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 8;

use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;
    
    skip 'No Redis server available', 7 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';

    $redis->set( redis_client_test_foo => 'foobar' );

    my $res = $redis->get( 'redis_client_test_foo' );
    is $res, 'foobar';

    ok $redis->del( 'redis_client_test_foo' );

    my $res2 = $redis->get( 'redis_client_test_not_exist' );
    ok !defined( $res2 );

    $redis->rpush( 'redis_client_test_list', 42 );
    my $res3 = eval { $redis->get( 'redis_client_test_list' ) };
    ok $@;
    like $@, qr/Operation against a key holding the wrong kind of value/;
}

