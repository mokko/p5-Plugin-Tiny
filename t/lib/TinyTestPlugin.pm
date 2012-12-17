package TinyTestPlugin;
use strict;
use warnings;

#use File::Spec;
#use lib File::Spec->catfile('t', 'lib');
use Moose;
has 'plugin_system' => (is => 'ro', isa => 'Plugin::Tiny', required => 1);
with 'TestRolePlugin';

#acts as bundle, i.e. loads other plugins
sub register_another_plugin {
    $_[0]->plugin_system->register(
        phase  => 'bar',
        role   => undef, #not 100% why this is needed...
        plugin => 'TinySubPlug'
    );
}

sub do_something {
    'doing something';
}

sub some_method {
    print "hello world\n";

}

1;
