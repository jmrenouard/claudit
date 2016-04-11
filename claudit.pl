#!/bin/env perl

# The Artistic License 2.0
# Copyright (c) 2016 Jean-Marie Renouard
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

use Cwd 'abs_path';
use File::Basename;
use Data::Dumper qw/Dumper/;

my $outputfile = "./result.log";
my $binDir="/usr/local/lib/postgres/bin";
my $psql="$binDir/psql -Upostgres";
my @elf64Exex=`file $binDir/*| sed -E 's/,.*//g'| grep 'ELF 64'| cut -d: -f1`;
map { s/\n$//g; s/^\s+//g; s/\s+$//g; } @elf64Exex;
$outputfile = abs_path( $outputfile );

my $fh = undef;
open( $fh, '>', $outputfile ) or die("Fail opening $outputfile") if defined($outputfile);

# Setting up the colors for the print styles
my $me=`whoami`;
$me =~s/\n//g;
my $good = ( $opt{nocolor} == 0 ) ? "[\e[0;32mOK\e[0m]" : "[OK]";
my $bad = ( $opt{nocolor} == 0 ) ? "[\e[0;31m!!\e[0m]" : "[!!]";
my $info = ( $opt{nocolor} == 0 ) ? "[\e[0;34m--\e[0m]" : "[--]";
my $deb = ( $opt{nocolor} == 0 ) ? "[\e[0;31mDG\e[0m]" : "[DG]";
my $cmd = ( $opt{nocolor} == 0 ) ? "\e[1;32m[CMD]($me)" : "[CMD]($me)";
my $end = ( $opt{nocolor} == 0 ) ? "\e[0m" : "";
# Super structure containing all information
my %result;
# Functions that handle the print styles
sub prettyprint { print $_[0] . "\n" ; print $fh $_[0] . "\n" if defined($fh); }
sub goodprint { prettyprint $good. " " . $_[0] unless ( $opt{nogood} == 1 ); }
sub infoprint { prettyprint $info. " " . $_[0] unless ( $opt{noinfo} == 1 ); }
sub badprint { prettyprint $bad. " " . $_[0] unless ( $opt{nobad} == 1 ); }
sub debugprint { prettyprint $deb. " " . $_[0] unless ( $opt{debug} == 0 ); }
sub redwrap { return ( $opt{nocolor} == 0 ) ? "\e[0;31m" . $_[0] . "\e[0m" : $_[0]; }
sub greenwrap { return ( $opt{nocolor} == 0 ) ? "\e[0;32m" . $_[0] . "\e[0m" : $_[0]; }
sub cmdprint { prettyprint $cmd." ". $_[0]. $end; }
sub infoprintml { for my $ln(@_) { $ln =~s/\n//g; infoprint "\t$ln"; } }
sub infoprintcmd { cmdprint "@_"; infoprintml grep { $_ ne '' and $_ !~ /^\s*$/ } `@_ 2>&1`; }
sub headerprint {
        my $tln=100;
        my $sln=$tln/4;
        my $ln=length("@_")+2;

        prettyprint " ";
        prettyprint "-"x$tln;
        prettyprint "-"x$sln ." @_ ". "-"x($tln-$ln-$sln);
        prettyprint "-"x$tln;
}
sub infoprinthcmd {
#       print Dumper @_;
        headerprint "$_[0]";
        infoprintcmd "$_[1]";
}

headerprint "Begin Audit Script";
infoprinthcmd ("OS Release", "cat /etc/redhat-release /etc/os-release");
infoprinthcmd ("Server Type", "virt-what");
infoprinthcmd ("Kernel Information", "uname -a");
infoprinthcmd ("Uptime System", "uptime");
infoprinthcmd ("RAM Usage", "free -m; free -g");
infoprinthcmd "Statistics Virtual Memory", "vmstat -s";
infoprinthcmd "Statistics Virtual Memory(2)", "vmstat | column -t";
infoprinthcmd "Nb Processor(hyperthreading included)", "grep -c processor /proc/cpuinfo";
infoprinthcmd "Error Disk", "dmidecode -t 17| grep -i error| sort | uniq -c";
infoprinthcmd "Swappiness", "sysctl -a | grep -i swappin";
infoprinthcmd "Shared memory", "sysctl -a | grep -i shm";
infoprinthcmd "TCP Slot Entries", "sysctl -a | grep -i sunrpc";
infoprinthcmd "Security limits", "cat /etc/security/limits.conf /etc/security/limits.d/*";
infoprinthcmd "Tuned profile", "tuned-adm list";
infoprinthcmd "Tuned status", "service tuned status";
infoprinthcmd "Statistics I/O", "iostat";

infoprinthcmd "local hosts", "cat /etc/hosts";
infoprinthcmd "Network cards", "ifconfig";
infoprinthcmd "Mount point space", "df -h";
infoprinthcmd "Mount point inode", "df -i";
infoprinthcmd "Partition Volume Information", "pvscan;pvdisplay";
infoprinthcmd "Volume Group Information", "vgscan;vgdisplay";
infoprinthcmd "Logical Volume Information", "lvscan;lvdisplay";
infoprinthcmd "NFS Mountpoints Information", "grep nfs /etc/fstab";
infoprinthcmd ("RPM Installed PostgreSQL", "rpm -qa | grep -i postgres");
infoprinthcmd ("RPM Information PostgreSQL", "rpm -qa | grep -i postgres| xargs -n 1 rpm -qi");
infoprinthcmd ("RPM files PostgreSQL", "rpm -qa | grep -i postgres| xargs -n 1 rpm -ql");

headerprint "Binaries Version PostgreSQL";
for my $tool ( @elf64Exex ) {
        infoprintcmd "$tool --version";
}

infoprinthcmd "Command line Version PostgreSQL", "$psql  -a -c 'select version()'";

infoprinthcmd "Binary compilation PostgreSQL", "find $binDir -type f | xargs -n 1 file | sed -E 's/,.*//g'";

infoprinthcmd "Binary RPM PostgreSQL", "find $binDir -type f | xargs -n 1 rpm -q --whatprovides";

infoprinthcmd "User PostgreSQL", "grep postgres /etc/passwd";
infoprinthcmd "Group PostgreSQL", "grep postgres /etc/group";

infoprinthcmd "PostgreSQL Processus", "ps -edf | grep --color=always '[p]ostgres' | grep -v ' postgres: postgres postgres'";

infoprinthcmd "PostgreSQL Server Processus", "ps -edf | grep --color=always '[p]ostgres -D ' | grep -v ' postgres: postgres postgres'";

headerprint "PostgreSQL Binary linked library without lib lib";
for my $elfBin( @elf64Exex) {
        infoprintcmd "ldd $elfBin| grep -v $binDir";
}

infoprinthcmd "YUM Security Packages", "yum clean all; yum --security check-update";
infoprinthcmd "YUM Update Packages", "yum clean all; yum check-update";
infoprinthcmd "SSHD configuration", "grep -Ei 'user|X11|root|allow|protocol|auth|interval|permit' /etc/ssh/sshd_config";
infoprinthcmd "SSH Key Compare root/postgres", "diff ~postgres/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub && echo 'keys are identical'";
infoprinthcmd "SSH root Authorized-keys content with postgres rsa key", "grep \"\$(cat ~postgres/.ssh/id_rsa.pub)\" ~/.ssh/authorized_keys && echo 'Key is included'";
infoprinthcmd "SSH postgres Authorized-keys content with posgres rsa key", "grep \"\$(cat ~postgres/.ssh/id_rsa.pub)\" ~postgres/.ssh/authorized_keys && echo 'Key is included'";
infoprinthcmd "SSH root Authorized-keys content with root rsa key", "grep \"\$(cat /root/.ssh/id_rsa.pub)\" ~/.ssh/authorized_keys && echo 'Key is included'";
infoprinthcmd "SSH postgres Authorized-keys content with root rsa key", "grep \"\$(cat /root/.ssh/id_rsa.pub)\" ~postgres/.ssh/authorized_keys && echo 'Key is included'";
infoprinthcmd "PostgreSQL users", "$psql -c 'select * from pg_user'";
infoprinthcmd "PostgreSQL databases", "$psql -c 'select * from pg_database'";
my $pglogdir=`$psql -ntA -c "select (select setting from pg_settings where name = 'data_directory') || '/' || (select setting from pg_settings where name = 'log_directory') "`;
$pglogdir=~s/\n//g;
infoprinthcmd "PostgreSQL log dir", "echo $pglogdir";
for my $patt ('ERROR', 'FATAL', 'WARN', 'STATEMENT') {
        infoprinthcmd "PostgreSQL log file $patt count", "grep -c '$patt' $pglogdir/*";
}
for my $dr('bin', 'share', 'include', 'lib') {
        infoprinthcmd "PostgreSQL binary file owned by postgres in $dr", " find /usr/local/lib/postgres/$dr -type f | xargs -n 1 ls -ls| grep -c 'postgres postgres'";
        infoprinthcmd "Listing of /usr/local/lib/postgres/$dr", "ls -ls /usr/local/lib/postgres/$dr ";
}

headerprint "End Audit Script";
