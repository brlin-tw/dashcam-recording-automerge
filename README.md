# Dashcam recording automerge utility

Automatic merging dashcam recordings that are named in a specific fashion

![GitHub Actions workflow status badge](https://github.com/brlin-tw/dashcam-recording-automerge/actions/workflows/check-potential-problems.yml/badge.svg "GitHub Actions workflow status") [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/github.com/brlin-tw/dashcam-recording-automerge "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/github.com/brlin-tw/dashcam-recording-automerge)

## Dependencies

This utility requires the following software to be installed and its
program to be in the system's command search PATHs:

* [Bash](https://www.gnu.org/software/bash/)(>=4.3)
* [ffmpeg-cat](https://github.com/brlin-tw/ffmpeg-cat)
* [GNU Core Utilities(Coreutils)](https://www.gnu.org/software/coreutils/)
* [Grep](https://www.gnu.org/software/grep/)

Note that the dependencies of the dependencies(e.g. FFmpeg) must be
satisfied, as well.

This software is specifically tested in Ubuntu GNU+Linux operating
system, however it should work in any similar environments as well.

## Licensing

Unless otherwise noted, this product is licensed under [the third version of the GNU General Public License](https://www.gnu.org/licenses/gpl-3.0.html),
or any of its recent versions you would prefer.

This work complies to the [REUSE Specification](https://reuse.software/spec/)
, refer [REUSE - Make licensing easy for everyone](https://reuse.software/)
for info regarding the licensing of this product.
