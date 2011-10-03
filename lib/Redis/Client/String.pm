package Redis::Client::String;

use strict;
use warnings;

use overload 
  '""'     => 'FETCH',
  '${}'    => 'FETCH',
  '<=>'    => '_num_compare',
  'cmp'    => '_str_compare';

use Scalar::Util 'blessed', 'refaddr';
use Carp 'croak';

my %OBJ_MAP;

sub TIESCALAR { 
    my ( $class, $key, $client ) = @_;

    my $val = $client->get( $key );

    my $obj = { key => $key, client => $client };

    my $ref = \$val;

    $OBJ_MAP{ refaddr $ref } = $obj;

    return bless $ref, $class;
}

sub FETCH { 
    my $self = shift;
    my $obj = $self->_get_obj;

    return $obj->{client}->get( $obj->{key} );
}

sub STORE { 
    my $self = shift;
    my $val  = shift;
    my $obj = $self->_get_obj;

    return $obj->{client}->set( $obj->{key}, $val );
}

sub _num_compare { 
    my $self = shift;
    my $val = shift;

    return $self->FETCH <=> $val;
}

sub _str_compare { 
    my $self = shift;
    my $val = shift;

    return $self->FETCH cmp $val;
}

sub _get_obj { 
    my $self = shift;

    my $obj = $OBJ_MAP{ refaddr $self };

    die "Can't find object info for $self"
      unless $obj;

    return $obj;
}

1;

__END__


