#ABSTRACT: A tiny plugin system for perl
package Plugin::Tiny;
{
  $Plugin::Tiny::VERSION = '0.006';
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


has 'debug' => (is => 'ro', isa => 'Bool', default => sub {0});


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

    if (defined $self->{_registry}{$phase} && ! $args{force}) {
        confess <<END
There is already a plugin registered under this phase. If you really want to 
overwrite the current plugin with a new one, use 'force=>1'.
END
    } 

    load_class($plugin) or confess "Can't load '$plugin'";

    if ($role && !$plugin->DOES($role)) {
        confess qq(Plugin '$plugin' doesn't do role '$role');
    }
    $self->{_registry}{$phase} = $plugin->new(%args)
      || confess "Can't make $plugin";
    print "register $plugin [$phase]\n" if $self->debug;
    return $self->{_registry}{$phase};
}



sub register_bundle {
    my $self = shift;
    my $bundle = shift or return;
    foreach my $plugin (keys %{$bundle}) {
        my %args = %{$bundle->{$plugin}};
        $args{plugin} = $plugin;
        $self->register(%args) or confess "Registering $plugin failed";
    }
    return $bundle;
}



sub get_plugin {
    my $self = shift;
    my $phase = shift or return;
    return if (!$self->{_registry}{$phase});
    return $self->{_registry}{$phase};
}



sub default_phase {
    my $self = shift;
    my $plugin = shift or return;    #a class name

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
    my $self = shift;
    my $plugin = shift or return;
    blessed($plugin);
    my $current_class = $self->get_class($plugin);

    #print 'z:['.join(' ', keys %{$self->{_registry}})."]\n";
    foreach my $phase (keys %{$self->{_registry}}) {
        my $registered_class = blessed($self->{_registry}{$phase});
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

version 0.006

=head1 SYNOPSIS

  use Plugin::Tiny;           #in your core
  my $ps=Plugin::Tiny->new(); #plugin system
  
  #load plugin_class (and perhaps phase) from your configuration
  $ps->register(
    phase=>$phase,         #optional
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
overwritten in C<register>.

=head1 METHODS

=head2 register

Registers a plugin, i.e. loads it and makes a new plugin object. Needs a
plugin package name (plugin). Returns the newly created plugin object on 
success. Confesses on error.

=head3 Arguments

=head4 plugin

The package name of the plugin. Required. Internally, the value of C<prefix>
is prepended to plugin, if set.

=head4 phase

A phase asociated with the plugin. Optional. If not specified, Plugin::Tiny 
uses C<default_phase> to determine the phase.

=head4 role

A role that the plugin has to appply. Optional. Specify role=>undef to unset 
global roles.

=head4 force

Force re-registration of a previously used phase. Optional.

Plugin::Tiny confesses if you try to register a phase that has previously been
assigned. To overwrite this message make force true.

With force both plugins will be loaded (required, imported) and both return new 
objects for their respective plugin classes, but after the second plugin is 
made, the first one can't be accessed anymore through get_plugin.

=head4 all other arguments

Remaining arguments are passed down to the plugin constructor. Optional.

    $obj=$ps->register(
        plugin=>$plugin_class,   #required
        args=>$more_args,        #optional
    );
    #Plugin::Tiny return result of
    #$plugin_class->new (args=>$args);

N.B. A side-effect of these arguments is that your plugin cannot use 'phase', 
'plugin', 'role', 'force' as named arguments.

=head2 register_bundle

Registers a bundle of plugins in no particular order. A bundle is just a 
hashRef with info needed to issue a series of register calls (see C<register>).

Confesses if a plugin cannot be registered. Otherwise returns $bundle or undef.

  sub bundle{
    return {
      'Store::One' => {   
          phase  => 'Store',
          role   => undef,
          dbfile => $self->core->config->{main}{dbfile},
        },
       'Scan::Monitor'=> {   
          core   => $self->core
        },
    };
  }
  $ps->register_bundle(bundle)

If you want to add or remove plugins, use hashref as usual:
  undef $bundle->{$plugin}; #remove a plugin using package name
  $bundle->{'My::Plugin'}={phase=>'foo'}; #add another plugin

To facilitate inheritance of your plugins perhaps you put the hashref in a 
separate sub, so a child bundle can extend or remove plugins from yours.

=head2 get_plugin

Returns the plugin object associated with the phase. Returns undef on failure.

  $plugin=$ps->get_plugin ($phase);

=head2 default_phase

Makes a default phase from (the plugin's) class name. Expects a $plugin_class. 
Returns scalar or undef. If prefix is defined it use tail and removes all '::'. 
If no prefix is set default_phase returns the last element of the class name:

    $ps=Plugin-Tiny->new;
    $ps->default_phase(My::Plugin::Long::Example); # returns 'Example'

    $ps=Plugin-Tiny->new(prefix=>'My::Plugin::');
    $ps->default_phase(My::Plugin::Long::Example); # returns 'LongExample'

=head2 get_class 

returns the plugin's class. A bit like C<ref $plugin>. Not sure what it returns
on error. Todo!

  $class=$ps->get_class ($plugin);

=head2 get_phase

returns the plugin's phase. Returns undef on failure. Normally, you should not
need this:
  $phase=$ps->get_phase ($plugin);

=head1 SOME THOUGHTS

=head2 Your Plugins

Plugin::Tiny requires that your plugins are objects (a package with new). 
Plugin::Tiny uses Moose internally, but this being perl you are of course free 
to use whatever object system you like.

    package My::Plugin; #a complete plugin that doesn't do very much
    use Moose; 
    
    sub do_something {
        print "Hello World\n";
    }
    
    1;

=head2 Recommendation: First Register Then Do Things

Plugin::Tiny suggests that you first register (load) all your plugins before 
you actually do something with them. Internal C<require> / C<use> of your 
packages is deferred until runtime. You can control the order in which plugins 
are loaded (in the order you call C<register>), but if you manage to load all 
of them before you do anything, you can forget about order.

You know Plugin::Tiny's phases at compile time, but not which plugins will be
loaded.

=head2 Recommendation: Require a Plugin Role

You may want to do a plugin role for all you plugins, e.g. to standardize
the interface for your plugins. Perhaps to make sure that a specific sub is
available in the plugin:

  package My::Plugin; 
  use Moose;
  with 'Your::App::Role::Plugin';
  #...

=head2 Plugin Bundles

You can create bundles of plugins if you hand the plugin system down to 
the (bundleing) plugin. That way, you can load multiple plugins for one 
phase. You still need unique phases for each plugin:

  package My::Core;
  use Moose; #optional
  has 'plugins'=>(
    is=>'ro',
    isa=>'Plugin::Tiny', 
    default=>sub{Plugin::Tiny->new},
  );

  sub BUILD {
    $self->plugins->register(
      phase=>'Scan', 
      plugin=>'PluginBundle', 
      plugins=>$self->plugins, #plugin system
    );
  }

  package PluginBundle;
  use Moose;
  has 'plugins'=>(is=>'ro', isa=>'Plugin::Tiny', required=>1); 

  sub bundle {
      {Plugin::One=>{},Plugin::Two=>{}}
  }  
  sub BUILD {
    #phase defaults to 'One' and 'Two':
    $self->plugins->register_bundle(bundle());
  
    #more or less the same as:    
    #$self->plugins->register (plugin=>'Plugin::One');  
    #$self->plugins->register (plugin=>'Plugin::Two'); 
  }
  
  sub start {
    my $one=$self->plugins->get('One');
    $one->do_something(@args);  
  }

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

