#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 11 }

use Cluster::Init;
# use Event;

my %parms = (
    'initstat' => 't/clinitstat',
    'inittab' => 't/clinittab',
    'socket' => 't/clinit.s'
	    );

unless (fork())
{
  my $init = daemon Cluster::Init (%parms);
  exit;
}

run(1);

my $init = client Cluster::Init (%parms);

`cat /dev/null > t/out`;
ok(lines(),0);
$init->tell("hellogrp",1);
ok(waitstat($init,"hellogrp",1,"DONE"));
$init->tell("hellogrp","3");
run(1);
ok($init->status(group=>"hellogrp",level=>"3"),"STARTING");
ok(lines(),1);
ok(waitstat($init,"hellogrp",3,"DONE"));
ok(lines(),0);
$init->tell("hellogrp",1);
ok(waitstat($init,"hellogrp",1,"DONE"));
ok(lines(),1);
`cat /dev/null > t/out`;
ok(lines(),0);
$init->tell("hellogrp",1);
run(1);
ok(lines(),0);

$init->shutdown();
ok(1);
