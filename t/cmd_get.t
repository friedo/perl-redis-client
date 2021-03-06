#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use lib 't';

use Test::More;

# ABSTRACT: Tests for the Redis GET command.

use_ok 'RedisClientTest';

my $redis = RedisClientTest->server;
done_testing && exit unless $redis;

isa_ok $redis, 'Redis::Client';

$redis->set( perl_redis_test_get => 'foobar' );

my $val = $redis->get( 'perl_redis_test_get' );

is $val, 'foobar';

ok $redis->del( 'perl_redis_test_get' );

$redis->lpush( perl_redis_test_list => 1 );

eval { $redis->get( 'perl_redis_test_list' ) };

like $@, qr/wrong kind of value/;

ok $redis->del( 'perl_redis_test_list' );

done_testing;

