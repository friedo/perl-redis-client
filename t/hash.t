#!/usr/bin/env perl

use strict;
use warnings;

use lib 't';

use Test::More tests => 12;
use RedisClientTest;
use Redis::Client::Hash;

use_ok 'RedisClientTest';

SKIP: { 
    my $redis = RedisClientTest->server;

    skip 'No Redis server available', 11 unless $redis;
    
    ok $redis;
    isa_ok $redis, 'Redis::Client';

    my $val = 0;
    for( 'A' .. 'E' ) {
        my $result = $redis->hset( 'perl_redis_test_hash', $_ => ++$val );
        is $result, 1;
    }

    tie my %hash, 'Redis::Client::Hash', key => 'perl_redis_test_hash', client => $redis;

    for( 'F', 'G', 'H' ) { 
        $hash{$_} = ++$val;
    }

    is $hash{F}, 6;
    is $hash{G}, 7;
    is $hash{H}, 8;


    ok $redis->del( 'perl_redis_test_hash' );
}
