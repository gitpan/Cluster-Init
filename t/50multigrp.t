#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 12 }

use Cluster::Init;

my %parms = (
    'cltab' => 't/cltab',
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
ok(waitline("foo1start",2));
ok(lines(),1);
$init->tell("bargrp",1);
ok(waitline("bar1start",5));
ok(lines(),1);
ok(waitline("foo1end"));
ok(lines(),1);
ok(waitline("bar1end"));
ok(lines(),1);
ok(waitline("baz1"));
ok(lines(),1);

$init->shutdown();
ok(1);

