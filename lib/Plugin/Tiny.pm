#ABSTRACT: A tiny plugin system for perl
package Plugin::Tiny;
use strict;
use warnings;
use Carp 'confess';
use Class::Load 'load_class';
use Moose;
use namespace::autoclean;

=head1 SYNOPSIS

  #from core or bundling plugin
  use Moose; #optional, t/tiny.t avoids using moose in core
  use Plugin::Tiny; 
  has 'plugins'=>(
    is=>'ro',
    isa=>'Plugin::Tiny', 
    default=>sub{Plugin::Tiny->new()}
  );
  
  #load plugin_class (and perhaps phase) from your configuration
  $self->plugins->register(
    phase=>$phase,         #optional; defaults to last part of plugin class
    plugin=>$plugin_class, #required
    role=>$role,           #optional
    arg1=>$arg1,           #optional
    arg2=>$arg2,           #optional
  );

  #execute your plugin's methods 
  my $plugin=$self->get_plugin ($phase); 
  $plugin->do_something(@args);  

=head1 DESCRIPTION

Plugin::Tiny is minimalistic plugin system for perl. Each plugin is associated
with a keyword (referred to as phase). A limitation of Plugin::Tiny is that 
each phase can have only one plugin. 

=head2 Bundles of Plugins

You can still create bundles of plugins if you hand the plugin system down to 
the (bundeling) plugin. That way, you can load multiple plugins for one 
phase (althoughyou still need distinct phase labels for each plugin).

  #in your core
  $self->plugins->register(
    phase=>'Scan', 
    plugin=>'Plugin::ScanBundle', 
    plugins=>$self->plugins, #plugin system
  );

  #in Plugin::ScanBundle
  has 'plugins'=>(is=>'ro', isa=>'Plugin::Tiny', required=>1); 
  $self->plugins->register (plugin=>'Plugin::Scan1'); 
  $self->plugins->register (plugin=>'Plugin::Scan2'); 
  
  my $scan1=$self->plugins->get('Scan1');
  $scan1->do_something(@args);  

=head2 Require a Plugin Role

You may want to do a plugin role for all you plugins, e.g. to standardize
an interface etc.
  
=cut

has '_registry' => (    #href with phases and plugin objects
    is       => 'ro',
    isa      => 'HashRef[Object]',
    default  => sub { {} },
    init_arg => undef,
);

=attr prefix

Optional init argument. You can have the prefix added to all plugin classes you
register so save some typing and force plugins in your namespace:

  #without prefix  
  my $ps=Plugin::Tiny->new  
  $ps->register(plugin='Your::App::Plugin::Example1');
  $ps->register(plugin='Your::App::Plugin::Example2');

  #with prefix  
  my $ps=Plugin::Tiny->new (  prefix=>'Your::App::Plugin::' );  
  $ps->register(plugin='Example1');
  $ps->register(plugin='Example2');

=cut

has 'prefix' => (is => 'ro', isa => 'Str');

=attr role

Optional init argument. A default role to be applied to all plugins. Can be 
overwritten in register.

=cut

has 'role' => (is => 'ro', isa => 'Str');


#
# METHODS
#

=method $plugin_system->register(phase=>$phase, plugin=>$plugin_class);  

Registers a plugin, e.g. uses it and makes a new plugin object. Needs a
plugin. If you don't specify a phase it, it makes a default phase from the 
plugin class name.

Optionally, you can also specify a role which your plugin will have to be able 
to apply. Specify role=>undef to overwrite global roles.

Remaining key value pairs are passed down to the plugin constructor: 

  $plugin_system->register (
    phase=>$phase,           #optional. Defaults to last part of plugin_class 
    plugin=>$plugin_class,   #required
    role=>$role,             #optional
    plugins=>$plugin_system, #optional
    args=>$more_args,        #optional
  );

A side-effect is that your plugin cannot use 'phase', 'plugin', 'role' as 
named arguments.

Returns the newly created plugin object on success. Confesses on error.

=cut


sub register {
    my $self   = shift;
    my %args   = @_;
    my $plugin = delete $args{plugin} or confess "Need plugin";

    if ($self->prefix) {
        $plugin = $self->prefix . $plugin;
    }
    my $phase = $args{phase} ? delete $args{phase} : $self->defaultPhase($plugin);

    my $role = $self->role if $self->role;    #default role
    $role = delete $args{role} if defined $args{role};

    load_class($plugin) or confess "Can't load $plugin";
    $self->{_registry}{$phase} = $plugin->new(%args);

    if ($role && !$plugin->does($role)) {
        confess qq(Plugin '$plugin' doesn't do role '$role');
    }
    return $self->{_registry}{$phase};
}


=method $plugin=$self->get_plugin ($phase);

Returns the plugin object associated with the phase. Returns undef if no plugin
is registered for this phase.

=cut

sub get_plugin {
    my $self = shift;
    my $phase = shift or return;
    return if (!$self->{_registry}{$phase});
    return $self->{_registry}{$phase};
}


=method $self->defaultPhase ($plugin_class);

Makes a default phase from a class name. If prefix is defined it use tail minus 
'::'. Otherwise just last element of the class name.

For My::Plugin::Long::Example and prefix='My::Plugin::' this results in 
'Long::Example' and without prefix it would be 'Example'.

Returns scalar;

=cut


sub defaultPhase {   
    my $self=shift;
    my $plugin = shift;    #a class name

    if ($self->prefix) {
        my $phase=$plugin;
        $phase=~s/$self->prefix//;
        return $phase=~s/:://g;
    }
    else {
        my @parts = split('::', $plugin);
        return $parts[-1];
    }
}

#
# PRIVATE
#

__PACKAGE__->meta->make_immutable;

1;
