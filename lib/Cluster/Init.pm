package Cluster::Init;
#

#
# The Design 
# ==========
#
# A collection of event-driven DFA state machines; each machine is its
# own object.
#
# Daemon machine started, daemon starts group machines, group machines
# start process machines, process machines start and stop processes.
#
# Client talks to daemon via UNIX domain socket.
#
#
# The Rules 
# =========
#
# Machines start watchers via the kernel.  Only the kernel starts
# watchers (this is so we can clean up references cleanly).
#
# Machines send events to each other via kernel calls.  (This is so we
# can set consistent priorities.)
#
# Only the kernel creates machines.  (This is so the kernel can
# dispatch events cleanly.)
#
# Anyone can read anything in the db, but machines can only change
# their own entry (XXX can this be enforced in the kernel?).  (This is
# so machines don't stomp on others' data.)
#
#
use strict;
use warnings;
use Data::Dump qw(dump);
use Carp::Assert;
use IO::Socket;
use POSIX qw(:signal_h :errno_h :sys_wait_h);
use IPC::LDT qw(              
  LDT_OK
  LDT_CLOSED
  LDT_READ_INCOMPLETE
  LDT_WRITE_INCOMPLETE
);
use Cluster::Init::DB;
use Cluster::Init::Conf;
use Cluster::Init::Util qw(debug);
use Cluster::Init::Daemon;
use base qw(Cluster::Init::Util);

our $VERSION     = "0.117";

my $debug=$ENV{DEBUG} || 0;

my $inittab="/etc/clinittab";

sub daemon
{
  my $class = shift;
  my $self = {@_};
  bless $self, $class;
  my $conf = $self->getconf(context=>'server',@_);
  Cluster::Init::Daemon->new(conf=>$conf);
  $self->loop();
  return 1;
}

sub client
{
  my $class = shift;
  my $self = {@_};
  bless $self, $class;
  my $conf = $self->getconf(context=>'client',@_);
  $self->{'socket'} = $conf->get('socket');
  return $self;
}

sub tell
{
  my $self=shift;
  my $group = shift;
  my $level = shift;
  my $socket = $self->{'socket'};
  affirm { $socket };
  affirm { -S $socket };
  my $client = new IO::Socket::UNIX 
  (
    Peer => $socket,
    Type => SOCK_STREAM
  ) || die $!;
  my $ldt=new IPC::LDT(handle=>$client, objectMode=>1);
  # send command
  debug "sending command $group $level";
  $ldt->send({group=>$group,level=>$level}) || warn $ldt->{'msg'};
  debug "command sent";
  # get response
  my $res;
  until (($res)=$ldt->receive)
  {
    die $ldt->{msg} if $ldt->{rc} == LDT_CLOSED;
  }
  return $res->{msg};
}


=head2 status(group=>'foo',level=>'bar',initstat=>'/tmp/initstat')

This method will read the status file for you, dumping it to stdout.
All arguments are optional.  If you provide 'group' or 'level', then
output will be filtered accordingly.  If you specify 'initstat', then
the status file at the given pathname wil be read (this is handy if
you need to query multiple Cluster::Init status files in a shared cluster
filesystem).

In addition to the usual $obj->status() syntax, the status() method
can also be called as a class function, as in
Cluster::Init::status(initstat=>'/tmp/initstat').   The 'initstat' argument
is required in this case.  Again, this is handy if you want to query a
running Cluster::Init on another machine via a shared filesystem, without
creating an Cluster::Init object or daemon here.  

=cut

sub status
{
  my $self=shift;
  my %parm = @_;
  # allow this to be called as Cluster::Init->status(...)
  $self=bless({},$self) unless ref($self);
  my $group = $parm{'group'} if $parm{'group'};
  my $level = $parm{'level'} if defined($parm{'level'});
  my $initstat = $parm{'initstat'} || $self->conf('initstat');
  die "need to specify initstat" unless $initstat;
  return "" unless -f $initstat;
  my $out ="";
  open(INITSTAT,"<$initstat") || die $!;
  while(<INITSTAT>)
  {
    chomp;
    my ($obj,$name,$stlevel,$state)=split;
    next unless $obj eq "Cluster::Init::Group";
    if ($group)
    {
      next unless $group eq $name;
    }
    if (defined($level))
    {
      next unless $level eq $stlevel;
    }
    $out.="$name " unless $group;
    $out.="$stlevel " unless $level;
    $out.=$state;
    $out.="\n" unless $group && $level;
  }
  return $out;
}

=head2 shutdown()

Causes daemon to stop all child processes and exit.

=cut

sub shutdown
{
  my $self=shift;
  return $self->tell(":::ALL:::",":::SHUTDOWN:::");
}

sub getconf
{
  my $self=shift;
  $inittab=$self->{inittab} if $self->{inittab};
  $self->{conf} = Cluster::Init::Conf->new(inittab=>$inittab,@_);
  my $conf = $self->{conf};
  return $conf;
}

sub conf
{
  my $self=shift;
  my $var=shift;
  die "can't set conf here" if @_;
  my $conf = $self->{conf};
  return $conf->get($var);
}

sub loop
{
  my $rc=Event::loop();
  debug $rc if $rc;
}

package XXX;
use IO::Socket;
# use IO::Select;
use POSIX qw(:signal_h :errno_h :sys_wait_h);
use Event qw(loop unloop unloop_all all_watchers);
use Event::Stats;
# use Time::HiRes qw(time);
use Storable qw(store retrieve freeze thaw dclone);


# Event priorities
use constant PCLIENT => 1; # client input
use constant PCHLD   => 2; # sigchld
use constant PKILL   => 2; # process killers
use constant PSTART  => 2; # process managers

# Event or group bit states
#  renumber with:
#   :perldo $i=1 
#   :'a,'bperldo s/\d+;/$i;/;$i*=2;
use constant CONFIGURED	=>    1; # found in config file
use constant STARTING	=>    2; # to be exec'd
use constant RUNNING	=>    4; # exec complete
use constant EXITED	=>    8; # exited, analysis pending
use constant DONE	=>   16; # exited normally
use constant KILL1	=>   32; # kill 1 sent
use constant KILL2	=>   64; # kill 2 sent
use constant KILL9	=>  128; # kill 9 sent
use constant KILL15	=>  256; # kill 15 sent
use constant KILLED	=>  512; # exited after kill 
use constant PASSED	=> 1024; # 'test' mode exited with zero rc
use constant FAILED	=> 2048; # 'test' mode exited with nonzero rc
use constant REMOVED	=> 4096; # not found in config file
use constant SHUTDOWN	=> 8192; # kill everything and exit

sub debug
{
  my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
  my $subline = (caller(0))[2];
  my $msg = join(' ',@_);
  $msg.="\n" unless $msg =~ /\n$/;
  warn "$$ $subroutine,$subline: $msg" if $debug;
  if ($debug > 1)
  {
    warn _stacktrace();
  }
  if ($debug > 2)
  {
    Event::Stats::collect(1);
    warn sprintf("%d\n%-20s %3s %10s %4s %4s %4s %4s %7s\n", time,
    "DESC", "PRI", "CBTIME", "PEND", "CARS", "RAN", "DIED", "ELAPSED");
    for my $w (reverse all_watchers())
    {
      my @pending = $w->pending();
      my $pending = @pending;
      my $cars=sprintf("%01d%01d%01d%01d",
      $w->is_cancelled,$w->is_active,$w->is_running,$w->is_suspended);
      my ($ran,$died,$elapsed) = $w->stats(60);
      warn sprintf("%-20s %3d %10d %4d %4s %4d %4d %7.3f\n",
      $w->desc,
      $w->prio,
      $w->cbtime,
      $pending,
      $cars,
      $ran,
      $died,
      $elapsed);
    }
  }
}

sub log
{
  my $self=shift;
  my $log = $self->conf('log');
  return unless $log;
  open(LOG,">>$log") || die $!;
  print LOG "@_\n";
  close LOG;
}

=head1 NAME

Cluster::Init - Clusterwide "init", spawn cluster applications

=head1 SYNOPSIS

  use Cluster::Init;

  my $init = new Cluster::Init;

  # spawn all apps for resource group "foo", runlevel "run"
  $init->tell("foo","run");

  # spawn all apps for resource group "foo", runlevel "runmore"
  # (this stops everything started by runlevel "run")
  $init->tell("foo","runmore");

=head1 DESCRIPTION

This module provides basic "init" functionality, giving you a single
inittab-like file to manage initialization and daemon startup across a
cluster or collection of machines.

=head1 USAGE

This module's package includes a script 'clinit', which is intended to
be a bolt-in cluster init tool, calling Cluster::Init.  The script is
called like 'init', with the addition of a new "resource group"
argument.

This module is intended to be used like 'init' and 'telinit' -- the
first execution runs as a daemon, spawning and managing processes.
Later executions talk to the first, requesting it to switch to
different runlevels.

The module references a configuration file, /etc/clinittab by default,
which is identical in format to /etc/inittab, with a new "resource
group" column added.  See t/clinittab in the Cluster::Init distribution for
an example.  This file must be replicated across all hosts in the
cluster by some means of your own.

A "resource group" is a collection of applications and physical
resources which together make up a coherent function.  For example,
sendmail, /etc/sendmail.cf, and the /var/spool/mqueue directory might
make up a resource group. From /etc/clinittab you could spawn the
scripts which update sendmail.cf, mount mqueue, and then start
sendmail itself.

Any time the module changes the runlevel of a resource group, it will
update a status file, /var/run/clinit/initstat by default.  The format of
this file might change -- you are encouraged to use the
Cluster::Init::status() method to read it (though the interface for
status() might change also.)  This will be firmed up before version
1.0.  The reason for this state of flux is that I need status() for an
openMosix HA cluster init layer, which I'll probably call
Cluster::Mosix:HA or somesuch.  Watch CPAN.

In addition to the init-style modes of 'once', 'wait', 'respawn', and
'off', Cluster::Init also supports a 'test' mode.  If the return code of a
'test' mode command is anything other than zero, then the resource
group as a whole is marked as 'failed' in the status file.  If the
return code is zero, then the resource group is marked 'running'.  Again,
this interface may change to support Cluster::Mosix:HA.  See t/* for
examples.


=head1 PUBLIC METHODS

=head2 new

=cut

sub new
{
  my $class=shift;
  $class = (ref $class || $class);
  my $self={};
  $self->{role}='unknown';
  bless $self, $class;

=pod

The constructor accepts an optional hash containing the paths to the
configuration file, socket, and/or status output file, like this:

  my $init = new Cluster::Init (
      'inittab' => '/etc/clinittab',
      'socket' => '/var/run/clinit/init.s'
      'initstat' => '/var/run/clinit/initstat'
			  );

You can also specify 'socket' and 'initstat' locations in the 
configuration file itself, like this:

  # location of socket
  :::socket:/tmp/init.s
  # location of status file
  :::initstat:/tmp/initstat

Settings passed to the constructor normally override any found in the 
inittab file.  You can cause the inittab file settings to take precedence 
though, by saying 'overrride' in the third column of the inittab file,
like this:

  # location of socket
  ::override:socket:/tmp/init.s
  # location of status file
  ::override:initstat:/tmp/initstat

=cut

  my %parms=@_;

  $self->{db} = new DB;
  my $db = $self->{db};

  # parms override inittab
  $self->conf('inittab',$parms{'inittab'} || "/etc/clinittab");
  $self->conf('socket',$parms{'socket'}) if $parms{'socket'};
  $self->conf('initstat',$parms{'initstat'}) if $parms{'initstat'};
  $self->conf('log',$parms{'log'}) if $parms{'log'};
  # inittab *might* override parms
  $self->_inittab();
  # otherwise use defaults
  $self->conf('socket',"/var/run/clinit/init.s") unless $self->conf('socket');
  $self->conf('initstat',"/var/run/clinit/initstat") unless $self->conf('initstat');
  $self->conf('log',"/var/run/clinit/initlog") unless $self->conf('log');

  # ($self->{'group'}, $self->{'level'}) = ("NULL", "NULL");


=pod

The first time this method is executed on a machine, it opens a UNIX
domain socket, /var/run/clinit/init.s by default.  Subsequent executions
communicate with the first via this socket.  

=cut

  $self->_open_socket() || $self->_start_daemon() || die $!;

  return $self;
}

=head2 tell($resource_group,$runlevel)

This method talks to a running Cluster::Init daemon, telling it to switch
the given resource group to the given runlevel.  

All processes listed in the configuration file (normally
/etc/clinittab) which belong to the new runlevel will be started if
they aren't already running.

All processes in the resource group which do not belong to the new
runlevel will be killed.

Other resource groups will not be affected.

=cut

# *all* socket comm to server goes through here
sub tell
{
  my ($self,$group,$runlevel)=@_;
  debug "opening on client side";
  my $socket = $self->_open_socket() || die $!;
  debug "sending $group $runlevel to server";
  print $socket "$group $runlevel\n";
  # debug "reading on client side";
  # my $res = <$socket>;
  close($socket);
  debug "done on client side";
  1;
}

=head2 shutdown()

Causes daemon to stop all child processes and exit.

=cut

sub shutdown
{
  my ($self)=@_;
  $self->tell(":::ALL:::",":::SHUTDOWN:::");
  1;
}

=head2 status(group=>'foo',level=>'bar',initstat=>'/tmp/initstat')

This method will read the status file for you, dumping it to stdout.
All arguments are optional.  If you provide 'group' or 'level', then
output will be filtered accordingly.  If you specify 'initstat', then
the status file at the given pathname wil be read (this is handy if
you need to query multiple Cluster::Init status files in a shared cluster
filesystem).

In addition to the usual $obj->status() syntax, the status() method
can also be called as a class function, as in
Cluster::Init::status(initstat=>'/tmp/initstat').   The 'initstat' argument
is required in this case.  Again, this is handy if you want to query a
running Cluster::Init on another machine via a shared filesystem, without
creating an Cluster::Init object or daemon here.  

=cut

sub status
{
  my $self=shift;
  my %parm = @_;
  # allow this to be called as Cluster::Init->status(...)
  $self=bless({},$self) unless ref($self);
  my $group = $parm{'group'} if $parm{'group'};
  my $level = $parm{'level'} if $parm{'level'};
  my $initstat = $parm{'initstat'} || $self->conf('initstat');
  die "need to specify initstat" unless $initstat;
  return "" unless -f $initstat;
  open(INITSTAT,"<$initstat") || die $!;
  warn <INITSTAT>;
}

=head1 PRIVATE METHODS

The following methods are documented here for internal use only.  No
user serviceable parts inside.

=cut

=head2 _open_socket()

Opens a client-side socket.

=cut

sub _open_socket
{
  my $self=shift;
  my $client = new IO::Socket::UNIX (
      Peer => $self->conf('socket'),
      Type => SOCK_STREAM
				    );
  return $client;
}

=head2 _start_daemon()

Opens server-side socket, starts main event loop, with long-running
event watchers for accepting and processing commands from client,
child exits, status file maintenance, etc.

=cut

sub _start_daemon
{
  my $self=shift;
  my $db=$self->{db};
  my $child;
  unless ($child = fork())
  {
    if ($debug > 4)
    {
      require NetServer::Portal;
      NetServer::Portal->default_start();  # creates server
      warn "NetServer::Portal listening on port ".(7000+($$ % 1000))."\n";
      $Event::DebugLevel=$debug;
    }
    unlink $self->conf('socket');
    my $server = new IO::Socket::UNIX (
      Local => $self->conf('socket'),
      Type => SOCK_STREAM,
      Listen => SOMAXCONN
    ) || die $!;

    Event->io
    (
      desc=>'_daemon',
      fd=>$server,
      cb=>\&_daemon,
      prio=>PCLIENT,
      data=>$self
    );

    Event->var
    (
      desc=>'_writestat',
      var=>\$db->{_mtime},
      poll=>'w',
      cb=>\&_writestat,
      prio=>PCLIENT,
      data=>$self
    );

    # $Event::DIED = sub {
      # Event::verbose_exception_handler(@_);
      # # warn _stacktrace();
      # Event::unloop_all();
      # # exit 1;
      # };

    my $rc = loop();
    debug "loop returned $rc";
    exit 1 unless $rc == SHUTDOWN;
    debug "exiting normally";
    # for my $w (all_watchers)
    # {
      # $w->cancel();
      # }
    exit 0;
  }
  debug "Cluster::Init daemon started as PID $child\n"; 
  sleep 1;
  return $child;
}

=head2 _daemon()

Watcher triggered by I/O activity on server socket; calls accept() and
sets a watcher for client I/O.

=cut

sub _daemon
{
  my $e=shift;
  my $self=$e->w->data;
  my $server=$e->w->fd;
  my $client = $server->accept();
  Event->io
  (
    desc=>'_client',
    fd=>$client,
    cb=>\&_client,
    prio=>PCHLD,
    data=>$self
  );
}

=head2 _client()

Watcher triggered by I/O activity on accept()ed client socket; parses
text from client and does the right thing.

=cut

sub _client
{
  my $e=shift;
  my $self=$e->w->data;
  my $client=$e->w->fd;
  debug "reading on server side";
  my $data=<$client>;
  $e->w->cancel;
  unless ($data)
  {
    debug "no data";
    # print $client "no command seen\n";
    return;
  }
  # warn dump($e);
  # $e->w->debug(0) unless $data;
  chomp($data);
  debug "got: $data\n" if $data;
  my ($group,$level) = split(' ',$data);
  unless (defined($group) && defined($level))
  {
    debug "got garbage";
    return
  }
  if ($level eq ":::SHUTDOWN:::")
  {
    $self->_shutdown();
    # print $client "shutdown accepted\n";
  }
  else
  {
    $self->_tellgroup($group,$level);
    # print $client "command accepted\n";
  }
}

=head2 _tellgroup($group,$level)

Finds the watcher for a particular resource group, and tells it what
the new runlevel is.  If the watcher isn't running yet, then we start
it.  

=cut

sub _tellgroup
{
  my $self=shift;
  my $db=$self->{db};
  my $group=shift;
  my $newlevel=shift;
  debug "_tellgroup $group $newlevel";
  # re-read inittab
  $self->_inittab();
  # find watcher
  affirm { $group };
  my ($summary) = $db->get({type=>'summary',group=>$group});
  unless ($summary)
  {
    $summary = $db->ins
    (
      {
	type=>'summary',
	group=>$group,
	state=>CONFIGURED,
	level=>undef()
      }
    );
    affirm { $summary->{_mtime} };
    my $w = Event->var
    (
      desc=>"_group_$group",
      var=>\$summary->{_mtime},
      cb=>\&_group,
      prio=>PSTART,
      data=>[$self,$summary]
    );
    $summary->{w}=$w;
    # $w->now();
  }
  affirm { $summary->{type} eq 'summary' };
  affirm { $summary->{group} eq $group };
  $db->upd($summary,{newlevel=>$newlevel});
}

=head2 _group()

Watcher triggered by control activity for a resource group; start
and/or stop watchers for the individual entries in the group.
Maintain master summary of group info.

Setting a runlevel of undef() causes the group to stop all of its
processes and cancel its watcher.

=cut

sub _group
{
  my $e=shift;
  my $self=$e->w->data->[0];
  my $summary=$e->w->data->[1];
  $self->_inittab();
  my $db = $self->{db};
  my $group = $summary->{group};
  debug "group $group";
  my $level = $summary->{level};
  my $newlevel = $summary->{newlevel};
  # dump $db;
  my @entry = sort byline $db->get({type=>'entry',group=>$group});
  # make sure every entry has a triggered watcher
  for my $entry (@entry)
  {
    my $tag = $entry->{tag};
    my $w = $entry->{w};
    unless ($w)
    {
      $w = Event->var
      (
	desc=>"_entry_${tag}",
	var=>\$entry->{_mtime},
	cb=>\&_entry,
	prio=>PSTART,
	data=>[$self,$entry]
      );
      $entry->{w}=$w;
    }
    debug "triggering";
    $w->now();
  }

  # $DB::single=1 if $newlevel eq ":::SHUTDOWN:::";
  # update state 
  my $all=$self->_sum(type=>'entry',group=>$group);
  my $old=0;
  if (defined($level))
  {
    my $levelqr   =qr/(^[^,]*$level   [^,]*$)|((^|,)$level   (,|$))/x;
    $old=$self->_sum(type=>'entry',group=>$group,level=>$levelqr);
  }
  # $old=CONFIGURED unless $old;
  my $new=0;
  if (defined($newlevel))
  {
    my $newlevelqr=qr/(^[^,]*$newlevel[^,]*$)|((^|,)$newlevel(,|$))/x;
    $new=$self->_sum(type=>'entry',group=>$group,level=>$newlevelqr);
  }
  $new=SHUTDOWN if $new==0 && $newlevel eq ":::SHUTDOWN:::";
  debug "all $all old $old new $new";
  my $state=$new | ($old & ~CONFIGURED);
  if 
  (
    (defined($summary->{state}) && ($summary->{state} != $state) ) ||
    ! defined($summary->{state})
  )
  {
    $db->upd($summary,{state=>$state}) 
  }

  # update level
  $level=$newlevel if ($old == 0)          && ($new & ~CONFIGURED);
  $level=$newlevel if ($old == CONFIGURED) && ($new & ~CONFIGURED);
  $level=$newlevel if $state == SHUTDOWN;
  if 
  (
    (defined($summary->{level}) && ($summary->{level} ne $level) ) ||
    ! defined($summary->{level})
  )
  {
    $db->upd($summary,{level=>$level});
  }
  # $e->w->stop;
  # $e->w->start;

  debug "group $group state $state level "
  .(defined $level ? $level : 'undef')
  ." newlevel "
  .(defined $newlevel ? $newlevel : 'undef')
  ;

}

sub _sum
{
  my $self=shift;
  my %filter=@_;
  my @item = $self->{db}->get(\%filter);
  my $sum=0;
  for my $item (@item)
  {
    affirm { $item->{state} };
    $sum|=$item->{state};
    # debug "tag ".$item->{tag}." state ".$item->{state}." sum $sum";
  }
  return $sum;
}

=head2 _entry()

Watcher triggered by control activity for an individual inittab entry;
start or stop process accordingly.  Will also be triggered indirectly
by signals, via _sigchld.

Each entry gets an active watcher, all the time, regardless of whether
the entry is for a currently active runlevel or not.

If the inittab entry for a given watcher disappears, then the watcher
kills its own process and cancels itself.

=cut

sub _entry
{
  my $e=shift;
  my $self=$e->w->data->[0];
  my $entry=$e->w->data->[1];
  affirm { $entry->{state} } ;
  affirm { $entry->{w} } ;
  my $db = $self->{db};
  my $w=$e->w;
  my $tag=$entry->{tag};
  debug "entry $tag running, address is $w";
  affirm { $w };
  affirm { $w == $entry->{w} } ;
  my $pid=$entry->{pid} || 0;
  my $group=$entry->{group};
  my $mode = $entry->{mode};
  my $cmd = $entry->{cmd};
  my $elevel=$entry->{level};
  affirm { $elevel } ;
  my @level;
  if ($elevel =~/,/)
  {
    @level = split(',',$elevel);
  }
  else
  {
    @level = split('',$elevel);
  }
  debug "entry $tag has levels ".dump(@level);
  my ($summary) = $db->get({type=>'summary',group=>$group});
  my $level = $summary->{level};
  my $newlevel = $summary->{newlevel};
  # $e->w->stop;
  # $e->w->start;
  my $s = $entry->{state};
  debug "analyzing $tag, state is $s";
  {

    $s|= SHUTDOWN if $newlevel eq ":::SHUTDOWN:::";

    (STARTING | RUNNING) & $s && do
    {
      unless (grep /^$newlevel$/, @level)
      {
	$self->_kill($entry);
	last;
      }
    };

    CONFIGURED == $s && do
    {
      last unless grep /^$newlevel$/, @level;
      # this is the *only* place a process gets started
      $s|=STARTING;
      $db->upd($entry,{state=>$s});
      # prevent race -- start the signal handler before forking
      Event->signal
      (
	desc=>"_sigchld_${tag}_$elevel",
	signal=>'CHLD',
	cb=>\&_sigchld,
	prio=>PCHLD,
	repeat=>1,
	data=>[$self,$entry]
      );
      my $childpid;
      unless ($childpid = fork())
      {
	# child
	# prevent race -- wait for SIGCONT from parent
	debug "waiting for SIGCONT: $tag";
	kill 19, $$;
	debug "$tag exec $cmd\n";
	exec($cmd);
	die $!;
      }
      # parent
      $s|=RUNNING;
      $db->upd($entry,{state=>$s,rc=>undef,pid=>$childpid});
      debug "sending $tag SIGCONT";
      kill 18, $childpid;
      debug "$childpid forked: $tag: $cmd\n";
      last;
    };

    (CONFIGURED | STARTING | RUNNING) == $s && do
    {
      $db->upd($entry,{state=>RUNNING});
      last;
    };

    RUNNING == $s && do {last};

    (CONFIGURED | SHUTDOWN) == $s && do
    {
      # all done
      # $db->del($entry);
      $e->w->stop();
      last;
    };

    (CONFIGURED | STARTING | RUNNING | SHUTDOWN) == $s && do
    {
      $self->_kill($entry);
      last;
    };

    (KILLED | REMOVED) & $s && do
    {
      affirm { kill(0,$entry->{pid}) == 0 };
      $db->del($entry);
      $e->w->cancel();
      last;
    };

    (REMOVED & $s) && do
    {
      # we've been removed -- kill the process
      $self->_kill($entry);
      last;
    };

    KILLED & $s && do
    {
      affirm { kill(0,$entry->{pid}) == 0 };
      if ($newlevel eq ":::SHUTDOWN:::")
      {
	$db->upd($entry,{state=>SHUTDOWN});
	last;
      }
      $db->upd($entry,{state=>CONFIGURED});
    };

    EXITED & $s && do
    {
      affirm { kill(0,$entry->{pid}) == 0 };
      for ($mode)
      {
	/^wait$/    && do { $db->upd($entry,{state=>DONE}) };
	/^once$/    && do { $db->upd($entry,{state=>DONE}) };
	/^respawn$/ && do { $db->upd($entry,{state=>CONFIGURED}) };
	/^test$/    && do 
	{ 
	  my $rc=$entry->{rc};
	  debug "$pid got rc $rc";
	  my $state=$rc ? FAILED : PASSED;
	  $db->upd($entry,{state=>$state}) 
	};
      }
      affirm { $entry->{state} != EXITED };

      last;
    };

    (DONE | PASSED | FAILED) & $s && do 
    {
      if ($newlevel eq ":::SHUTDOWN:::")
      {
	$db->upd($entry,{state=>SHUTDOWN});
	last;
      }
      last if $newlevel eq $level;
      $db->upd($entry,{state=>CONFIGURED});
      last;
    };

    SHUTDOWN == $s && do
    {
      last;
    };

    die "unknown state $s in ".$entry->{tag};
    
  }
}

sub byline
{
  $a->{line} <=> $b->{line};
}

sub _stacktrace
{
  my $out="";
  for (my $i=1;;$i++)
  {
    my @frame = caller($i);
    last unless @frame;
    $out .= "$frame[3] $frame[1] line $frame[2]\n";
  }
  return $out;
}

sub _writestat
{
  my $e=shift;
  my $self=$e->w->data;
  my $db = $self->{db};
  # debug "in _writestat";
  return unless $self->conf('initstat');
  my $initstat = $self->conf('initstat');
  my $tmp = "$initstat.".time();
  # for my $group (keys %{$self->{'status'}})
  store($db,$tmp) || die $!;
  rename($tmp,$initstat) || die $!;
}

sub _shutdown
{
  my $self=shift;
  my $db=$self->{db};
  for my $summary ($db->get({type=>'summary'}))
  {
    # tell each group to go away
    my $group = $summary->{group};
    affirm { $group };
    $self->_tellgroup($group,":::SHUTDOWN:::");
    debug "done telling";
  }
  my $w = Event->timer
  (
    desc=>'_halt',
    at=>time+1,
    interval=>1,
    cb=>\&_halt,
    prio=>0,
    data=>$self
  );
  $w->now();
}

sub _halt
{
  my $e=shift;
  my $self=$e->w->data;
  my $db=$self->{db};
  debug "halting";
  for my $summary ($db->get({type=>'summary'}))
  {
    my $group = $summary->{group};
    my $level = $summary->{level};
    debug "$group level is $level";
    if ($summary->{level} ne ":::SHUTDOWN:::")
    {
      $self->_tellgroup($group,":::SHUTDOWN:::");
    debug "done telling again";
      return 1;
    }
  }
  debug "unlooping";
  unloop_all(SHUTDOWN);
}

sub _kill
{
  my $self = shift;
  my $entry = shift;
  my $tag = $entry->{tag};
  my $pid = $entry->{pid};
  debug "killing $tag";
  my $i=0;
  for my $sig (2,15,9)
  {
    Event->timer
    (
      desc=>'__kill',
      at=>time+$i,
      interval=>10,
      cb=>\&__kill,
      prio=>PKILL,
      data=>[$self,$entry,$sig]
    );
    $i+=10;
  }
}

sub __kill
{
  my $e=shift;
  my $self=$e->w->data->[0];
  my $db=$self->{db};
  my $entry=$e->w->data->[1];
  my $sig=$e->w->data->[2];
  my $tag = $entry->{tag};
  my $pid = $entry->{pid};
  my $state = $entry->{state};
  unless ($pid)
  {
    $e->w->stop;
    return;
  }
  unless (kill(0,$pid))
  {
    debug "killed $pid\n";
    $db->upd($entry,{pid=>0,state=>($state|=KILLED)});
    $e->w->stop;
    return;
  }
  debug "killing $pid with $sig\n";
  kill($sig,$pid);
  my $sigbit;
  $sigbit = KILL2  if $sig == 2;
  $sigbit = KILL9  if $sig == 9;
  $sigbit = KILL15 if $sig == 15;
  $db->upd($entry,{state=>($state|=$sigbit)});
}

sub _sigchld
{
  my $e=shift;
  my $self=$e->w->data->[0];
  my $entry=$e->w->data->[1];
  my $db=$self->{db};
  # debug dump($self);
  # debug "got _sigchld in\n". _stacktrace;
  debug "got _sigchld in ".$entry->{tag};
  my $pid = $entry->{pid};
  affirm { $pid };
  my $waitpid = waitpid($pid, &WNOHANG);
  my $rc = $?;
  # debug "waitpid returned: $waitpid\n";
  affirm { $waitpid != -1 };
  unless (kill(0,$waitpid) == 0)
  {
    # still running -- false alarm
    debug $entry->{tag}." false alarm";
    return;
  }
  affirm { $pid == $waitpid };
  # $pid exited
  debug "$pid returned $rc";
  my $state=$entry->{state}|EXITED;
  $db->upd($entry,{state=>$state,rc=>$rc});
  $e->w->stop;
}


=head1 BUGS

=head1 AUTHOR

	Steve Traugott
	CPAN ID: STEVEGT
	stevegt@TerraLuna.Org
	http://www.stevegt.com

=head1 COPYRIGHT

Copyright (c) 2003 Steve Traugott. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

perl(1).

=cut

1; 

__END__


