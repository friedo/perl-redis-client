package Redis::Client::Set;

use Moose;
with 'Redis::Client::Role::Tied';

use Carp 'croak';


sub TIEHASH { 
    return shift->new( @_ );
}

sub FETCH { 
    return;
}

sub STORE { 
    my ( $self, $member ) = @_;

    return $self->client->sadd( $self->{key}, $member );
}

sub DELETE { 
    my ( $self, $member ) = @_;

    return $self->client->srem( $self->{key}, $member );
}

sub CLEAR { 
    my ( $self ) = @_;

    my @members = $self->client->smembers( $self->{key} );

    foreach my $member( @members ) { 
        $self->DELETE( $member );
    }
}

sub EXISTS { 
    my ( $self, $member ) = @_;

    return 1 if $self->client->sismember( $self->{key}, $member );
    return 0;
}

sub FIRSTKEY { 
    my ( $self ) = @_;

    my @members = $self->client->smembers( $self->{key} );
    return if @members == 0;

    $self->{members} = \@members;

    return $self->NEXTKEY;
}

sub NEXTKEY { 
    my ( $self ) = @_;

    return shift @{ $self->{members} };
}


1;

