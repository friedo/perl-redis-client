package Redis::Client::Zset;

use Moose;
with 'Redis::Client::Role::Tied';

use Carp 'croak';


sub TIEHASH { 
    return shift->new( @_ );
}

sub FETCH { 
    my ( $self, $member ) = @_;

    return $self->client->zscore( $self->{key}, $member );
}

sub STORE { 
    my ( $self, $member, $score ) = @_;

    return $self->client->zadd( $self->{key}, $score, $member );
}

sub DELETE { 
    my ( $self, $member ) = @_;

    return $self->client->zrem( $self->{key}, $member );
}

sub CLEAR { 
    my ( $self ) = @_;

    my @members = $self->client->zrange( $self->{key}, 0, -1 );

    foreach my $member( @members ) { 
        $self->DELETE( $member );
    }
}

sub EXISTS { 
    my ( $self, $member ) = @_;

    return 1 if defined $self->client->zscore( $self->{key}, $member );
    return 0;
}

sub FIRSTKEY { 
    my ( $self ) = @_;

    my @members = $self->client->zrange( $self->{key}, 0, -1 );
    return if @members == 0;

    $self->{members} = \@members;

    return $self->NEXTKEY;
}

sub NEXTKEY { 
    my ( $self ) = @_;

    return shift @{ $self->{members} };
}


1;

