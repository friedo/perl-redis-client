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

sub TIESCALAR { 
    my ( $class, %args ) = @_;

    croak 'No key specified' unless $args{key};
    croak 'No Redis client object specified' unless $args{client};

    my $obj = { %args };

    return bless $obj, $class;
}

sub FETCH { 
    my $self = shift;

    my $val = $self->{client}->get( $self->{key} );
    return $val;
}

sub STORE { 
    my $self = shift;
    my $val  = shift;

    return $self->{client}->set( $self->{key}, $val );
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

1;

__END__


