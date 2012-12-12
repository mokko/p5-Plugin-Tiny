#ABSTRACT: A tiny plugin system for perl
package Plugin::Tiny;
{
  $Plugin::Tiny::VERSION = '0.002';
}
use strict;
use warnings;
use Carp 'confess';
use Class::Load 'load_class';
use Moose;
use namespace::autoclean;


has '_registry' => (    #href with phases and plugin objects
    is       => 'ro',
    isa      => 'HashRef[Object]',
    default  => sub { {} },
    init_arg => undef,
);


has 'prefix' => (is => 'ro', isa => 'Str');


has 'role' => (is => 'ro', isa => 'Str');


#
# METHODS
#

sub register {
    my $self   = shift;
    my %args   = @_;
    my $plugin = delete $args{plugin} or confess "Need plugin";
    if ($self->prefix) {
        $plugin = $self->prefix . $plugin;
    }
    my $phase = $args{phase} ? delete $args{phase} : _lastPart($plugin);

    my $role = $self->role if $self->role;    #default role
    $role = delete $args{role} if $args{role};

    load_class($plugin) or confess "Can't load $plugin";
    $self->{_registry}{$phase} = $plugin->new(%args);

    if ($role && !$plugin->does($role)) {
        confess qq(Plugin doesn't plugin into role '$role');
    }
    return $self->{_registry}{$phase};
}



sub get_plugin {
    return $_[0]->{_registry}{$_[1]};
}


#
# PRIVATE
#

sub _lastPart {    #function!
    my $plugin = shift;                 #a class name
    my @parts = split('::', $plugin);
    return $parts[-1];
}

__PACKAGE__->meta->make_immutable;

1;
__END__
=pod

=head1 NAME

Plugin::Tiny - A tiny plugin system for perl

=head1 VERSION

version 0.002

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

=head1 ATTRIBUTES

=head2 prefix

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

=head2 role

Optional init argument. A default role to be applied to all plugins. Can be 
overwritten in register.

=head1 METHODS

=head2 $plugin_system->register(phase=>$phase, plugin=>$plugin_class);  

Optionally, you can also specify a role which your plugin will have to be able 
to apply. Remaining key value pairs are passed down to the plugin constructor: 

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

=head2 my $plugin=$self->get_plugin ($phase);

Returns the plugin object associated with the phase.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

