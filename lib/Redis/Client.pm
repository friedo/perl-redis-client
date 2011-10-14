package Redis::Client;

use Moose;
use IO::Socket::INET;
use Carp 'croak';

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

