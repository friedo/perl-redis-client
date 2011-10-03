#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 11;

use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;
    
    skip 'No Redis server available', 10 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';

    my $result = $redis->set( perl_redis_client_test => 'foobar' );
    
    is $result, 'OK';

    my $result2 = $redis->del( 'perl_redis_client_test' );

    is $result2, 1;

    for ( 1..5 ) { 
        my $res = $redis->set( "perl_redis_client_test:$_" => "foobar $_" );
        is $res, 'OK';
    }

    my @keys = map { "perl_redis_client_test:$_" } 1..5;

    my $res3 = $redis->del( @keys );

    is $res3, 5;
}

