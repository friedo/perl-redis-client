package Redis::Client;

use Moose;
use IO::Socket::INET ();
use Carp 'croak';
use utf8;

# ABSTRACT: Perl client for Redis 2.4 and up

has 'host'         => ( is => 'ro', isa => 'Str', default => 'localhost' );
has 'port'         => ( is => 'ro', isa => 'Int', default => 6379 );
has '_sock'        => ( is => 'ro', isa => 'IO::Socket', init_arg => undef, lazy_build => 1 );

BEGIN { 
    my %COMMANDS = 
      ( ECHO        => 1,
        TYPE        => 1,

        SET         => 2,
        DEL         => undef,
        GET         => 1,

        LINDEX      => 2,
        LSET        => 3,
        LLEN        => 1,
        LTRIM       => 3,
        RPUSH       => undef,
        RPOP        => 1,
        LPUSH       => undef,
        LPOP        => 1,

        HGET        => 2,
        HSET        => 3,
        HDEL        => undef,
        HEXISTS     => 2,
        HGETALL     => 1,
        HKEYS       => 1,
        HVALS       => 1,
        HLEN        => 1,
        HMGET       => undef,
        HMSET       => undef,

        SADD        => undef,
        SREM        => undef,
        SMEMBERS    => 1,
        SISMEMBER   => 2,
      );

    foreach my $cmd ( keys %COMMANDS ) { 
        my $meth = sub { 
            my $self = shift;
            my @args = @_;

            if ( my $args_num = $COMMANDS{$cmd} ) { 
                croak sprintf( 'Redis %s command requires %s arguments', $cmd, $args_num )
                  unless @args == $args_num;
            }

            return $self->_send_command( $cmd, @args );
        };

        __PACKAGE__->meta->add_method( lc $cmd, $meth );
    }
};

my $CRLF = "\x0D\x0A";


foreach my $func( 'lpush', 'rpush' ) { 
    around $func => sub { 
        my ( $orig, $self, @args ) = @_;

        my $rcmd = uc $func;
        croak 'Redis $rcmd requires 2 or more arguments'
          unless @args >= 2;

        $self->$orig( @args );
    };
}


sub _build__sock { 
    my $self = shift;

    my $sock = IO::Socket::INET->new( 
        PeerAddr    => $self->host,
        PeerPort    => $self->port,
        Proto       => 'tcp',
    ) or die sprintf q{Can't connect to Redis host at %s:%s: %s}, $self->host, $self->port, $@;

    return $sock;
}

sub _send_command { 
    my $self = shift;
    my ( $cmd, @args ) = @_;

    my $sock = $self->_sock;
    my $cmd_block = $self->_build_urp( $cmd, @args );

    $sock->send( $cmd_block );

    return $self->_get_response;
}

# build a command string using the binary-safe Unified Request Protocol
sub _build_urp { 
    my $self = shift;
    my @items = @_;

    my $length = @_;

    my $block = sprintf '*%s%s', $length, $CRLF;

    foreach my $line( @items ) { 
        $block .= sprintf '$%s%s', length $line, $CRLF;
        $block .= $line . $CRLF;
    }

    return $block;
}

sub _get_response { 
    my $self = shift;
    my $sock = $self->_sock;

    # the first byte tells us what to expect
    my %msg_types = ( '+'   => '_read_single_line',
                      '-'   => '_read_single_line',
                      ':'   => '_read_single_line',
                      '$'   => '_read_bulk_reply',
                      '*'   => '_read_multi_bulk_reply' );

    my $buf;
    $sock->read( $buf, 1 );
    die "Can't read from socket" unless $buf;
    die "Can't understand Redis message type [$buf]" unless exists $msg_types{$buf};

    my $meth = $msg_types{$buf};

    if ( $buf eq '-' ) { 
        # A Redis error. Get the error message and throw it.
        croak sprintf 'Redis: %s', $self->$meth;
    }

    # otherwise get the response and return it normally.
    return $self->$meth;
}

sub _read_multi_bulk_reply { 
    my $self = shift;
    my $sock = $self->_sock;

    local $/ = $CRLF;

    my $parts = readline $sock;
    chomp $parts;

    return if $parts == 0;      # null response

    my @results;
    foreach my $part ( 1 .. $parts ) { 
        # better hope we don't see a multi-bulk inside a multi-bulk!
        push @results, $self->_get_response;
    }

    return @results;
}

sub _read_bulk_reply { 
    my $self = shift;
    my $sock = $self->_sock;

    local $/ = $CRLF;

    my $length = readline $sock;
    chomp $length;

    return if $length == -1;    # null response

    my $buf;
    $sock->read( $buf, $length );

    # throw out the terminating CRLF
    readline $sock;

    return $buf;
}

sub _read_single_line { 
    my $self = shift;
    my $sock = $self->_sock;

    local $/ = $CRLF;

    my $val = readline $sock;
    chomp $val;

    return $val;
}


1;

__END__


=pod

=encoding utf8


=head1 SYNOPSIS

    use Redis::Client;

    my $client = Redis::Client->new( host => 'localhost', port => 6379 );

    # work with strings
    $client->set( some_key => 'myval' );
    my $str_val = $client->get( 'some_key' );
    print $str_val;        # myval

    # work with lists
    $client->lpush( some_list => 1, 2, 3 );
    my $list_elem = $client->lindex( some_list => 2 );
    print $list_elem;      # 3

    # work with hashes
    $client->hset( 'some_hash', foobar => 42 );
    my $hash_val = $client->hget( 'some_hash', 'foobar' );
    print $hash_val;      # 42


=head1 DESCRIPTION

Redis::Client is a Perl-native client for the Redis (L<http://redis.io>) key/value store.
Redis supports storage and retrieval of strings, ordered lists, hashes, sets, and ordered sets.

Redis::Client uses the new binary-safe Unified Request Protocol to implement all of its commands.
This requires that Redis::Client be able to get accurate byte-length counts of all strings passed
to it. Therefore, if you are working with character data, it MUST be encoded to a binary form
(e.g. UTF-8) before you send it to Redis; otherwise the string lengths may be counted 
incorrectly and the requests will fail. Redis guarantees round-trip safety for binary data.

This distribution includes classes for working with Redis data via C<tie> based objects
that map Redis items to native Perl data types. See the documentation for those modules for
usage:

=over

=item L<Redis::Client::String>

=item L<Redis::Client::List>

=item L<Redis::Client::Hash>

=item L<Redis::Client::Set>

=item L<Redis::Client::Zset>

=back

=method new

Constructor. Returns a new C<Redis::Client> object for talking to a Redis server. Throws a fatal error
if a connection cannot be obtained.

=over

=item C<host>

The hostname of the Redis server. Defaults to C<localhost>.

=item C<port>

The port number of the Redis server. Defaults to C<6379>.

=back

Redis connection passwords are not currently supported.

    my $client = Redis::Client->new( host => 'foo.example.com', port => 1234 );


=method del

Deletes keys. Takes a list of key names. Returns the number of keys deleted.

    $client->del( 'foo', 'bar', 'baz' );

=method echo

Returns whatever you send it. Useful for testing only. Takes one argument.

    print $client->echo( "Hello, World!" );

=method get

Retrieves a string value associated with a key. Takes one key name. Returns C<undef> if the
key does not exist. If the key is associated with something other than a string,
a fatal error is thrown.

    print $client->get( 'mykey' );

=method hdel

Deletes keys from a hash. Takes the name of a hash and a list of key names to delete. 
Returns the number of keys deleted. Returns zero if the hash does not exist, or if
none of the keys specified exist in the hash. 

    $client->hdel( 'myhash', 'foo', 'bar', 'baz' );

=method hexists

Returns a true value if a key exists in a hash. Takes a hash name and the key name.

    blah() if $client->hexists( 'myhash', 'foo' );

=method hget

Retrieves a value associated with a key in a hash. Takes the name of the hash
and the key within the hash. Returns C<undef> if the hash or the key within the
hash does not exist. (Use L<exists> to determine if a key exists at all.)

    # sets the value for 'key' in the hash 'foo'
    $client->hset( 'foo', key => 42 );

    print $client->hget( 'foo', 'key' );   # 42

=method hgetall

Retrieves all of the keys and values in a hash. Takes the name of the hash
and returns a list of key/value pairs. 

    my %hash = $client->hgetall( 'myhash' );

=method hkeys

Retrieves a list of all the keys in a hash. Takes the name of the hash and
returns a list of keys.

    my @keys = $client->hkeys( 'myhash' );

=method hmget

Retrieves a list of values associated with the given keys in a hash. Takes
the name of the hash and a list of keys. If a given key does not exist, 
C<undef> will be returned in the corresponding location in the result list.

    my @values = $client->hmget( 'myhash', 'key1', 'key2', 'key3' );

=method hmset

Sets a list of key/value pairs in a hash. Takes the hash name and a list of
keys and values to set. 

    $client->hmset( 'myhash', foo => 1, bar => 2, baz => 3 );

=method hvals

Retrieves a list of all the values in a given hash. Takes the hash name.

    my @values = $client->hvals( 'myhash' );


