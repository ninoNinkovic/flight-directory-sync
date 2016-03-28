# flight-directory-sync
[Signiant Flight](http://signiant.com/products/flight/) is a file transfer service designed for large files. In certain situtations, with very large numbers of files in a large number of subfolders, Flight performance can be improved by using the file system to determine the files to transfer, and passing the list of files to the Flight command line interface (CLI).

Signiant has developed these bash scripts which can be used to synchronize a large number of files to AWS or Azure using Signiant Flight.

# Usage: 
Run in “-init” mode first to create the set of manifests. The deeper the “—descentdepth” value, the more manifests will be created.

Run in “-go” mode to execute the CLI against all of the pre-created manifests. By default there will be up to 6 parallel “launcher” processes, each of which will execute their designated manifests sequentially.
 
NOTES:
- The option names only have to be specified long enough to be unique (e.g. --man == --manifestfolder, etc).
- Perl will have to be in the $PATH, as will the CLI (or have “.” in your $PATH and have the CLI in the working directory).
- The default config file will be picked up if in the same directory as the CLI, otherwise you can explicitly specify which config file to use

## Generate Manifest: 
```perl
FlightSync.pl -init --basefolder=<BaseFolder> --manifestfolder=<ManifestFolder> [--descentdepth=<DescentDepth>] [--maxpathspermanifest=<MaxPathsPerManifest>] [-d]
```
--basefolder          = Base folder to transfer via Flight

--manifestfolder      = Folder in which to write per-folder Flight transfer manifests

--descentdepth        = Depth of folder structure to recurse when building per-folder Flight transfer manifests (Default: 3)

--maxpathspermanifest = Maximum number of paths per Flight transfer manifest before partitioning into multiple manifests (Default: 500)
-d = Enable debug output
 
## Transfer Files: 
```perl
FlightSync.pl -go   --manifestfolder=<ManifestFolder> --logfolder=<LogFolder> [--configfile=<ConfigFile>][--paralleltransfers=<ParallelTransfers>] [-d]
```
--manifestfolder      = Folder containing the Flight transfer manifests created by -init mode

--logfolder           = Folder in which to write Flight CLI and transport log files

--configfile          = Path to Flight config file to be passed to Flight CLI (Default: CLI folder)

--paralleltransfers   = Number of parallel Flight transfers to initiate when multiple transfer manifests are present (Default: 6)
-d = Enable debug output
```