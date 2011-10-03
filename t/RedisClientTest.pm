package RedisClientTest;

use strict;
use warnings;

use Redis::Client;

sub server { 
    my $host = $ENV{PERL_REDIS_TEST_SERVER}   || 'localhost';
    my $port = $ENV{PERL_REDIS_TEST_SERVER}   || '6379';
    my $pw   = $ENV{PERL_REDIS_TEST_PASSWORD} || undef;

    my $client = eval { 
        Redis::Client->new( host => $ENV{PERL_REDIS_TEST_SERVER},
                            port => $ENV{PERL_REDIS_TEST_PORT},
                            $pw ? ( password => $pw ) : ( ) );
    };

    return if $@;
    return $client;
}


1;
