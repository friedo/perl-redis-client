package Redis::Client::String;

# ABSTRACT: Work with Redis strings

use Moose;
with 'Redis::Client::Role::Tied';

use namespace::sweep 0.003;
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

    return $self->_cmd( 'get' );
}

sub STORE { 
    my $self = shift;
    my $val  = shift;

    return $self->_cmd( 'set', $val );
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


=pod

=encoding utf8

=head1 SYNOPSIS

    use Redis::Client;

    my $client = Redis::Client->new;
    tie my $str, 'Redis::Client::String', key => 'my_string', client => $client;

    print $str;
    $str = 'foo';
    $str .= 'bar';

    print 1 if $str eq 'foobar';

=head1 DESCRIPTION

This class provides a C<tie>d interface for Redis strings. Redis strings are mapped to Perl
scalars. Like Perl scalars, a Redis string may contain any single value, including a 
character string, number, etc. Any time the string is evaluated, its current value will be 
fetched from the Redis store. Any time it is modified, the value will be written to the 
Redis store. 

Additionally, the C<tie>d object also overloads the stringification operator and numerical
and string comparitors.


=head1 SEE ALSO

=over

=item L<Redis::Client>

=back



=cut

