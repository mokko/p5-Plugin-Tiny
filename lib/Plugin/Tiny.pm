#ABSTRACT: A tiny plugin system for perl
package Plugin::Tiny;
{
  $Plugin::Tiny::VERSION = '0.003';
}
use strict;
use warnings;
use Carp 'confess';
use Class::Load 'load_class';
use Moose;
use namespace::autoclean;
use Scalar::Util 'blessed';
#use Data::Dumper;


has '_registry' => (    #href with phases and plugin objects
    is       => 'ro',
    isa      => 'HashRef[Object]',
    default  => sub { {} },
    init_arg => undef,
);


has 'debug'=>(is=>'ro', isa=>'Bool', default=> sub{0});


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
    my $phase =
      $args{phase}
      ? delete $args{phase}
      : $self->default_phase($plugin);

    my $role = $self->role if $self->role;    #default role
    $role = delete $args{role} if exists $args{role};

    load_class($plugin) or confess "Can't load '$plugin'";
 
    if ($role && !$plugin->does($role)) {
        confess qq(Plugin '$plugin' doesn't do role '$role');
    }
    $self->{_registry}{$phase} = $plugin->new(%args) || confess "Can't make $plugin";
    print "register $plugin [$phase]\n" if $self->debug;
    return $self->{_registry}{$phase};
}



sub get_plugin {
    my $self = shift;
    my $phase = shift or return;
    return if (!$self->{_registry}{$phase});
    return $self->{_registry}{$phase};
}




sub default_phase {
    my $self   = shift;
    my $plugin = shift;    #a class name

    if ($self->prefix) {
        my $phase  = $plugin;
        my $prefix = $self->prefix;
        $phase =~ s/$prefix//;
        $phase =~ s/:://g;
        return $phase;
    }
    else {
        my @parts = split('::', $plugin);
        return $parts[-1];
    }
}


sub get_class {
    my $self = shift;
    my $plugin = shift or return;
    blessed($plugin);
}



sub get_phase {
    my $self         = shift;
    my $plugin       = shift or return;
    blessed($plugin);
    my $current_class = $self->get_class($plugin);
    #print 'z:['.join(' ', keys %{$self->{_registry}})."]\n";
    foreach my $phase (keys %{$self->{_registry}}) {
        my $registered_class=blessed ($self->{_registry}{$phase});
        print "[$phase] $registered_class === $current_class\n";
        return $phase if ("$registered_class" eq "$current_class");
    }
            
}

#
# PRIVATE
#

__PACKAGE__->meta->make_immutable;

1;

__END__
=pod

=head1 NAME

Plugin::Tiny - A tiny plugin system for perl

=head1 VERSION

version 0.003

=head1 SYNOPSIS

  #in your core
  use Plugin::Tiny; 
  my $ps=Plugin::Tiny->new(); #plugin system
  
  #load plugin_class (and perhaps phase) from your configuration
  $ps->register(
    phase=>$phase,         #optional; defaults to last part of plugin class
    plugin=>$plugin_class, #required
    role=>$role,           #optional
    arg1=>$arg1,           #optional
    arg2=>$arg2,           #optional
  );

  #execute your plugin's methods 
  my $plugin=$ps->get_plugin ($phase); 
  $plugin->do_something(@args);  

=head1 DESCRIPTION

Plugin::Tiny is minimalistic plugin system for perl. Each plugin is associated
with a keyword (referred to as phase). A limitation of Plugin::Tiny is that 
each phase can have only one plugin. 

=head2 Bundles of Plugins

You can still create bundles of plugins if you hand the plugin system down to 
the (bundeling) plugin. That way, you can load multiple plugins for one 
phase (you still need distinct phase labels for each plugin).

  #in your core
  use Moose; #optional
  has 'plugins'=>(
    is=>'ro',
    isa=>'Plugin::Tiny', 
    default=>sub{}
  );

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

=head2 debug

expects a boolean. Prints additional info to STDOUT.

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

=head2 $ps->register(phase=>$phase, plugin=>$plugin_class);  

Registers a plugin, e.g. uses it and makes a new plugin object. Needs a
plugin. If you don't specify a phase it, it uses a default phase from the 
plugin class name. See method C<default_phae> for details.

Optionally, you can also specify a role which your plugin will have to be able 
to apply. Specify role=>undef to unset global roles.

Remaining key value pairs are passed down to the plugin constructor: 

  $plugin_system->register (
    plugin=>$plugin_class,   #required
    phase=>$phase,           #optional
    role=>$role,             #optional
    plugins=>$plugin_system, #optional
    args=>$more_args,        #optional
  );

A side-effect is that your plugin cannot use 'phase', 'plugin', 'role' as 
named arguments.

Returns the newly created plugin object on success. Confesses on error.

=head2 $plugin=$ps->get_plugin ($phase);

Returns the plugin object associated with the phase. Returns undef if no plugin
is registered for this phase.

=head2 $ps->defaultPhase ($plugin_class);

Makes a default phase from a class name. If prefix is defined it use tail minus 
'::'. Otherwise just last element of the class name.

For My::Plugin::Long::Example and prefix='My::Plugin::' this results in 
'Long::Example' and without prefix it would be 'Example'.

Returns scalar;

=head2 $class=$ps->get_class ($plugin); 

returns the plugin's class. A bit like C<ref $plugin>. Not sure what it returns
on error. Todo!

=head2 $phase=$ps->get_phase ($plugin); 

returns the plugin's phase. Returns undef on failure. Normally, you should not
need this.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

