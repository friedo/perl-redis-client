package RedisClientTest.pm;

use strict;
use warnings;

use Redis::Client;

sub server { 
    my $pw = $ENV{PERL_REDIS_TEST_PASSWORD};
    return Redis::Client->new( host => $ENV{PERL_REDIS_TEST_SERVER},
                               port => $ENV{PERL_REDIS_TEST_PORT},
                               $pw ? ( password => $pw ) : ( ) );

}


1;
