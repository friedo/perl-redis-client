package Redis::Client::Role::Tied;

use Moose::Role;

has key     => ( is => 'ro', isa => 'Str', required => 1 );
has client  => ( is => 'ro', isa => 'Redis::Client', required => 1 );


1;
