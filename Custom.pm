package Slim::Utils::OS::Custom;

# Custom OS file for pCP 3.5.0   https://www.picoreplayer.org
#
# This version only downloads the update link to
# /tmp/slimupdate/update_url
#
# Revision 1.1
# 2017-04-16	Removed /proc from a music path
#
# Revision 1.2
# 2017-08-14    Added Manual Plugin directory at Cache/Plugins


use strict;
use warnings;

use base qw(Slim::Utils::OS::Linux);

use File::Spec::Functions qw(catdir);

use constant MAX_LOGSIZE => 1024*1024*1; # maximum log size: 1 MB
use constant UPDATE_DIR  => '/tmp/slimupdate';

sub initDetails {
	my $class = shift;

	$class->{osDetails} = $class->SUPER::initDetails();
	$class->{osDetails}->{osName} = 'piCore';

	return $class->{osDetails};
}

sub getSystemLanguage { 'EN' }

sub localeDetails {
	my $lc_ctype = 'utf8';
	my $lc_time = 'C';
       
	return ($lc_ctype, $lc_time);
}

=head2 dirsFor( $dir )

Return OS Specific directories.

Argument $dir is a string to indicate which of the server directories we
need information for.

=cut

sub dirsFor {
	my ($class, $dir) = @_;

	my @dirs;
	
	if ($dir eq 'updates') {

		mkdir UPDATE_DIR unless -d UPDATE_DIR;

		@dirs = (UPDATE_DIR);
	}
	else {
		@dirs = $class->SUPER::dirsFor($dir);

		if ($dir eq "Plugins") {
			push @dirs, catdir( Slim::Utils::Prefs::preferences('server')->get('cachedir'), 'Plugins' );
			unshift @INC, catdir( Slim::Utils::Prefs::preferences('server')->get('cachedir') );
		}
	}

	return wantarray() ? @dirs : $dirs[0];
}

sub canAutoUpdate { 1 }
sub installerExtension { 'tgz' }
sub installerOS { 'nocpan' }

sub getUpdateParams {
	my ($class, $url) = @_;
	
	if ($url) {
		my ($version, $revision) = $url =~ /(\d+\.\d+\.\d+)(?:.*(\d{5,}))?/;
		$revision ||= '';
		$::newVersion = Slim::Utils::Strings::string('PICORE_UPDATE_AVAILABLE', "$version - $revision", $url);
		
		require File::Slurp;
		
		my $updateFile = UPDATE_DIR . '/update_url';
			
		if ( File::Slurp::write_file($updateFile, $url) ) {
			main::INFOLOG && Slim::Utils::Log::logger('server.update')->info("Setting update url file to: $url"); 
		}
		else {
			Slim::Utils::Log::logger('server.update')->warn("Unable to update version file: $updateFile");
		}
	}
	
	return;
}                                                                                               

sub logRotate {
	# only keep small log files (1MB) because they are in RAM
	Slim::Utils::OS->logRotate($_[1], MAX_LOGSIZE);
}       

sub ignoredItems {
	return (
		'bin'	=> '/',
		'dev'	=> '/',
		'etc'	=> '/',
		'opt'	=> '/',
		'init'	=> '/',
		'root'	=> '/',
		'sbin'	=> '/',
		'tmp'	=> '/',
		'var'	=> '/',
		'lib'	=> '/',
		'run'	=> '/',
		'sys'	=> '/',
		'usr'	=> '/',
		'proc'  => '/',
		'lost+found'=> 1,
	);
}

1;

