#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 9 }

use Cluster::Init;

my %parms = (
    'initstat' => 't/clinitstat',
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
$init->tell("pidgrp",1);
ok(waitstat($init,"pidgrp",1,"DONE"));
ok(lines(),1);
my $pid=lastline();
`cp t/clinittab t/clinittab.sav`;
`echo "scram:scram2:1:wait:sleep 1" > t/clinittab`; 
$init->tell("scram",1);
ok(waitstat($init,"scram",1,"DONE"));
my $pide=lastline();
ok($pide,$pid);
sleep 10;
my $pidf=lastline();
ok($pide,$pidf);
`cp t/clinittab.sav t/clinittab`;
$init->tell("pidgrp",1);
ok(waitstat($init,"pidgrp",1,"DONE"));
my $pidg=lastline();
ok(kill(0,$pidg),1);

$init->shutdown();

ok(1);
