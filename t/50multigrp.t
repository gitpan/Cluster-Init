#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 12 }

use Cluster::Init;

my %parms = (
    'inittab' => 't/clinittab',
    'socket' => 't/clinit.s'
	    );

unless (fork())
{
  my $init = Cluster::Init->daemon(%parms);
  exit;
}
sleep 1;
my $init = Cluster::Init->client(%parms);

`cat /dev/null > t/out`;
ok(lines(),0);
$init->tell("foogrp",1);
$init->tell("bazgrp",1);
sleep 1;
ok(lines(),1);
ok(lastline(),"foo1start");
sleep 2;
$init->tell("bargrp",1);
sleep 1;
ok(lines(),1);
ok(lastline(),"bar1start");
sleep 3;
ok(lines(),1);
ok(lastline(),"foo1end");
sleep 3;
ok(lines(),1);
ok(lastline(),"bar1end");
sleep 3;
ok(lines(),1);
ok(lastline(),"baz1");

$init->shutdown();
ok(1);

