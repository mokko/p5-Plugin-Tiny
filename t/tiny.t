#!perl

use strict;
use warnings;
use Test::More;
use Plugin::Tiny;
use Try::Tiny;
use FindBin;
use File::Spec;
use Scalar::Util 'blessed';
use Data::Dumper;
use lib File::Spec->catfile('t', 'lib');

use_ok('Plugin::Tiny');

package SampleCore;
use Moose;
has 'plugin_system'=> (is=>'ro', isa=>'Plugin::Tiny', required=>1);
1;

package SampleBundle;
use Moose;
has 'core'=> (is=>'ro', isa=>'Object', required=>1);
1;


package main;



my $ps = Plugin::Tiny->new();
ok($ps, 'new');

ok( $ps->register(
        phase   => 'foo',               #required
        plugin  => 'TinyTestPlugin',    #required
        plugin_system => $ps,
        bar     => 'tiny',
    ),
    'simple register'
);

try {
    $ps->register(
        phase  => 'foo',                #required
        plugin => 'TinyTestPlugin',     #required
        bar    => 'tiny',
    );
}
finally {
    ok(@_, 'register fails without attr plugin_system');
};


try {
    $ps->register(
        phase  => 'foo',                  #required
        plugin => 'nonexistingPlugin',    #required
        bar    => 'tiny',
    );
}
finally {
    ok(@_, 'register fails when non-existing plugin is required');
};


my ($p1, $p2);
ok($p1 = $ps->get_plugin('foo'), 'get p1');
is($p1->do_something, 'doing something', 'execute return value');
ok($p1->register_another_plugin, 'registering a new plug from inside a plug');
ok($p2 = $ps->get_plugin('bar'), 'get p2');
is( $p2->do_something,
    'a plugin that is loaded by another plugin',
    'return looks good'
);

my $aCore=SampleCore->new(plugin_system=>$ps);
ok ($aCore, 'aCore created');
ok ($aCore->plugin_system->register(plugin=>'TinySubPlug', plugin_system=>$ps),'another register');
ok ($aCore->plugin_system->register(plugin=>'TinyTestPlugin', plugin_system=>$ps),'another register');

done_testing;
