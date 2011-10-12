package Redis::Client::String;

use Moose;
with 'Redis::Client::Role::Tied';

use overload 
  '""'     => 'FETCH',
  '${}'    => 'FETCH',
  '<=>'    => '_num_compare',
  'cmp'    => '_str_compare';

use Scalar::Util 'blessed', 'refaddr';
use Carp 'croak';

sub TIESCALAR { 
    return shift->new( @_ );
}

sub FETCH { 
    my $self = shift;

    my $val = $self->client->get( $self->{key} );
    return $val;
}

sub STORE { 
    my $self = shift;
    my $val  = shift;

    return $self->client->set( $self->{key}, $val );
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

__PACKAGE__->meta->make_immutable;

1;

__END__


