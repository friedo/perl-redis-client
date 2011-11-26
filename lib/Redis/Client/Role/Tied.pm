package Redis::Client::Role::Tied;

use Moose::Role;
use Carp 'croak';
use Scalar::Util 'blessed';

has key     => ( is => 'ro', isa => 'Str', required => 1 );
has client  => ( is => 'ro', isa => 'Redis::Client', required => 1 );

sub BUILD { 
    my ( $self ) = @_;
    my $class = blessed $self;

    my ( $c_type ) = ( $class =~ m{::(\w+)$} );
    my $type = $self->client->type( $self->key );

    unless ( $type eq lc $c_type ) { 
        die sprintf "Redis key %s is a %s. Try using Redis::Client::%s instead", $self->key, $type, ucfirst $type;
    }
}


1;


__END__


=pod

=encoding utf8

=head1 DESCRIPTION

This role contains common functionality used by the Redis::Client C<tie> classes.

=head1 SEE ALSO

=over

=item L<Redis::Client>

=item L<Redis::Client::String>

=item L<Redis::Client::List>

=item L<Redis::Client::Hash>

=item L<Redis::Client::Set>

=item L<Redis::Client::Zset>

=back

=cut


