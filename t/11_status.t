#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 2 }

use Cluster::Init;

my %parms = (
    'inittab' => 't/clinittab',
    'socket' => 't/clinit.s',
    'initstat' => 't/clinitstat'
	    );
unless (fork())
{
  my $init = Cluster::Init->daemon (%parms);
  exit;
}
run(1);

my $init = Cluster::Init->client (%parms);
my $out;

$init->tell("hellogrp","1");
run(6);
$out = $init->status();
# warn $out;
ok($out =~ /^hellogrp\s+1\s+DONE\s*$/ms);
$init->shutdown();
waitdown();

# warn "bare status()";
$out = Cluster::Init->status(initstat=>'t/clinitstat');
# warn $out;
ok($out =~ /^$/);

