#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

SKIP: { 
    unless( $ENV{PERL_REDIS_TEST_SERVER} ) {  
        skip 'No Redis server available', 4
    }

    use_ok 'RedisClientTest';

    my $redis = RedisClientTest->server;

    ok $redis;
    isa_ok $redis, 'Redis::Client';

    my $result = $redis->set( perl_redis_client_test => 'foobar' );
    
    is $result, 'OK';
}

