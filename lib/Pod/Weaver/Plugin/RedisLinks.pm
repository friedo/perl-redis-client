package Pod::Weaver::Plugin::RedisLinks;

# ABSTRACT: Add links to Redis documentation

use Moose;
with 'Pod::Weaver::Role::Transformer';

use Data::Dumper;
use Scalar::Util 'blessed';
use aliased 'Pod::Elemental::Element::Pod5::Ordinary';

sub transform_document { 
    my ( $self, $doc ) = @_;

    my @children = $doc->children;
    
    my @new_children;
    foreach my $child( @{ $children[0] } ) { 
        if ( $child->can( 'command' ) && $child->command =~ /^(?:key|str|list|hash|set|zset|conn|serv)_method/ ) { 
            my $meth_name = $child->content;
            $meth_name =~ s/^\s*?(\S+)\s*$/$1/;

            my $cmd_name = uc $meth_name;
            $cmd_name =~ tr/_/ /;

            my $link_name = $meth_name;
            $link_name =~ tr/_/-/;

            my $new_para = Ordinary->new( content => sprintf 'Redis L<%s|%s> command.', 
                                                     $cmd_name, 'http://redis.io/commands/' . $link_name );

            push @new_children, $child, $new_para;
            next;
        } 

        push @new_children, $child;
    }

    $doc->children( \@new_children );
}

__PACKAGE__->meta->make_immutable;

1;


__END__


=pod

=head1 DESCRIPTION

This L<Pod::Weaver> plugin is used internally by the Redis::Client distribution to add links
to the official L<Redis|http://redis.io/> documentation for each command.

