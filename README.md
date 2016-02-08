# flight-directory-sync
Bash scripts used to synchronize large number of files to Cloud storage using Signiant Flight

## create_manifest.sh

Creates multiple manifest files from the specified source directory. The cloud storage target path is encoded in the manifest file name. This is accomplished by replacing the directory separators with the character sequence "\_!\_". If this sequence of characters are used as part of a filename, the replacement string (DIR_SEP_PATTERN) must be replaced.

### Usage

``` create_manifest.sh <Source Directory> <Manifest Output Directory> ```

Source Directory - Specifies the directory to be transfered by Flight. Optional parameter, default value './'.

Manifest Output Directory - Specifies temporary directory in which to create the manifest files. This directory will be created automatically. Optional parameter, default value './manifest'.

### Example

```
$ ./create_manifest.sh /tmp/dataset/

Creating manifest files in '/tmp/manifest' .

Distributing manifests for parallel execution
  Creating directory '/tmp/manifest_0'  -  Use 'send_files.sh /tmp/manifest_0' to transfer files specified in 'manifest_0' manifests.
  Creating directory '/tmp/manifest_1'  -  Use 'send_files.sh /tmp/manifest_1' to transfer files specified in 'manifest_1' manifests.
  Creating directory '/tmp/manifest_2'  -  Use 'send_files.sh /tmp/manifest_2' to transfer files specified in 'manifest_2' manifests.
```


## send_files.sh

Sends all manifest files to Flight CLI application to be transfered to cloud storage. The cloud storage target path is encoded in the manifest file name. This is accomplished by replacing the directory separators with the character sequence "\_!\_". If this sequence of characters are used as part of a filename, the replacement string (DIR_SEP_PATTERN) must be replaced. DIR_SEP_PATTERN **MUST** match the pattern used in create_manifest.sh script.

The absolute path to the Flight CLI (AKA sigcli) **SHOULD** be specified in the SIG_CLI_DIR script variable. If it is not the script will attempt to run the CLI from the same directory as the send_file.sh script.

The results of the transfer will be placed in STATUS & LOG files. From the example above /tmp/manifest_0_status, and /tmp/manifest_0_log.

### Usage

``` send_files.sh <Manifest Directory> ```

Manifest Directory -  Specifies the directory which contains the manifest files generated by the 'create_manifest.sh' script.

### Example

```
$ ./send_files.sh manifest_0/

Total number of Manifest files to transfer:        5

09:43:31 COMPLETED /tmp/manifest_0/dataset_!_small_dataset_!_01
09:43:33 COMPLETED /tmp/manifest_0/dataset_!_small_dataset_!_04
09:43:36 COMPLETED /tmp/manifest_0/dataset_!_small_dataset_!_07
09:43:40 COMPLETED /tmp/manifest_0/dataset_!_small_dataset_!_10
09:43:42 COMPLETED /tmp/manifest_0/dataset_!_small_dataset_!_13
```