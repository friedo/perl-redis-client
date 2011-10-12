package Redis::Client::List;

use Moose;
with 'Redis::Client::Role::Tied';

use Carp 'croak';

sub TIEARRAY { 
    return shift->new( @_ );
}


sub FETCH { 
    my ( $self, $idx ) = @_;

    my $val = $self->client->lindex( $self->{key}, $idx );
    return $val;
}

sub STORE { 
    my ( $self, $idx, $val ) = @_;

    return $self->client->lset( $self->{key}, $idx, $val );
}

sub FETCHSIZE { 
    my ( $self ) = @_;

    return $self->client->llen( $self->{key} );
}

sub STORESIZE { 
    croak q{Can't modify the size of a Redis list. Use push or unshift.};
}

sub EXTEND { 
}

sub EXISTS { 
    my ( $self, $idx ) = @_;

    return 1 if $self->FETCHSIZE > $idx;
    return;
}

sub DELETE { 
    my ( $self, $idx ) = @_;

    return $self->STORE( $idx, undef );
}

sub CLEAR { 
    my ( $self ) = @_;

    return $self->client->ltrim( $self->{key}, 0, 0 );
}

sub PUSH { 
    my ( $self, @args ) = @_;

    return $self->client->rpush( $self->{key}, @args );
}

sub POP { 
    my ( $self ) = @_;

    return $self->client->rpop( $self->{key} );
}

sub UNSHIFT { 
    my ( $self, @args ) = @_;

    return $self->client->lpush( $self->{key}, @args );
}

sub SHIFT { 
    my ( $self ) = @_;

    return $self->client->lpop( $self->{key} );
}

sub SPLICE { 
    croak q{splice is not implemented for Redis lists.};
}

__PACKAGE__->meta->make_immutable;

1;
