use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Cluster::Init',
    VERSION_FROM => 'lib/Cluster/Init.pm', # finds $VERSION
    AUTHOR       => 'Steve Traugott (stevegt@TerraLuna.Org)',
    ABSTRACT     => 'Clusterwide "init", spawn cluster applications'
);
