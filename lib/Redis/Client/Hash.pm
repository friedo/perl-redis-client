package Redis::Client::Hash;

use Moose;
with 'Redis::Client::Role::Tied';

use Carp 'croak';


sub TIEHASH { 
    return shift->new( @_ );
}

sub FETCH { 
    my ( $self, $key ) = @_;

    my $val = $self->client->hget( $self->{key}, $key );
    return $val;
}

sub STORE { 
    my ( $self, $key, $val ) = @_;

    return $self->client->hset( $self->{key}, $key, $val );
}

sub DELETE { 
    my ( $self, $key ) = @_;

    my $val = $self->FETCH( $key );

    if ( $self->client->hdel( $self->{key}, $key ) ) { 
        return $val;
    }

    return;
}

sub CLEAR { 
    my ( $self ) = @_;

    my @keys = $self->client->hkeys( $self->{key} );

    foreach my $key( @keys ) { 
        $self->DELETE( $key );
    }
}

sub EXISTS { 
    my ( $self, $key ) = @_;

    return 1 if $self->client->hexists( $self->{key}, $key );
    return;
}

sub FIRSTKEY { 
    my ( $self ) = @_;

    my @keys = $self->client->hkeys( $self->{key} );
    return if @keys == 0;

    $self->{keys} = \@keys;

    return $self->NEXTKEY;
}

sub NEXTKEY { 
    my ( $self ) = @_;

    return shift @{ $self->{keys} };
}


1;

