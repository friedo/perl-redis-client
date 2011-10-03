package Redis::Client;

use Moose;
use IO::Socket::INET;
use Carp 'croak';

has 'host'         => ( is => 'ro', isa => 'Str', default => 'localhost' );
has 'port'         => ( is => 'ro', isa => 'Int', default => 6379 );
has '_sock'        => ( is => 'ro', isa => 'IO::Socket', init_arg => undef, lazy_build => 1 );

my $CRLF = "\x0D\x0A";

sub _build__sock { 
    my $self = shift;

    my $sock = IO::Socket::INET->new( 
        PeerAddr    => $self->host,
        PeerPort    => $self->port,
        Proto       => 'tcp',
    ) or die sprintf q{Can't connect to Redis host at %s:%s: %s}, $self->host, $self->port, $@;

    return $sock;
}


# ECHO command
sub echo { 
    my $self = shift;
    my $arg  = shift;

    croak 'No string provided for Redis ECHO command'
      unless defined $arg;

    my $res = $self->_send_command( 'ECHO', $arg );

    return $res;
}

# SET command
sub set { 
    my $self = shift;
    my @args = @_;

    croak 'Redis SET requires a key and a value'
      unless @_ == 2;

    my $res = $self->_send_command( 'SET', @args );
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
                      ':'   => '_read_integer',
                      '$'   => '_read_bulk_reply',
                      '*'   => '_read_multi_bulk_reply' );

    my $buf;
    $sock->recv( $buf, 1 );
    die "Can't read from socket" unless $buf;
    die "Can't understand Redis message type [$buf]" unless exists $msg_types{$buf};

    my $meth = $msg_types{$buf};

    return $self->$meth;
}

sub _read_bulk_reply { 
    my $self = shift;
    my $sock = $self->_sock;

    local $/ = $CRLF;

    my $length = readline $sock;
    chomp $length;
    my $buf;
    $sock->read( $buf, $length );

    # throw out the terminating CRLF
    readline $sock;

    return $buf;
}

1;

__END__

