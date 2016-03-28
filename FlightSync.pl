#
# FlightSync.pl 
#
# Copyright 2016, Signiant Inc.
#

use strict;
use File::Basename;
use File::Path;
use File::Copy;
use Getopt::Long;
use Data::Dumper;

${^WIDE_SYSTEM_CALLS}=1;

select STDERR; $| = 1; # Enable immediate flush on STDERR
select STDOUT; $| = 1; # Enable immediate flush on STDOUT

use constant
{
	false	=>	0,
	FALSE	=>	0,
	true	=>	1,
	TRUE	=>	1,
};

use constant
{
	LOGERROR  =>	0,
	LOGWARN	  =>	1,
	LOGINFO	  =>	2,
	LOGDEBUG  =>	3
};

use constant
{
	LOGSTDOUT => 	0,
	LOGSTDERR => 	1
};

use constant
{
	RECURSION_DEPTH_DEFAULT => 3,
	RECURSION_DEPTH_MAX => 20,

	FILES_PER_MANIFEST_DEFAULT => 500,
	FILES_PER_MANIFEST_MAX => 10000,

	PARALLEL_TRANSFERS_DEFAULT => 6,
	PARALLEL_TRANSFERS_MAX => 10,
};

our $LOGLEVELVALUE = LOGINFO;
our $LOGLEVELNAME  = "INFO";
our $DEBUG         = FALSE;
our $IsWindows	   = FALSE;
our $IsUnix        = FALSE;

our $CommandMode;
our	$TopLevelFolder;
our	$MaxDepth;
our	$MaxPathsPerManifest;
our	$ManifestFolder;
our $ParallelTransfers;
our $LogFolder;
our $ConfigFile;
our $CliSequenceNum;

my @MANIFESTLIST;
my @CLIWORKFOLDERS;
my $WorkFolder;

our $ColorReset    = "\033[0m";
our	$AlertColor    = "\033[05m";

our	$GreenPrefix   = "\033[07m\033[32m\033[40m";
our $YellowPrefix  = "\033[07m\033[33m\033[40m";
our $CyanPrefix    = "\033[07m\033[36m\033[40m";
our $WhitePrefix   = "\033[07m\033[37m\033[40m";
our $MagentaPrefix = "\033[07m\033[35m\033[40m";
our $RedPrefix     = "\033[07m\033[31m\033[40m";
our $BluePrefix    = "\033[07m\033[34m\033[40m";

our $GreenText     = "\033[27m\033[32m\033[40m";
our $YellowText    = "\033[27m\033[33m\033[40m";
our $CyanText      = "\033[27m\033[36m\033[40m";
our $WhiteText     = "\033[27m\033[37m\033[40m";
our $MagentaText   = "\033[27m\033[35m\033[40m";
our $RedText       = "\033[27m\033[31m\033[40m";
our $BlueText      = "\033[27m\033[34m\033[40m";

#
# Mac terminal window uses different color codes
#
if (lc($^O) eq "darwin")
{
	$GreenPrefix   = "\033[07m\033[92m\033[40m";
	$YellowPrefix  = "\033[07m\033[93m\033[40m";
	$CyanPrefix    = "\033[07m\033[96m\033[40m";
	$WhitePrefix   = "\033[07m\033[97m\033[40m";
	$MagentaPrefix = "\033[07m\033[95m\033[40m";
	$RedPrefix     = "\033[07m\033[91m\033[40m";
	$BluePrefix    = "\033[07m\033[94m\033[40m";

	$GreenText     = "\033[27m\033[92m\033[40m";
	$YellowText    = "\033[27m\033[93m\033[40m";
	$CyanText      = "\033[27m\033[96m\033[40m";
	$WhiteText     = "\033[27m\033[97m\033[40m";
	$MagentaText   = "\033[27m\033[95m\033[40m";
	$RedText       = "\033[27m\033[91m\033[40m";
	$BlueText      = "\033[27m\033[94m\033[40m";
}

our @PREFIXCOLORS = ( $GreenPrefix, $YellowPrefix, $CyanPrefix, $WhitePrefix, $MagentaPrefix, $RedPrefix, $BluePrefix);
our @TEXTCOLORS   = ( $GreenText,   $YellowText,   $CyanText,   $WhiteText,   $MagentaText, $RedText, $BlueText);

our $DIRSEP = "";
	
###############
sub ShowUsage()
###############
{
	print "\n";
	print "Usage: $0 -init --basefolder=<BaseFolder> --manifestfolder=<ManifestFolder> [--descentdepth=<DescentDepth>] [--maxpathspermanifest=<MaxPathsPerManifest>] [-d]\n";
	print "       $0 -go   --manifestfolder=<ManifestFolder> --logfolder=<LogFolder> [--configfile=<ConfigFile>][--paralleltransfers=<ParallelTransfers>] [-d]\n";
	print "\n";
	print "       -init mode options:\n";
	print "               --basefolder          = Base folder to transfer via Flight\n";
	print "               --manifestfolder      = Folder in which to write per-folder Flight transfer manifests\n";
	print "               --descentdepth        = Depth of folder structure to recurse when building per-folder Flight transfer manifests (Default: " . RECURSION_DEPTH_DEFAULT .")\n";
	print "               --maxpathspermanifest = Maximum number of paths per Flight transfer manifest before partitioning into multiple manifests (Default: " . FILES_PER_MANIFEST_DEFAULT .")\n";
    print "\n";
	print "       -go mode options:\n";
	print "               --manifestfolder      = Folder containing the Flight transfer manifests created by -init mode\n";
	print "               --logfolder           = Folder in which to write Flight CLI and transport log files\n";
	print "               --configfile          = Path to Flight config file to be passed to Flight CLI (Default: CLI folder)\n";
	print "               --paralleltransfers   = Number of parallel Flight transfers to initiate when multiple transfer manifests are present (Default: " . PARALLEL_TRANSFERS_DEFAULT .")\n";
	print "\n";
	print "       General options:\n";
	print "               -d                    = Enable DEBUG output\n";
	print "\n";
}

################
sub Initialize()
################
{
	if ( $LOGLEVELVALUE == LOGERROR )
	{
		$LOGLEVELNAME = "ERROR";
	}
	elsif ( $LOGLEVELVALUE == LOGWARN )
	{
		$LOGLEVELNAME = "WARN";
	}
	elsif ( $LOGLEVELVALUE == LOGINFO )
	{
		$LOGLEVELNAME = "INFO";
	}
	elsif ( $LOGLEVELVALUE == LOGDEBUG )
	{
		$LOGLEVELNAME = "DEBUG";
		$DEBUG = TRUE;
	}

	if ($^O =~ m/MSWin/)
	{
		$IsWindows=TRUE;
		$IsUnix=FALSE;
		$DIRSEP="_!_";
	}
	else
	{
		$IsWindows=FALSE;
		$IsUnix=TRUE;
		$DIRSEP="_!_";
	}
}

#####################
sub SigPrintLog($;$$)
#####################
{
	my $LogString	= $_[0];
	my $MsgLevel	= $_[1]; # Optional
	my $MsgStream	= $_[2]; # Optional

	my @LogArray = split(/\n/, $LogString);

	foreach my $LogMessage (@LogArray)
	{
		chomp($LogMessage);

		if (length($LogMessage) > 2048)
		{
			$LogMessage = substr($LogMessage,0,2048) . "...";
		}

		if (($MsgLevel eq "") && ($LOGLEVELVALUE >= LOGINFO)) # Default is info if MsgLevel not specified
		{
			if ($MsgStream == LOGSTDERR) {
				print STDERR (_GetUtf8String("$LogMessage\n"));
			} else {
				print STDOUT (_GetUtf8String("$LogMessage\n"));
			}
		}
		elsif (($MsgLevel == LOGINFO) && ($LOGLEVELVALUE >= LOGINFO))
		{
			if ($MsgStream == LOGSTDERR) {
				print STDERR (_GetUtf8String("$LogMessage\n"));
			} else {
				print STDOUT (_GetUtf8String("$LogMessage\n"));
			}
		}
		elsif (($MsgLevel == LOGWARN) && ($LOGLEVELVALUE >= LOGWARN))
		{
			if ($MsgStream == LOGSTDERR) {
				print STDERR (_GetUtf8String("$LogMessage\n"));
			} else {
				print STDOUT (_GetUtf8String("$LogMessage\n"));
			}
		}
		elsif (($MsgLevel == LOGERROR) && ($LOGLEVELVALUE >= LOGERROR))
		{
			if ($MsgStream == LOGSTDERR) {
				print STDERR (_GetUtf8String("$LogMessage\n"));
			} else {
				print STDOUT (_GetUtf8String("$LogMessage\n"));
			}
		}
		elsif (($MsgLevel == LOGDEBUG) && ($LOGLEVELVALUE >= LOGDEBUG))
		{
			if ($MsgStream == LOGSTDERR) {
				print STDERR (_GetUtf8String("$LogMessage\n"));
			} else {
				print STDOUT (_GetUtf8String("$LogMessage\n"));
			}
		}
	}

	#
	# Ensures that a string passed in is encoded as UTF8.
	#
	sub _GetUtf8String($)
	{
		use Encode;

		my ($srcString) = @_;
		my $returnString = $srcString;

		eval {
			Encode::decode('UTF-8', $returnString, Encode::FB_QUIET);
		};

		if ($returnString) {
			$returnString = Encode::encode("UTF-8", $srcString);
		} else {
			$returnString = $srcString;
		}

		return $returnString;
	}
}

###############
sub DepthTab($)
###############
{
	my $CurrentDepth = $_[0];
	my $Indent = "";
	
	for (my $i=0; $i < $CurrentDepth; $i++)
	{
		$Indent .= "\t";
	}
	
	return($Indent);
}

######################
sub ValidateInputs ($)
######################
{
	$CommandMode = $_[0];

	if (((lc($CommandMode)) eq "--help") || ((lc($CommandMode)) eq "--help"))
	{
		ShowUsage();
		exit(0);
	}

	Getopt::Long::Configure('pass_through');
	
	if ((lc($CommandMode)) eq "-init")
	{
		GetOptions(
			'basefolder=s' => \$TopLevelFolder,
			'manifestfolder=s' => \$ManifestFolder,
			'descentdepth:s' => \$MaxDepth,
			'maxpathspermanifest:s' => \$MaxPathsPerManifest,
			'd' => \$DEBUG,
		);

		if ($TopLevelFolder eq "") 
		{
			SigPrintLog("\nERROR: No base folder specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		} 
		elsif (! -d $TopLevelFolder)
		{
			SigPrintLog("\nERROR: Base folder does not exist: $TopLevelFolder",LOGERROR);
			ShowUsage();
			return(FALSE);
		}

		if ($MaxDepth eq "") 
		{
			$MaxDepth = RECURSION_DEPTH_DEFAULT
		}
		elsif ($MaxDepth !~ /^\d+?$/ )
		{
			SigPrintLog("\nERROR: Invalid depth value specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		}
		elsif ($MaxDepth < 0) 
		{
			SigPrintLog("\nERROR: Minimum folder recursion depth is 0",LOGWARN);
			ShowUsage();
			return(FALSE);
		}
		elsif ($MaxDepth > RECURSION_DEPTH_MAX) 
		{
			SigPrintLog("\nWARNING: Maximum folder recursion depth will be limited to " . RECURSION_DEPTH_MAX,LOGWARN);
			$MaxDepth = RECURSION_DEPTH_MAX;
		}

		if ($MaxPathsPerManifest eq "") 
		{
			$MaxPathsPerManifest = FILES_PER_MANIFEST_DEFAULT; 
		}
		elsif ($MaxPathsPerManifest !~ /^\d+?$/ )
		{
			SigPrintLog("\nERROR: Invalid maximum files per manifest value specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		}
		elsif ($MaxPathsPerManifest < 0) 
		{
			SigPrintLog("\nERROR: Maximum files per manifest must be 0 (unlimited) or greater",LOGWARN);
			ShowUsage();
			return(FALSE);
		}
		elsif ($MaxPathsPerManifest > FILES_PER_MANIFEST_MAX) 
		{
			SigPrintLog("\nWARNING: Maximum files per manifest will be limited to " . FILES_PER_MANIFEST_MAX,LOGWARN);
			$MaxPathsPerManifest = FILES_PER_MANIFEST_MAX;
		}

		if ($ManifestFolder eq "") 
		{
			SigPrintLog("\nERROR: No manifest folder specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		} 
	}
	elsif ((lc($CommandMode)) eq "-go")
	{
		GetOptions(
			'manifestfolder=s' => \$ManifestFolder,
			'logfolder=s' => \$LogFolder,
			'configfile:s' => \$ConfigFile,
			'paralleltransfers:s' => \$ParallelTransfers,
			'd' => \$DEBUG,
		);

		if ($ManifestFolder eq "") 
		{
			SigPrintLog("\nERROR: No manifest folder specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		} 

		if (! -d $ManifestFolder) 
		{
			SigPrintLog("\nERROR: Manifest folder not found: $ManifestFolder",LOGERROR);
			ShowUsage();
			return(FALSE);
		} 

		if ($LogFolder eq "") 
		{
			SigPrintLog("\nERROR: No transfer log folder specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		} 

		if ($ConfigFile ne "") 
		{
			if (! -f $ConfigFile) 
			{
				SigPrintLog("\nERROR: Invalid config file: $ConfigFile",LOGERROR);
				ShowUsage();
				return(FALSE);
			} 
		}

		if ($ParallelTransfers eq "") 
		{
			$ParallelTransfers = PARALLEL_TRANSFERS_DEFAULT;
		}
		elsif ($ParallelTransfers !~ /^\d+?$/ )
		{
			SigPrintLog("\nERROR: Invalid parallel transfers value specified",LOGERROR);
			ShowUsage();
			return(FALSE);
		}
		elsif ($ParallelTransfers < 1) 
		{
			SigPrintLog("\nERROR: Minimum parallel transfers value is 1",LOGWARN);
			ShowUsage();
			return(FALSE);
		}
		elsif ($ParallelTransfers > PARALLEL_TRANSFERS_MAX) 
		{
			SigPrintLog("\nWARNING: Parallel transfers value limited to " . PARALLEL_TRANSFERS_MAX,LOGWARN);
			$ParallelTransfers = PARALLEL_TRANSFERS_MAX;
		}
	}
	elsif ((lc($CommandMode)) eq "-exec") # exec is an internal-only option used to launch the CLI against a pre-built CLI work folder
	{
		GetOptions(
			'workfolder=s' => \$WorkFolder,
			'logfolder=s' => \$LogFolder,
			'sequencenum:s' => \$CliSequenceNum,
			'configfile:s' => \$ConfigFile,
			'd' => \$DEBUG,
		);
	}
	else
	{
		ShowUsage();
		return(FALSE);
	}
	
	if ($DEBUG)
	{
		$LOGLEVELVALUE = LOGDEBUG;
		$LOGLEVELNAME  = "DEBUG";
	}

	# Normalize slashes and remove trailing slashes
	$TopLevelFolder =~ s|\\|\/|g;
	$TopLevelFolder =~ m/(\\|\/)$/;
	
	$ManifestFolder =~ s|\\|\/|g;
	$ManifestFolder =~ m/(\\|\/)$/;

	$LogFolder      =~ s|\\|\/|g;
	$LogFolder      =~ m/(\\|\/)$/;

	if ($CommandMode ne "-exec")
	{
		#
		# Ensure perl is in the current path since it will be called from from within the script itself...
		#
		my $PerlRC = system("perl -v > /dev/null 2>&1") >> 8;

		if ($PerlRC != 0)
		{
			SigPrintLog("\nERROR: perl executable must be in the current executable search path (PATH variable)",LOGERROR);
			print "\n";
			exit;
		}
		
		#
		# Ensure sigcli is in the current path...
		#
		my $CliRC = system("sigcli --version > /dev/null 2>&1") >> 8; 

		if ($CliRC != 2)
		{
			SigPrintLog("\nERROR: sigcli executable must be in the current executable search path (PATH variable)",LOGERROR);
			print "\n";
			exit;
		}
	}
	
	return(TRUE);
}

#########################
sub InitManifestFolder($)
#########################
{
	my $ManifestFolder = $_[0];

	SigPrintLog("\nInitalizing transfer manifest folder...",LOGINFO);
	
	if (! -d $ManifestFolder)
	{
		if (!mkdir($ManifestFolder))
		{
			SigPrintLog("\nERROR: Could not create transfer manifest folder",LOGERROR);
			return(FALSE);
		}
	}

	my @MANLIST = BuildFileListFromFolder($ManifestFolder);
	
	foreach my $manfile (@MANLIST)
	{
		if ( $manfile =~ m/.flight_manifest.[\d]+$/)
		{
			unlink($manfile);
		}
	}
	
	for (my $i=0; $i < PARALLEL_TRANSFERS_MAX; $i++)
	{
		rmtree("$ManifestFolder/_cli_" . $i . "_");
	}
	
	return(TRUE);
}

####################
sub InitLogFolder($)
####################
{
	my $LogFolder = $_[0];

	SigPrintLog("\nInitalizing transfer log folder...",LOGINFO);

	if (! -d $LogFolder)
	{
		if (!mkdir($LogFolder))
		{
			SigPrintLog("\nERROR: Could not create transfer log folder",LOGERROR);
			return(FALSE);
		}
	}

	my @LOGLIST = BuildFileListFromFolder($LogFolder);
	
	foreach my $logfile (@LOGLIST)
	{
		if (( $logfile =~ m/.log$/) || ( $logfile =~ m/.STATUS=/))
		{
			unlink($logfile);
		}
	}
	
	return(TRUE);
}

################################
sub BuildPathListFromFolder($$$)
################################
{
	my $PARENTDIR    = $_[0];
	my $PATHTYPE     = $_[1];
	my $CurrentDepth = $_[2];
	
	my $DIRENTRY;
	my @PATHLIST = ();
	my $CurrentPath;

	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 1) . ">>> Entering subroutine: BuildPathListFromFolder -- Path type: $PATHTYPE",LOGDEBUG); }

	if ( opendir ( HDIR, $PARENTDIR ) )
	{
		while ( $DIRENTRY = readdir( HDIR ) )
		{
			$CurrentPath = $PARENTDIR . "/" . $DIRENTRY;

			if ($PATHTYPE eq "FILE")
			{
				if ( -f $CurrentPath )
				{
					if (($DIRENTRY ne ".") && ($DIRENTRY ne ".."))
					{
						push(@PATHLIST,$CurrentPath);
						if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "File: [$CurrentPath]",LOGDEBUG); }
					}
				}
			}
			elsif ($PATHTYPE eq "FOLDER")
			{
				if ( -d $CurrentPath )
				{
					if (($DIRENTRY ne ".") && ($DIRENTRY ne ".."))
					{
						push(@PATHLIST,$CurrentPath);
						if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "Folder: [$CurrentPath]",LOGDEBUG); }
					}
				}
			}
		}

		closedir HDIR;
	}
	else
	{
		SigPrintLog(DepthTab($CurrentDepth + 1) . "ERROR: Failed to open folder: $PARENTDIR",LOGERROR);
	}

	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 1) . "<<< Leaving subroutine: BuildPathListFromFolder",LOGDEBUG); }
	
	return @PATHLIST;
}

##############################
sub BuildFileListFromFolder($)
##############################
{
	my $PARENTDIR    = $_[0];
	
	my $DIRENTRY;
	my @FILELIST = ();
	my $CurrentPath;

	if ( opendir ( HDIR, $PARENTDIR ) )
	{
		while ( $DIRENTRY = readdir( HDIR ) )
		{
			$CurrentPath = $PARENTDIR . "/" . $DIRENTRY;

			if ( -f $CurrentPath )
			{
				if (($DIRENTRY ne ".") && ($DIRENTRY ne ".."))
				{
					push(@FILELIST,$CurrentPath);
				}
			}
		}

		closedir HDIR;
	}
	else
	{
		SigPrintLog("ERROR: Failed to open folder: $PARENTDIR",LOGERROR);
	}

	return @FILELIST;
}

###########################
sub GenerateManifest($$$$$)
###########################
{
	my $BaseFolder   = $_[0];
	my $FOLDERLIST   = $_[1]; # ARRAY by reference
	my $FILELIST     = $_[2]; # ARRAY by reference
	my $CurrentDepth = $_[3];
	my $ManifestPart = $_[4];

	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 1) . ">>> Entering subroutine: GenerateManifest",LOGDEBUG); }

	my $TopLevelParentFolder = dirname($TopLevelFolder);
	my $ManifestFileName = $BaseFolder;
	$ManifestFileName =~ s/^$TopLevelParentFolder//g;
	$ManifestFileName =~ s/^[\\\/]//;
	$ManifestFileName =~ s|\/|$DIRSEP|g;

	my $ManifestFilePath = $ManifestFolder . "/" . $ManifestFileName . ".flight_manifest." . ($ManifestPart + 1);
	
	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "MANIFEST FILE: $ManifestFilePath\n",LOGDEBUG); }

	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "MANIFEST: Base Folder: $BaseFolder",LOGDEBUG); }
	
	if (!open(MANIFESTFILE,'>',$ManifestFilePath))
	{
		SigPrintLog("ERROR: Could not create manifest file: $ManifestFilePath",LOGERROR);
	}
	else
	{
		if ($MaxPathsPerManifest == 0)
		{
			foreach my $File (@{$FILELIST})
			{
				print MANIFESTFILE $File . "\n";
				if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "MANIFEST: File: $File", LOGDEBUG); }
			}
		}
		else
		{
			for (my $FileNum = 0; $FileNum < $MaxPathsPerManifest; $FileNum++) 
			{
				if (($FileNum + ($MaxPathsPerManifest * $ManifestPart)) < scalar(@{$FILELIST}))
				{
					my $File = @{$FILELIST}[$FileNum + ($MaxPathsPerManifest * $ManifestPart)];
				
					print MANIFESTFILE $File . "\n";
					if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "MANIFEST: File: $File", LOGDEBUG); }
				}
			}
		}
		
		foreach my $SubFolder (@{$FOLDERLIST})
		{
			print MANIFESTFILE $SubFolder . "\n";
			if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 2) . "MANIFEST: SubFolder: $SubFolder", LOGDEBUG); }
		}
	
		close MANIFESTFILE;
	}

	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth + 1) . "<<< Leaving subroutine: GenerateManifest",LOGDEBUG); }
}

#######################
sub LoadManifests($$;$)
#######################
{
	my $ManifestFolder = $_[0];
	my $MANIFESTLIST   = $_[1]; # ARRAY by reference
	my $SuppressOutput = $_[2];
	
	$SuppressOutput = FALSE if ($SuppressOutput eq "");
	
	my $DIRENTRY;
	my $CurrentPath; 
	
	SigPrintLog("\nLoading Flight transfer manifest files...",LOGINFO) if (!$SuppressOutput);

	if ($DEBUG && !$SuppressOutput) { SigPrintLog(">>> Entering subroutine: LoadManifests",LOGDEBUG); }

	@{$MANIFESTLIST} = ();
	
	if ( opendir ( HDIR, $ManifestFolder ) )
	{
		while ( $DIRENTRY = readdir( HDIR ) )
		{
			$CurrentPath = $ManifestFolder . "/" . $DIRENTRY;

			if ( -f $CurrentPath && $DIRENTRY =~ m/.flight_manifest.[\d]+$/)
			{
				push(@{$MANIFESTLIST},$CurrentPath);
				if ($DEBUG && !$SuppressOutput) { SigPrintLog("Transfer manifest File: [$CurrentPath]",LOGDEBUG); }
			}
		}

		closedir HDIR;
	}
	else
	{
		SigPrintLog("ERROR: Failed to open transfer manifest folder: $ManifestFolder",LOGERROR);
		return(FALSE);
	}

	if ($DEBUG && !$SuppressOutput) { SigPrintLog("<<< Leaving subroutine: LoadManifests",LOGDEBUG); }
	
	return(TRUE);
}

##########################
sub ShowCreatedManifests()
##########################
{
	if (LoadManifests($ManifestFolder,\@MANIFESTLIST))
	{
		my $ManifestCount = scalar(@MANIFESTLIST);
		SigPrintLog("\nFlight transfer manifests created: $ManifestCount",LOGINFO);
		print "\n";
	}
}

############################
sub DistributeManifests($$$)
############################
{
	my $ManifestFolder = $_[0];
	my $MANIFESTLIST   = $_[1]; # ARRAY by reference
	my $CLIWORKFOLDERS = $_[2]; # ARRAY by reference

	my $DIRENTRY;
	my $CurrentPath; 
	
	SigPrintLog("\nAssigning manifest files for Flight CLI execution...",LOGINFO);

	@{$CLIWORKFOLDERS} = ();
	
	if ($DEBUG) { SigPrintLog(">>> Entering subroutine: DistributeManifests",LOGDEBUG); }

	for (my $i=0; $i < PARALLEL_TRANSFERS_MAX; $i++)
	{
		rmtree("$ManifestFolder/_cli_" . $i . "_");
	}
	
	my $ManifestsPerProcess = int(scalar(@{$MANIFESTLIST}) / $ParallelTransfers);
	$ManifestsPerProcess = 1 if $ManifestsPerProcess == 0;

	my $LastManifestCopied = 0;
	my $LastCliUsed = 0; 
	
	for (my $cli=0; $cli < $ParallelTransfers; $cli++)
	{
		for (my $manifest=0; $manifest < $ManifestsPerProcess; $manifest++)
		{
			my $CurrentManifest = ($cli * $ManifestsPerProcess) + $manifest;

			if ($CurrentManifest < scalar(@{$MANIFESTLIST}))
			{
				my $cliFolder = $ManifestFolder . "/_cli_" . ($cli + 1) . "_";
				
				if (! -d $cliFolder)
				{
					mkdir $cliFolder;
					push(@{$CLIWORKFOLDERS},$cliFolder);
				}
				
				SigPrintLog("copying " . @{$MANIFESTLIST}[$CurrentManifest] . " to " . $cliFolder,LOGDEBUG);
				copy(@{$MANIFESTLIST}[$CurrentManifest],$cliFolder); 
			
				$LastManifestCopied = $CurrentManifest;
				$LastCliUsed = $cli;
			}
		}
	}

	my $cli = $LastCliUsed + 1;

	#
	# Make a second pass to distribute any leftovers...
	#
	for (my $manifest = $LastManifestCopied + 1; $manifest < scalar(@{$MANIFESTLIST}); $manifest++)
	{
		if ($cli >= $ParallelTransfers)
		{
			$cli = 0;
		}
		else
		{
			$cli++;
		}

		my $cliFolder = $ManifestFolder . "/_cli_" . ($cli + 1) . "_";

		SigPrintLog("copying " . @{$MANIFESTLIST}[$manifest] . " to " . $cliFolder,LOGDEBUG);
		copy(@{$MANIFESTLIST}[$manifest],$cliFolder); 
	}
	
	if ($DEBUG) { SigPrintLog("<<< Leaving subroutine: DistributeManifests",LOGDEBUG); }

	return(TRUE);
}

#####################
sub DescendFolder($$)
#####################
{
	my $BaseFolder     = $_[0];
	my $CurrentDepth   = $_[1];

	my @FILELIST = ();
	my @FOLDERLIST = ();
	my @NULLFILELIST = ();
	my @NULLFOLDERLIST = ();
	
	if ($CurrentDepth == 0) 
	{
		SigPrintLog("\nAnalyzing source content for transfer manifest creation...",LOGINFO);
	}

	if ($DEBUG) { SigPrintLog("\n" . DepthTab($CurrentDepth) . ">>> Entering subroutine: DescendFolder -- [Folder: $BaseFolder] -- [Depth: $CurrentDepth]",LOGDEBUG); }

	@FILELIST   = BuildPathListFromFolder($BaseFolder,"FILE",$CurrentDepth);
	@FOLDERLIST = BuildPathListFromFolder($BaseFolder,"FOLDER",$CurrentDepth);

	#
	# Write FILES to manifest at all depth levels. 
	#
	# Subfolders are not included in the manifest at intermediate levels - only at the bottom level.
	# This is because intermediate level folders will be recursively traversed and will have their own manifests.
	# Files are always added to the manifest regardless of depth level, but multiple manifests may be required 
	# depending on the MaxPathsPerManifest value.
	#
	my $MaxManifestPart = 0;
	
	if (scalar(@FILELIST) > 0)
	{
		if ($MaxPathsPerManifest == 0)
		{
			GenerateManifest($BaseFolder,\@NULLFOLDERLIST,\@FILELIST,$CurrentDepth,0);
		}
		else
		{
			for (my $ManifestPart=0; $ManifestPart < scalar(@FILELIST) / $MaxPathsPerManifest; $ManifestPart++)
			{
				GenerateManifest($BaseFolder,\@NULLFOLDERLIST,\@FILELIST,$CurrentDepth,$ManifestPart);
				$MaxManifestPart++;
			}
		}
	}

	if ($CurrentDepth == $MaxDepth)
	{
		#
		# Once we hit MAXDEPTH, all subfolders are added to the manifest so that the Flight CLI itself will traverse them.
		#
		if (scalar(@FOLDERLIST) > 0)
		{
			GenerateManifest($BaseFolder,\@FOLDERLIST,\@NULLFILELIST,$CurrentDepth,$MaxManifestPart);
		}
	}

	#
	# Perform a recursive-descent traversal of the directory tree until we reach MAX DEPTH
	#
	if ($CurrentDepth < $MaxDepth) 
	{
		foreach my $SubFolder (@FOLDERLIST) 
		{
			DescendFolder($SubFolder,$CurrentDepth + 1);
		}
	}
	
	if ($DEBUG) { SigPrintLog(DepthTab($CurrentDepth) . "<<< Leaving subroutine: DescendFolder -- [Folder: $BaseFolder] -- [Depth: $CurrentDepth]\n",LOGDEBUG); }
}

###############
sub GoFlight($)
###############
{
	SigPrintLog("\nLaunching Flight CLI processes...",LOGINFO);

	if ($DEBUG) { SigPrintLog(">>> Entering subroutine: GoFlight",LOGDEBUG); }

	my $CLIWORKFOLDERS = $_[0]; # ARRAY by reference

	my $ConfigDirective = "";
	my $DebugDirective = "";
			
	if ($ConfigFile ne "")
	{
		$ConfigDirective = "-f \"$ConfigFile\"";
	}

	if ($DEBUG)
	{
		$DebugDirective = "-d";
	}
	
	my $NumCLIs = scalar(@{$CLIWORKFOLDERS});
	
	for (my $i=0; $i < $NumCLIs; $i++)
	{
		my $CLIFOLDER = @{$CLIWORKFOLDERS}[$i];

		my $FlightCmd;
		my $CliNum = $i+1;

		if ($IsWindows) 
		{
			$FlightCmd = "START \"Signiant Flight CLI Process #" . $CliNum . " of " . ($NumCLIs) . "\" CMD /T:0A /K \"perl FlightSync.pl -exec --workfolder=\"$CLIFOLDER\" --logfolder=\"$LogFolder\" --sequencenum=$CliNum $ConfigDirective $DebugDirective & pause & exit\"";
		}
		else
		{
			$FlightCmd = "perl FlightSync.pl -exec --workfolder=\"$CLIFOLDER\" --logfolder=\"$LogFolder\" --sequencenum=$CliNum $ConfigDirective $DebugDirective &";
		}	

		SigPrintLog("Launching Flight CLI: " . $FlightCmd,LOGDEBUG);
		
		system($FlightCmd);
		
		sleep(1);
	}
	
	if ($DEBUG) { SigPrintLog("<<< Leaving subroutine: GoFlight",LOGDEBUG); }
}

#################
sub OutputLine($$)
#################
{
	my $Line        = $_[0];
	my $SequenceNum = $_[1];
	
	chomp($Line);
	
	if ($IsWindows)
	{
		print $Line . "\n";
	}
	else
	{
		my $colorIndex = ($SequenceNum - 1) % 7; # Max of 7 colors to choose from
		
		my $FmtLine = $PREFIXCOLORS[$colorIndex] . "[Flight $SequenceNum]" . $ColorReset . " ";
		
		if (($Line =~ m/ERROR/) || ($Line =~ m/FAILURE/))
		{
			$FmtLine .= $PREFIXCOLORS[$colorIndex] . $AlertColor  . $Line . $ColorReset;
		}
		else
		{
			$FmtLine .= $TEXTCOLORS[$colorIndex] . $Line . $ColorReset; 
		}
		
		print $FmtLine . "\n";
	}
}

##################
sub ExecFlight($$)
##################
{
	my $WorkFolder = $_[0];
	my $SequenceNum = $_[1];
	my @CLIMANIFESTS = ();
	
	OutputLine("\n",$SequenceNum);
	OutputLine("Initiating Flight transfer...\n",$SequenceNum);

	my $ConfigDirective = "";
	my $DebugDirective = "";
	
	if ($ConfigFile ne "")
	{
		$ConfigDirective = "-f \"$ConfigFile\"";
	}

	if ($DEBUG)
	{
		$DebugDirective = "-v";
	}

	if (LoadManifests($WorkFolder,\@CLIMANIFESTS,TRUE))
	{
		foreach my $Manifest (@CLIMANIFESTS)
		{
			my $TargetFolder = basename($Manifest);
			$TargetFolder =~ s|$DIRSEP|\/|g;
			$TargetFolder =~ s|\.flight_manifest.[\d]+$||g;
		
			my $LogFile = basename($Manifest);
			$LogFile =~ s|\.flight_manifest$||g;
			
			my $FlightCmd = "sigcli $ConfigDirective $DebugDirective -z -d upload -x \"$LogFolder/$LogFile.transport.log\" \"\@$Manifest\" \"sig://$TargetFolder/\"";

			my $CliLog = open(LOGFILE,'>',"$LogFolder/$LogFile.cli.log");

			select LOGFILE; $| = 1;
			select STDOUT; $| = 1;

			OutputLine("\n",$SequenceNum);
			OutputLine("Launching Flight CLI...\n",$SequenceNum);
			OutputLine("\n",$SequenceNum);
			OutputLine("Flight transfer manifest file: $Manifest\n",$SequenceNum);
			OutputLine("\n",$SequenceNum);
			
			if ($DEBUG)
			{
				OutputLine("Flight CLI: " . $FlightCmd . "\n",$SequenceNum);
				OutputLine("\n",$SequenceNum);
			}
			
			OutputLine("\n",$SequenceNum);

			print LOGFILE "Flight CLI: " . $FlightCmd . "\n\n";
			
			my $FlightPID = open(FLIGHTCLI,"$FlightCmd 2>&1 |");
			my $EndSTDOUT = FALSE;
			
			if (!$FlightPID) 
			{
				OutputLine("ERROR: Flight CLI failed to launch\n",$SequenceNum);
				exit(1);
			}

			while ( my $Line = <FLIGHTCLI> ) {
				chomp ($Line);
				
				if ($Line =~ m/^File Statistics:/)
				{
					$EndSTDOUT = TRUE;
				}
					
				if (!$EndSTDOUT)
				{
					OutputLine("$Line\n",$SequenceNum);
				}
				
				print LOGFILE $Line . "\n";
			}

			my $FlightRC = close(FLIGHTCLI) >> 8;
			
			if ($FlightRC == 0) 
			{
				my $StatusFile = "$LogFolder/$LogFile.STATUS=SUCCESS";
				open STATUSFILE, ">$StatusFile"; close STATUSFILE;
			}
			else
			{
				my $StatusFile = "$LogFolder/$LogFile.STATUS=ERROR";
				open STATUSFILE, ">$StatusFile"; close STATUSFILE;
				OutputLine("ERROR: Flight CLI completed with non-zero return code\n",$SequenceNum);
				print LOGFILE "ERROR: Flight CLI completed with non-zero return code\n";
				exit(1);
			}
		}
	}
}

####################################################################################################################################
############################################################# MAIN #################################################################
####################################################################################################################################

Initialize();

if (ValidateInputs(@ARGV[0]))
{
	if ((lc($CommandMode)) eq "-init") 
	{
		if (InitManifestFolder($ManifestFolder))
		{
			DescendFolder($TopLevelFolder,0);
			ShowCreatedManifests();
		}
	}
	elsif ((lc($CommandMode)) eq "-go")
	{
		if (InitLogFolder($LogFolder))
		{
			if (LoadManifests($ManifestFolder,\@MANIFESTLIST))
			{
				if (DistributeManifests($ManifestFolder,\@MANIFESTLIST,\@CLIWORKFOLDERS))
				{
					GoFlight(\@CLIWORKFOLDERS);
				}
			}
		}
	}
	elsif ((lc($CommandMode)) eq "-exec") # exec is an internal-only option used to launch the CLI against a pre-built CLI work folder
	{
		ExecFlight($WorkFolder,$CliSequenceNum);
	}
}

