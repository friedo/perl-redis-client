#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 9;
use RedisClientTest;
use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;

    skip 'No Redis server available', 8 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';
    
    my $result = $redis->set( perl_redis_test_var => "foobar" );
    
    is $result, 'OK';

    my $got = $redis->get( 'perl_redis_test_var', tied => 1 );

    isa_ok $got, 'Redis::Client::String';
    is $got, 'foobar';

    $got = 'narf';
    is $got, 'narf';

    # test round-trip
    my $got2 = $redis->get( 'perl_redis_test_var' );
    is $got2, 'narf';

    my $res = $redis->del( 'perl_redis_test_var' );
    is $res, 1;

}


