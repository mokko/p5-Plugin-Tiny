
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A tiny plugin system for perl",
  "AUTHOR" => "Maurice Mengel <mauricemengel\@gmail.com>",
  "BUILD_REQUIRES" => {
    "File::Spec" => 0,
    "FindBin" => 0,
    "Moo::Role" => 0,
    "Test::More" => 0,
    "Try::Tiny" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Plugin-Tiny",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Plugin::Tiny",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Module::Runtime" => 0,
    "Moo" => 0,
    "MooX::Types::MooseLike::Base" => 0,
    "Scalar::Util" => 0,
    "namespace::clean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.011",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



