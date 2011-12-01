package Redis::Client;

use Moose;
use IO::Socket::INET ();
use Carp 'croak';
use utf8;
use namespace::sweep 0.003;

# ABSTRACT: Perl client for Redis 2.4 and up

has 'host'         => ( is => 'ro', isa => 'Str', default => 'localhost' );
has 'port'         => ( is => 'ro', isa => 'Int', default => 6379 );
has '_sock'        => ( is => 'ro', isa => 'IO::Socket', init_arg => undef, lazy_build => 1, 
                        predicate => '_have_sock', clearer => '_clear_sock' );

BEGIN { 
    # maps Redis commands to arity; undef implies variadic
    my %COMMANDS = 
      ( # key commands
        DEL         => undef,
        EXISTS      => 1,
        EXPIRE      => 2,
        EXPITEAT    => 2,
        KEYS        => 1,
        MOVE        => 2,
        OBJECT      => undef,
        PERSIST     => 1,
        RANDOMKEY   => 0,
        RENAME      => 2,
        RENAMENX    => 2,
        SORT        => undef,
        TTL         => 1,
        TYPE        => 1,
        EVAL        => undef,
       
        # string commands
        APPEND      => 2,
        DECR        => 1,
        DECRBY      => 2, 
        GET         => 1,
        GETBIT      => 2,
        GETRANGE    => 3,
        GETSET      => 2,
        INCR        => 1,
        INCRBY      => 2,
        MGET        => undef,
        MSET        => undef,
        MSETNX      => undef,
        SET         => 2,
        SETBIT      => 3,
        SETEX       => 3,
        SETNX       => 2,
        SETRANGE    => 3,
        STRLEN      => 1,

        # list commands
        BLPOP       => undef,
        BRPOP       => undef,
        BRPOPLPUSH  => 3,
        LINDEX      => 2,
        LINSERT     => 4,
        LLEN        => 1,
        LPOP        => 1,
        LPUSH       => undef,
        LPUSHX      => 2,
        LRANGE      => 3,
        LREM        => 3,
        LSET        => 3,
        LTRIM       => 3,
        RPOP        => 1,
        RPOPLPUSH   => 2,
        RPUSH       => undef,
        RPUSHX      => 2,

        # hash commands
        HDEL        => undef,
        HEXISTS     => 2,
        HGET        => 2,
        HGETALL     => 1,
        HINCRBY     => 3,
        HKEYS       => 1,
        HLEN        => 1,
        HMGET       => undef,
        HMSET       => undef,
        HSET        => 3,
        HSETNX      => 3,
        HVALS       => 1,

        # set commands
        SADD        => undef,
        SCARD       => 1,
        SDIFF       => undef,
        SDIFFSTORE  => undef,
        SINTER      => undef,
        SINTERSTORE => undef,
        SISMEMBER   => 2,
        SMEMBERS    => 1,
        SMOVE       => 3,
        SPOP        => 1,
        SRANDMEMBER => 1,
        SREM        => undef,
        SUNION      => undef,
        SUNIONSTORE => undef,

        # zset commands
        ZADD        => undef,
        ZCARD       => 1,
        ZCOUNT      => 3,
        ZINCRBY     => 3,
        ZINTERSTORE => undef,
        ZRANGE      => undef,
        ZRANGEBYSCORE => undef,
        ZRANK       => 2,
        ZREM        => undef,
        ZREMRANGEBYRANK => 3,
        ZREMRANGEBYSCORE => undef,
        ZREVRANK    => 2,
        ZSCORE      => 2,
        ZUNIONSTORE => undef,

        # connection commands
        AUTH        => 1,
        ECHO        => 1,
        PING        => 0,
        QUIT        => 0,
        SELECT      => 1,

        # server commands
        BGREWRITEAOF => 0,
        BGSAVE      => 0,
        'CONFIG GET' => 1,
        'CONFIG SET' => 2,
        'CONFIG RESETSTAT' => 0,
        DBSIZE      => 0,
        'DEBUG OBJECT' => 1,
        'DEBUG SEGFAULT' => 0,
        FLUSHALL    => 0,
        FLUSHDB     => 0,
        INFO        => 0,
        LASTSAVE    => 0,
        SAVE        => 0,
        SHUTDOWN    => 0,
        SLAVEOF     => 2,
        SLOWLOG     => undef,
        SYNC        => 0,
      );

    foreach my $cmd ( keys %COMMANDS ) { 
        my $meth = sub { 
            my $self = shift;
            my @args = @_;

            my $args_num = $COMMANDS{$cmd};
            if ( defined $args_num ) { 
                croak sprintf( 'Redis %s command requires %s arguments', $cmd, $args_num )
                  unless @args == $args_num;
            }

            return $self->_send_command( $cmd, @args );
        };

        # some commands have spaces in them. yeesh.
        my $meth_name = lc $cmd;
        $meth_name =~ s/\s/_/g;

        __PACKAGE__->meta->add_method( $meth_name => $meth );
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

# don't try to send commands on disconnected socket
after quit => sub { 
    my $self = shift;
    $self->_clear_sock;
};


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
        my $err = $self->$meth;
        $err =~ s/ERR\s/Redis: /;
        croak $err;
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


__PACKAGE__->meta->make_immutable;

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

=class_method new

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


=key_method del

Deletes keys. Takes a list of key names. Returns the number of keys deleted.

    $client->del( 'foo', 'bar', 'baz' );

=key_method type

Retrieves the type of a key. Takes the key name and returns one of C<string>, C<list>, 
C<hash>, C<set>, or C<zset>.

    my $type = $client->type( 'some_key' );

=str_method get

Retrieves a string value associated with a key. Takes one key name. Returns C<undef> if the
key does not exist. If the key is associated with something other than a string,
a fatal error is thrown.

    print $client->get( 'mykey' );

=str_method set

Sets the value of a string. Takes the key name and a value. 

    $client->set( my_key => 'foobar' );

=list_method lindex

Retrieves the value stored at a particular index in a list. Takes the list name
and the numeric index. 

    my $val = $client->lindex( 'my_list', 42 );

=list_method lset

Sets the value at a particular index in a list. Takes the list name, the numeric
index, and the new value.

    $client->lset( 'my_list', 42, 'yippee!' );

=list_method llen

Retrieves the number of items in a list. Takes the list name.

    my $length = $client->llen( 'my_list' );

=list_method ltrim

Removes all elements of a list outside of the specified range. Takes the list 
name, start index, and stop index. All keys between the start and stop indices
(inclusive) will be preserved. The rest will be deleted. The list is shifted down
if the start index is not zero. The stop index C<-1> can be used to select everything
until the end of the list.

    # get rid of first two elements.
    $client->ltrim( 'my_list', 2, -1 );

=list_method rpush

Adds items to the end of a list, analogous to the Perl C<push> operator. Takes 
the list name and a list of items to add. Returns the length of the list when
done.

    my $new_length = $client->rpush( my_list => 42, 43, 'narf', 'poit' );

=list_method rpop

Removes and returns the last element of a list, analogous to the Perl C<pop>
operator. 

    my $last = $client->rpop( 'my_list' );

=list_method lpush

Adds items to the beginning of a list, analogous to the Perl C<unshift> operator. 
Takes the list name and a list of items to add. Returns the length of the list 
when done.

    my $new_length = $client->lpush( my_list => 1, 2, 3 );

=list_method lpop

Removes and returns the first element of a list, analogous to the Perl C<shift>
operator. 

    my $first = $client->lpop( 'my_list' );

=hash_method hdel

Deletes keys from a hash. Takes the name of a hash and a list of key names to delete. 
Returns the number of keys deleted. Returns zero if the hash does not exist, or if
none of the keys specified exist in the hash. 

    $client->hdel( 'myhash', 'foo', 'bar', 'baz' );

=hash_method hexists

Returns a true value if a key exists in a hash. Takes a hash name and the key name.

    blah() if $client->hexists( 'myhash', 'foo' );

=hash_method hget

Retrieves a value associated with a key in a hash. Takes the name of the hash
and the key within the hash. Returns C<undef> if the hash or the key within the
hash does not exist. (Use L</hexists> to determine if a key exists at all.)

    # sets the value for 'key' in the hash 'foo'
    $client->hset( 'foo', key => 42 );

    print $client->hget( 'foo', 'key' );   # 42

=hash_method hgetall

Retrieves all of the keys and values in a hash. Takes the name of the hash
and returns a list of key/value pairs. 

    my %hash = $client->hgetall( 'myhash' );

=hash_method hkeys

Retrieves a list of all the keys in a hash. Takes the name of the hash and
returns a list of keys.

    my @keys = $client->hkeys( 'myhash' );

=hash_method hlen

Retrieves the number of keys in a hash. Takes the name of the hash.

    my $size = $client->hlen( 'myhash' );

=hash_method hmget

Retrieves a list of values associated with the given keys in a hash. Takes
the name of the hash and a list of keys. If a given key does not exist, 
C<undef> will be returned in the corresponding location in the result list.

    my @values = $client->hmget( 'myhash', 'key1', 'key2', 'key3' );

=hash_method hmset

Sets a list of key/value pairs in a hash. Takes the hash name and a list of
keys and values to set. 

    $client->hmset( 'myhash', foo => 1, bar => 2, baz => 3 );

=hash_method hvals

Retrieves a list of all the values in a given hash. Takes the hash name.

    my @values = $client->hvals( 'myhash' );


=set_method sadd

Adds members to a set. Takes the names of the set and the members to add.

    $client->sadd( 'myset', 'foo', 'bar', 'baz' );

=set_method srem

Removes members from a set. Takes the names of the set and the members
to remove.

    $client->srem( 'myset', 'foo', 'baz' );

=set_method smembers

Returns a list of all members in a set, in no particular order. Takes
the name of the set.

    my @members = $client->smembers( 'myset' );

=set_method sismember

Returns a true value if the given member is in a set. Takes the names
of the set and the member.

    if ( $client->sismember( 'myset', foo' ) ) { ... }

=zset_method zadd

Adds members to a sorted set (zset). Takes the sorted set name and a list of
score/member pairs. 

    $client->zadd( 'myzset', 1 => 'foo', 2 => 'bar', 3 => 'baz' );

(The ordering of the scores and member names may seem backwards if you think
of zsets as rough analogs of hashes. That's just how Redis does it.)

=zset_method zcard

Returns the cardinality (size) of a sorted set. Takes the name of the sorted set.

    my $size = $client->zcard( 'myzset' );

=zset_method zcount

Returns the number of members in a sorted set with scores between two values.
Takes the name of the sorted set and the minimum and maximum

    my $count = $client->zcount( 'myzset', $min, $max );

=zset_method zrange

Returns all the members of a sorted set with scores between two values. Takes the
name of the sorted set, a minimum and maximum, and an optional boolean to 
control whether or not the scores are returned along with the members.

    my @members = $client->zrange( 'myzset', $min, $max );
    my %members_scores = $client->zrange( 'myzset', $min, $max, 1 );

=zset_method zrank  

Returns the index of a member within a sorted. set. Takes the names of the
sorted set and the member.

    my $rank = $client->zrank( 'myzset', 'foo' );

=zset_method zscore  

Returns the score associated with a member in a sorted set. Takes the names
of the sorted set and the member.

    my $score = $client->zscore( 'myzset', 'foo' );


=conn_method echo

Returns whatever you send it. Useful for testing only. Takes one argument.

    print $client->echo( "Hello, World!" );



=head1 CAVEATS

This early release is not feature-complete. I've implemented all the Redis
commands that I use, but there are several that are not yet implemented. There
is also no support for Redis publish/subscribe, but I intend to add that
soon. Patches welcome. :)

The L<MONITOR|http://redis.io/commands/monitor> command will probably not be
supported any time soon since it would require some kind of asynchronous 
solution and does not use the URP.

=cut


