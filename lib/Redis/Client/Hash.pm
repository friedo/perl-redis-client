package Redis::Client::Hash;

use strict;
use warnings;

use Carp 'croak';

sub TIEHASH { 
    my ( $class, %args ) = @_;

    croak 'No key specified' unless $args{key};
    croak 'No Redis client object specified' unless $args{client};

    my $obj = { %args };

    return bless $obj, $class;
}

sub FETCH { 
    my ( $self, $key ) = @_;

    my $val = $self->{client}->hget( $self->{key}, $key );
    return $val;
}

sub STORE { 
    my ( $self, $key, $val ) = @_;

    return $self->{client}->hset( $self->{key}, $key, $val );
}

sub DELETE { 
    my ( $self, $key ) = @_;

    return $self->{client}->hdel( $self->{key}, $key );
}

sub CLEAR { 
    my ( $self ) = @_;

    croak 'not yet';
}

sub EXISTS { 
    my ( $self, $key ) = @_;

    return 1 if $self->{client}->hexists( $self->{key}, $key );
    return;
}

sub FIRSTKEY { 
    my ( $self ) = @_;

    my @keys = $self->{client}->hkeys( $self->{key} );
    return if @keys == 0;

    $self->{key_index} = 0;
    $self->{keys} = \@keys;

    return $self->{keys}[ $self->{key_index}++ ];
}

sub NEXTKEY { 
    my ( $self );

    return $self->{keys}[ $self->{key_index}++ ];
}


1;

