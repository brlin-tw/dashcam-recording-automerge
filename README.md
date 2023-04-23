# Dashcam recording automerge utility

Automatic merging dashcam recordings that are named in a specific fashion

![Continuous Integration(CI) status badge](https://github.com/brlin-tw/dashcam-recording-automerge/actions/workflows/run-continuous-integration.yml/badge.svg "Continuous Integration(CI) status") [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/github.com/brlin-tw/dashcam-recording-automerge "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/github.com/brlin-tw/dashcam-recording-automerge)

## Prerequisites

This utility requires the following software to be installed and their
executables to be available in the system's command search PATHs:

* [Bash](https://www.gnu.org/software/bash/)(>=4.3)
* [ffmpeg-cat](https://github.com/brlin-tw/ffmpeg-cat)
* [GNU Core Utilities(Coreutils)](https://www.gnu.org/software/coreutils/)
* [Grep](https://www.gnu.org/software/grep/)

Note that the dependencies of the dependencies(e.g. FFmpeg) must be
satisfied, as well.

This software is specifically tested in Ubuntu GNU+Linux operating
system, however it should work in any similar environments as well.

## Usage

1. Download [the release package](https://github.com/brlin-tw/dashcam-recording-automerge/releases)
1. Extract the release package
1. Launch a text terminal
1. Run the program with [the required environment variables specified](#environment-variables):

    ```sh
    env \
        SOURCE_DIR=/path/to/my/source/recordings \
        DEST_DIR=/path/to/my/merged/recordings \
        RECORDING_SPLIT_MINUTES=5 \
        /path/to/merge-dashcam-recordings.sh
    ```

1. Verify results and do post-processing when necessary

## Environment variables

The following environment variables are used to change the merge utility's configuration and behavior:

### SOURCE_DIR

The path fo the source directory that contains the source dashcam
recordings.  This utility will search recursively in this path for any
files matching with the following filename extension(case insensitive):

* mov
* mp4

The filename of the source files should contain a timestamp in the
`HHMMSS` fashion, files with invalid names will be skipped.

**Required:** Yes  
**Default:** N/A

### DEST_DIR

The path of the destination folder to save the merged files.  The last
timestamp of the sequence of source files will be appended to the
timestamp of the first file in sequence to generate the merged file's
filename.

**Required:** Yes  
**Default:** N/A

### RECORDING_SPLIT_MINUTES

The split duration of the recordings(in minutes).

**Default:** `5`

### DEBUG

Whether to print the message for debugging

**Supported values:** `true` | `false`  
**Default:** `false`

### DRY_RUN

Whether to print what will the program do without actually doing.

**Supported values:** `true` | `false`  
**Default:** `false`

### KEEP_SOURCE_FILES

Whether to keep the source files after merging

**Supported values:** `true` | `false`  
**Default:** `false`

## Licensing

Unless otherwise noted, this product is licensed under [the third version of the GNU General Public License](https://www.gnu.org/licenses/gpl-3.0.html),
or any of its recent versions you would prefer.

This work complies to the [REUSE Specification](https://reuse.software/spec/)
, refer [REUSE - Make licensing easy for everyone](https://reuse.software/)
for info regarding the licensing of this product.
