package Cluster::Init::DFA::Group;
# 
# AUTOMATICALLY GENERATED by ./dot2dfa
# Fri Apr  4 11:40:16 2003

# DO NOT EDIT
#
#   Original .dot file contents included below __END__.
#
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(DFA_ACTIONS CHECKING CONFIGURED DONE DUMPING FAILED HALTING PASSED STARTING STOPPING TELL HALT PROC ALL_STARTED ALL_DONE ALL_PASSED ANY_FAILED OLD_STOPPED TIMEOUT KICKME ALL_HALTED CLEAN);         
our %EXPORT_TAGS = (constants => [qw(CHECKING CONFIGURED DONE DUMPING FAILED HALTING PASSED STARTING STOPPING TELL HALT PROC ALL_STARTED ALL_DONE ALL_PASSED ANY_FAILED OLD_STOPPED TIMEOUT KICKME ALL_HALTED CLEAN)]);

my $debug = $ENV{DEBUG};

# Actions
#   (you need to implement these in caller)
#
#   Action       =>                   Value, # Events it can generate
#
use constant DFA_ACTIONS => (
    CKHALT	 =>   '$self->ckhalt(@arg)', # ALL_HALTED KICKME
					     # TIMEOUT
    CKPROC	 =>   '$self->ckproc(@arg)', # ALL_DONE ALL_PASSED
					     # ANY_FAILED PROC
    CKSTOP	 =>   '$self->ckstop(@arg)', # KICKME OLD_STOPPED
					     # TIMEOUT
    GARBAGE_COLLECT => '$self->garbage_collect(@arg)', # CLEAN
    HALTGRP	 =>  '$self->haltgrp(@arg)', # ALL_HALTED KICKME
					     # TIMEOUT
    KICK	 =>	'$self->kick(@arg)', # ALL_HALTED KICKME
					     # OLD_STOPPED TIMEOUT
    STARTNEXT	 => '$self->startnext(@arg)', # ALL_STARTED PROC
    STOPOLD	 =>  '$self->stopold(@arg)', # KICKME OLD_STOPPED
					     # TIMEOUT
);


my %const2act = DFA_ACTIONS;

# States
# use constant State      =>         Value; # Events it can handle     
#
use constant CHECKING	  =>	'CHECKING'; # ALL_DONE ALL_PASSED
					    # ANY_FAILED HALT PROC
					    # TELL
use constant CONFIGURED   =>  'CONFIGURED'; # HALT TELL
use constant DONE	  =>	    'DONE'; # HALT TELL
use constant DUMPING	  =>	 'DUMPING'; # CLEAN HALT TELL
use constant FAILED	  =>	  'FAILED'; # HALT TELL
use constant HALTING	  =>	 'HALTING'; # ALL_HALTED HALT KICKME
					    # TELL TIMEOUT
use constant PASSED	  =>	  'PASSED'; # HALT TELL
use constant STARTING	  =>	'STARTING'; # ALL_STARTED HALT PROC
					    # TELL
use constant STOPPING	  =>	'STOPPING'; # HALT KICKME OLD_STOPPED
					    # TELL TIMEOUT


# Events
# use constant Event      =>         Value; # States it can be accepted in
#
use constant TELL	  =>	    'TELL'; # CHECKING CONFIGURED
					    # DONE DUMPING FAILED
					    # HALTING PASSED STARTING
					    # STOPPING
use constant HALT	  =>	    'HALT'; # CHECKING CONFIGURED
					    # DONE DUMPING FAILED
					    # HALTING PASSED STARTING
					    # STOPPING
use constant PROC	  =>	    'PROC'; # CHECKING STARTING
use constant ALL_STARTED  => 'ALL_STARTED'; # STARTING
use constant ALL_DONE	  =>	'ALL_DONE'; # CHECKING
use constant ALL_PASSED   =>  'ALL_PASSED'; # CHECKING
use constant ANY_FAILED   =>  'ANY_FAILED'; # CHECKING
use constant OLD_STOPPED  => 'OLD_STOPPED'; # STOPPING
use constant TIMEOUT	  =>	 'TIMEOUT'; # HALTING STOPPING
use constant KICKME	  =>	  'KICKME'; # HALTING STOPPING
use constant ALL_HALTED   =>  'ALL_HALTED'; # HALTING
use constant CLEAN	  =>	   'CLEAN'; # DUMPING


use constant GRAPH => {
  CHECKING   => {
                  ALL_DONE => { action => "", newstate => "DONE" },
                  ALL_PASSED => { action => "", newstate => "PASSED" },
                  ANY_FAILED => { action => "", newstate => "FAILED" },
                  HALT => { action => "HALTGRP", newstate => "HALTING" },
                  PROC => { action => "CKPROC", newstate => "CHECKING" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                },
  CONFIGURED => {
                  HALT => { action => "", newstate => "CONFIGURED" },
                  TELL => { action => "STARTNEXT", newstate => "STARTING" },
                },
  DONE       => {
                  HALT => { action => "HALTGRP", newstate => "HALTING" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                },
  DUMPING    => {
                  CLEAN => { action => "STARTNEXT", newstate => "STARTING" },
                  HALT  => { action => "HALTGRP", newstate => "HALTING" },
                  TELL  => { action => "STOPOLD", newstate => "STOPPING" },
                },
  FAILED     => {
                  HALT => { action => "", newstate => "CONFIGURED" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                },
  HALTING    => {
                  ALL_HALTED => { action => "", newstate => "CONFIGURED" },
                  HALT       => { action => "HALTGRP", newstate => "HALTING" },
                  KICKME     => { action => "KICK", newstate => "HALTING" },
                  TELL       => { action => "STOPOLD", newstate => "STOPPING" },
                  TIMEOUT    => { action => "CKHALT", newstate => "HALTING" },
                },
  PASSED     => {
                  HALT => { action => "", newstate => "CONFIGURED" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                },
  STARTING   => {
                  ALL_STARTED => { action => "CKPROC", newstate => "CHECKING" },
                  HALT => { action => "HALTGRP", newstate => "HALTING" },
                  PROC => { action => "STARTNEXT", newstate => "STARTING" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                },
  STOPPING   => {
                  HALT => { action => "HALTGRP", newstate => "HALTING" },
                  KICKME => { action => "KICK", newstate => "STOPPING" },
                  OLD_STOPPED => { action => "GARBAGE_COLLECT", newstate => "DUMPING" },
                  TELL => { action => "STOPOLD", newstate => "STOPPING" },
                  TIMEOUT => { action => "CKSTOP", newstate => "STOPPING" },
                },
};

my $num2str = {
  "1"       => "CHECKING",
  "1024"    => "HALT",
  "1048576" => "CLEAN",
  "128"     => "STARTING",
  "131072"  => "TIMEOUT",
  "16"      => "FAILED",
  "16384"   => "ALL_PASSED",
  "2"       => "CONFIGURED",
  "2048"    => "PROC",
  "256"     => "STOPPING",
  "262144"  => "KICKME",
  "32"      => "HALTING",
  "32768"   => "ANY_FAILED",
  "4"       => "DONE",
  "4096"    => "ALL_STARTED",
  "512"     => "TELL",
  "524288"  => "ALL_HALTED",
  "64"      => "PASSED",
  "65536"   => "OLD_STOPPED",
  "8"       => "DUMPING",
  "8192"    => "ALL_DONE",
};

my $str2num = {
  ALL_DONE    => 8192,
  ALL_HALTED  => 524_288,
  ALL_PASSED  => 16_384,
  ALL_STARTED => 4096,
  ANY_FAILED  => 32_768,
  CHECKING    => 1,
  CLEAN       => 1_048_576,
  CONFIGURED  => 2,
  DONE        => 4,
  DUMPING     => 8,
  FAILED      => 16,
  HALT        => 1024,
  HALTING     => 32,
  KICKME      => 262_144,
  OLD_STOPPED => 65_536,
  PASSED      => 64,
  PROC        => 2048,
  STARTING    => 128,
  STOPPING    => 256,
  TELL        => 512,
  TIMEOUT     => 131_072,
};

my %num2str = %$num2str;
my %str2num = %$str2num;

sub new
{
  my $class=shift;
  my $self = { @_ };
  bless $self, ref($class) || $class;
  $self->{graph}=GRAPH;
  $self->{except}=\&except unless $self->{except};
  $self->{entersuf} = "_enter" unless $self->{entersuf};
  $self->{leavesuf} = "_leave" unless $self->{leavesuf};
  $self->init() if $self->can('init');
  return $self;
}

# set state blindly, running only the enter routine -- for use at startup
sub state
{
  my ($self,$state)=@_;
  if ($state)
  {
    die __PACKAGE__.": invalid state: ".$state."\n" 
    unless $self->{graph}{$state};
    $self->{state}=$state;
    my $enter = $state.$self->{entersuf};
    $self->$enter($state) if $self->can($enter);
  }
  return $self->{state};
}

# feed event into state engine, then execute leave, action, and enter
# routines
sub tick
{
  my ($self,$event,@arg) = @_;
  die "usage: \$obj->tick(\$event[,\@arg])\n" unless $event;
  @arg=() unless @arg;
  my $numeric=0;
  # $numeric = 1 if $event =~ /^\d+$/;
  # $event=$num2str{$event} if $numeric;
  my $graph = $self->{graph};
  my $oldstate = $self->{state};
  die __PACKAGE__.": initial state not set\n" unless $oldstate;
  unless ($graph->{$oldstate}{$event})
  {
    return (&{$self->{except}}($oldstate,$event),'');
  }
  my $node = $graph->{$oldstate}{$event};
  my $newstate = $node->{newstate};
  my $action = $node->{action} || "";
  my $statechg = ($newstate ne $oldstate);
  $self->{state}=$newstate if $statechg;
  my $leave = $oldstate.$self->{leavesuf};
  my $enter = $newstate.$self->{entersuf};
  $self->$leave($oldstate,$newstate,$action,@arg) 
    if $statechg && $self->can($leave);
  $self->transit($oldstate,$newstate,$action,@arg) 
    if $self->can('transit');
  $self->$enter($oldstate,$newstate,$action,@arg) 
    if $statechg && $self->can($enter);
  return ($newstate,$action);
}

# default exception handler
sub except
{
  my ($state,$event) = @_;
  warn __PACKAGE__.": state '$state': unhandled event: ".$event."\n" if $debug;
  return $state;
}

sub num2str
{
  my $self=shift;
  my $num=shift;
  return $num2str{$num};
}

1;
__END__
digraph "Cluster::Init::DFA::Group"
{
  size="7.5,10";
  //rankdir=LR;
  ratio=fill;

  //async: halt tell
  configured -> starting [label="tell/startnext"];
  configured -> configured [label="halt/"];
  starting -> starting [label="proc/startnext"];
  starting -> checking [label="all_started/ckproc"];
  starting -> stopping [label="tell/stopold"];
  starting -> halting [label="halt/haltgrp"];
  checking -> checking [label="proc/ckproc"];
  checking -> done [label="all_done/"];
  checking -> passed [label="all_passed/"];
  checking -> failed [label="any_failed/"];
  checking -> stopping [label="tell/stopold"];
  checking -> halting [label="halt/haltgrp"];
  done -> stopping [label="tell/stopold"];
  done -> halting [label="halt/haltgrp"];

  stopping -> dumping [label="old_stopped/garbage_collect"];
  stopping -> stopping [label="timeout/ckstop"];
  stopping -> stopping [label="kickme/kick"];
  stopping -> stopping [label="tell/stopold"];
  stopping -> halting [label="halt/haltgrp"];

  halting -> configured [label="all_halted/"];
  halting -> halting [label="timeout/ckhalt"];
  halting -> halting [label="kickme/kick"];
  halting -> halting [label="halt/haltgrp"];
  halting -> stopping [label="tell/stopold"];

  passed -> stopping [label="tell/stopold"];
  passed -> configured [label="halt/"];
  failed -> stopping [label="tell/stopold"];
  failed -> configured [label="halt/"];
  dumping -> stopping [label="tell/stopold"];
  dumping -> starting [label="clean/startnext"];
  dumping -> halting [label="halt/haltgrp"];
  
}

