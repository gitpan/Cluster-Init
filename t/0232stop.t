#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
our $inittab;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 10 }

use Cluster::Init::Conf;
use Cluster::Init::Group;
use Cluster::Init::Kernel;
use Cluster::Init::Process;
use Cluster::Init::DFA::Group qw(:constants);
use Data::Dump qw(dump);

my $conf = Cluster::Init::Conf->new(inittab=>$inittab,context=>'server');
my $data;

# create dfa
my $dfa=Cluster::Init::Group->new ( group=>'test', conf=>$conf );
ok(go($dfa,CONFIGURED));

# abort in STARTING...
$data={level=>2};
# $ENV{DEBUG}=1;
$data->{level}=2;
$dfa->event(TELL,$data);
ok(go($dfa,STARTING,4));
$data->{level}=1;
$dfa->event(TELL,$data);
ok(go($dfa,STOPPING));
ok(go($dfa,STARTING,6));
ok(go($dfa,CHECKING,7));
# ...and in CHECKING...
$data->{level}=2;
$dfa->event(TELL,$data);
ok(go($dfa,STOPPING));
# ...and in STOPPING
$data->{level}=3;
$dfa->event(TELL,$data);
ok(go($dfa,STOPPING));
ok(go($dfa,DUMPING,2));
ok(go($dfa,STARTING,2));
ok(go($dfa,CHECKING,5));

$dfa->destruct;

### once

### respawn

### stop fg


1;
