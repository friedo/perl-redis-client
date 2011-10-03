package Redis::Client::String;

use overload 
  '""'     => '_get_scalar',
  '${}'    => '_get_scalar',
  '<=>'    => '_num_compare',
  'cmp'    => '_str_compare';


use Moose;
use Scalar::Util 'blessed', 'refaddr', 'reftype';

has 'key'      => ( is => 'ro', isa => 'Str', required => 1 );
has 'value'    => ( is => 'rw', isa => 'Str', required => 1 );
has 'client'   => ( is => 'ro', isa => 'Redis::Client', required => 1 );

my %OBJ_MAP;
sub _get_scalar { 
    my $self = shift;

    tie my $scalar, blessed $self, $self->value;
    $OBJ_MAP{ refaddr \$scalar } = $self;

    warn "returning [$scalar]";

    return $scalar;
}

sub _num_compare { 
    my $self = shift;
    my $compare = shift;

    return $self->value <=> $compare;
}

sub _str_compare { 
    my $self = shift;
    my $compare = shift;

    return $self->value cmp $compare;
}

around [ '_num_compare', '_str_compare' ] => sub {
    my ( $orig, $self, @args ) = @_;

    warn "type of self = " . reftype $self;

    if ( reftype $self eq reftype \"" ) { 
        my $real_self = $OBJ_MAP{ refaddr $self };
        return $real_self->$orig( @args );
    }

    return $self->$orig( @args );
};

sub TIESCALAR { 
    my ( $class, $scalar ) = @_;

    warn "tieing [$scalar] to [$class]";

    return bless \$scalar, $class;
}

sub FETCH { 
    my $self = shift;
    
    warn "fetch self = [$self]";

    my $obj = $OBJ_MAP{ refaddr $self };

    return $obj->value;
}

sub STORE { 
    my $self = shift;
    my $val  = shift;

    my $obj = $OBJ_MAP{ refaddr $self };

    warn "store obj = [$obj]";

    my $ret = $obj->client->set( $obj->key => $val );
    $obj->value( $val );

    warn "store return = [$ret]";

    return $ret;
}

1;

__END__


