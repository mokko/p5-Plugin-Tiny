package TinyTestPlugin;
use strict;
use warnings;
use Moose;
has 'plugin_system' => (is => 'ro', isa => 'Plugin::Tiny', required => 1);

#acts as bundle, i.e. loads other plugins
sub register_another_plugin {
    $_[0]->plugin_system->register(phase => 'bar', plugin => 'TinySubPlug');
}

sub do_something {
    'doing something';
}


1;
