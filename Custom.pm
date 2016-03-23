package Slim::Utils::OS::Custom;

# Custom OS file for piCore 7.x   http://www.tinycore.net
#
# This version only downloads the update link to
# /tmp/slimupdate/update_url
#
# Revision 1.0

use strict;
use warnings;
use Config;
use File::Spec::Functions qw(:ALL);
use FindBin qw($Bin);
use base qw(Slim::Utils::OS);

use constant MAX_LOGSIZE => 1024*1024*1; # maximum log size: 1 MB

sub name {
	return 'piCore';
}

sub initDetails {
	my $class = shift;

	$class->{osDetails}->{'os'} = 'piCore';
	$class->{osDetails}->{osName} = $Config{'osname'} || 'piCore';
	$class->{osDetails}->{uid}    = getpwuid($>);
	$class->{osDetails}->{osArch} = $Config{'myarchname'};

	return $class->{osDetails};
}

sub canDBHighMem {
	my $class = shift;
    
	require File::Slurp;
        
	if ( my $meminfo = File::Slurp::read_file('/proc/meminfo') ) {
		if ( $meminfo =~ /MemTotal:\s+(\d+) (\S+)/sig ) {
			my ($value, $unit) = ($1, $2);
                                
		# some 1GB systems grab RAM for the video adapter - enable dbhighmem if > 900MB installed
			if ( ($unit =~ /KB/i && $value > 900_000) || ($unit =~ /MB/i && $value > 900) ) {
				return 1;
			}
		}
	}
	return 0;
}

sub initSearchPath {
	my $class = shift;

	$class->SUPER::initSearchPath();

	my @paths = (split(/:/, ($ENV{'PATH'} || '/sbin:/usr/sbin:/bin:/usr/bin')), qw(/usr/bin /usr/local/bin /usr/sbin ));
	
	Slim::Utils::Misc::addFindBinPaths(@paths);
}

=head2 dirsFor( $dir )

Return OS Specific directories.

Argument $dir is a string to indicate which of the server directories we
need information for.

=cut

sub dirsFor {
	my ($class, $dir) = @_;

	my @dirs = $class->SUPER::dirsFor($dir);
	
	# some defaults
	if ($dir =~ /^(?:strings|revision|convert|types|repositories)$/) {

		push @dirs, $Bin;

	} elsif ($dir eq 'log') {

		push @dirs, $::logdir || catdir($Bin, 'Logs');

	} elsif ($dir eq 'cache') {

		push @dirs, $::cachedir || catdir($Bin, 'Cache');

	} elsif ($dir =~ /^(?:music|playlists)$/) {

		push @dirs, '';

	# we don't want these values to return a(nother) value
	} elsif ($dir =~ /^(?:libpath|mysql-language)$/) {

	} elsif ($dir eq 'prefs' && $::prefsdir) {
		
		push @dirs, $::prefsdir;
		
    } elsif ($dir eq 'updates') {
	    
		my $updateDir = '/tmp/slimupdate';

        mkdir $updateDir unless -d $updateDir;
        	
		@dirs = $updateDir;
                        
	} else {

		push @dirs, catdir($Bin, $dir);
	}
	return wantarray() ? @dirs : $dirs[0];
}

sub initPrefs {
	my ($class, $defaults) = @_;
	
	$defaults->{checkVersionInterval} = '2592000';
	$defaults->{checkVersionLastTime} = 1458146048;
}

# don't download/cache firmware for other players, but have them download directly
sub directFirmwareDownload { 1 };

sub canAutoUpdate { 1 }
sub runningFromSource { 0 }
sub installerExtension { 'tgz' }
sub installerOS { 'nocpan' }

sub getUpdateParams {
	my ($class, $url) = @_;
	my $updateFile = '/tmp/slimupdate/update_url';
	if ($url) {
		$url =~ /(\d\.\d\.\d).*?(\d{5,})/;
		$::newVersion = Slim::Utils::Strings::string('PICORE_UPDATE_AVAILABLE', "$1 - $2", $url );
			
		if ($url && open(my $file,">$updateFile")) {
			main::INFOLOG &&Slim::Utils::Log->info("Setting update url file to: $url"); 
			print $file $url;
			close $file;
		}
		elsif ($url) {
			Slim::Utils::Log->warn("Unable to update version file: $updateFile");
		}
	}
	return;
}                                                                                               

sub logRotate
{
    my $class   = shift;
	my $dir     = shift || Slim::Utils::OSDetect::dirsFor('log');
        
	# only keep small log files (1MB) because they are in RAM
	Slim::Utils::OS->logRotate($dir, MAX_LOGSIZE);
}       

sub ignoredItems {
	return (
		'bin'	=> '/',
		'dev'	=> '/',
		'etc'	=> '/',
		'opt'	=> '/',
		'etc'	=> '/',
		'init'	=> '/',
		'root'	=> '/',
		'sbin'	=> '/',
		'tmp'	=> '/',
		'var'	=> '/',
		'lib'	=> '/',
		'run'	=> '/',
		'sys'	=> '/',
		'usr'	=> '/',
		'lost+found'=> 1,
	);
}

1;

