use inc::Module::Install;
use Carp 'confess';

name             'Redis-Client';
all_from         'lib/Redis/Client.pm';

requires         'Moose';
requires         'Tie::IxHash';

# stolen from ExtUtils::MakeMaker
sub prompt ($;$) {  
    my($mess, $def) = @_;
    confess("prompt function called without an argument") 
        unless defined $mess;

    my $isa_tty = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ;

    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";

    local $|=1;
    local $\;
    print "$mess $dispdef";

    my $ans;
    if ($ENV{PERL_MM_USE_DEFAULT} || (!$isa_tty && eof STDIN)) {
        print "$def\n";
    }
    else {
        $ans = <STDIN>;
        if( defined $ans ) {
            chomp $ans;
        }
        else { # user hit ctrl-D
            print "\n";
        }
    }

    return (!defined $ans || $ans eq '') ? $def : $ans;
}

my $run_server_tests = prompt(
"\n\n\nRedis::Client requires a running Redis server to perform its tests.
Run server tests?", "Skip" );

unless( $run_server_tests =~ /skip/i ) { 
    my $server_name = prompt 'Redis server host:', 'localhost';
    my $port = prompt 'Redis port number:', '6379';
    my $password = prompt 'Redis server password:', 'None';

    preamble qq{
# env vars for Redis tests
PERL_REDIS_TEST_SERVER := $server_name
PERL_REDIS_TEST_PORT := $port
} . ( ( $password !~ /none/i ) ? qq{PERL_REDIS_TEST_PASSWORD := $password

} : "\n\n" );

}

WriteAll;

