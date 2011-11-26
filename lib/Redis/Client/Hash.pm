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


__END__


=pod

=encoding utf8

=head1 SYNOPSIS

    use Redis::Client;

    my $client = Redis::Client->new;
    tie my %hash, 'Redis::Client::Hash', key => 'my_hash', client => $client;

    my @keys = keys %hash;
    $hash{foo} = 42;
    print 1 if exists $hash{bar};

=head1 DESCRIPTION

This class provides a C<tie>d interface for Redis hashes. Redis hashes are mapped
to Perl hashes. Like Perl hashes, Redis hashes contain an unordered set of key-value
pairs. Any time the C<tie>d hash or one of its elements is evaluated, the corresponding
item will be fetched from the Redis store. Any time it is modified, the value will
be written to the Redis store.

=head1 INTERFACE

The following Perl builtins will work the way you expect on Redis hashes.

=over

=item C<delete>

Removes a key from the hash. (Note that this is not the same as setting the value
to C<undef>, in which case the key still exists.)

    delete $hash{foo};

=item C<exists>

Check if a key exists in the hash.

    print 1 if exists $hash{blargh};

=item C<keys>

Retrieves a list of all keys in the hash, in no particular order.

    my @keys = keys %hash;

=item C<values>

Retrieves a list of all values in the hash, in no particular order

    my @vals = values %hash;

=item C<each>

Iterate over key/value pairs from the hash.

    while( my ( $key, $val ) = each %hash ) { ... }

=back

=head1 SEE ALSO

=over

=item L<Redis::Client>

=back

=cut


