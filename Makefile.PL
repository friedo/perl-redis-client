use inc::Module::Install;
use Carp 'confess';

name             'Redis-Client';
all_from         'lib/Redis/Client.pm';

requires         'Moose';
requires         'Tie::IxHash';

WriteAll;

