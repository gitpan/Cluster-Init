#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 16 }

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
$init->tell("foogrp",1);
ok(waitstat($init,"foogrp",1,"DONE"));
ok(lastline(),"foo1start");
$init->tell("foogrp",2);
ok(waitstat($init,"foogrp",2,"DONE"));
ok(lastline(),"foo1start");
1 until lastline() eq "foo1end";
ok(1);

$init->tell("foogrp",99);
ok(waitstat($init,"foogrp",99,"DONE"));
$init->tell("foogrp",1);
ok(waitstat($init,"foogrp",1,"DONE"));
ok(lines(),1);
ok(lastline(),"foo1start");
$init->tell("foogrp",3);
ok(waitstat($init,"foogrp",3,"DONE"));
ok(lines(),1);
ok(lastline(),"foo3");
sleep 7;
ok(lines(),1);
ok(lastline(),"foo3");

$init->shutdown();
ok(1);

__END__
