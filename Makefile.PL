use inc::Module::Install;

name             'Redis-Client';
all_from         'lib/Redis/Client.pm';

requires         'Moose';
requires         'Tie::IxHash';

WriteAll;

