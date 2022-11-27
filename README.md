# DTI Processing Pipeline

## Purpose

The script combine several preprocessing steps for diffusion weighted imaging data for use in tractography. The pipeline's steps are as follows:

1. Eddy current correction
2. Brain extraction (a.k.a. "skull stripping")
3. Fitting tensors to each voxel
4. Tract-based spatial statistics

## Usage

The script expects to work on (and indeed, assumes) a BIDS-conformant file hierarchy, though there is no strict check in place at the time of writing as to whether the target directory structure is conformant. Such a check may be added at a later stage. The reasons for this presupposition/imposition are twofold:

1. Our lab's data were structured as such for use with other BIDS-reliant applications
2. A standardized file hierarchy eases logistics of scripting (e.g., where to place the output directory or where the input files are located within the target)

### Syntax

`$ preprocess.sh [ -h | -c | -w ] MODE INPUT OUTPUT`

Options:

* `-h`: Display help text
* `-c`: Display copyright text
* `-w`: Display warranty text

Positional parameters:

* `MODE`: Specify which mode the program should run in. There are 3 acceptable values to pass here: [`session`](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#session), [`subject`](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject), or [`project`](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#project). Each of these terms refer to their respective BIDS definitions (see hyperlinks for each term).
  * `session`: Analyze single session
  * `subject`: Analyze all sessions of a single subject
  * `project`: Analyze all sessions of all subjects
* `INPUT`: Directory containing input data for chosen `MODE`
* `OUTPUT`: A name for the directory in which the temporary & permanent output data will be stored. Temporary data are deleted at the script's end. The script automatically locates the "BIDS root directory" (i.e., the parent folder of the [project](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject)) for any session, subject, or project directory passed as input data to the project. It also creates a `derivatives` & `analysis` directories outside the project root (within the project root's parent directory) if it doesn't exist. If `OUTPUT` does not exist within `derivatives`, it creates the directory; if it does, it uses that directory.

**CAUTION**: in cases in which `derivatives` and/or `analysis` exist(s) and there is already a subdirectory within either of the same name passed to `OUTPUT`, the program *may* overwrite data within that subdirectory should there be a conflict of subdirectory names within `[derivatives | analysis]/OUTPUT`

## Acknowledgements

This script was created by Pavan Anand, M.D. as a member of the University of Kentucky Lab for Addiction Neuromodulation in 2022.

## CHANGELOG

### version 0.3.0

* feat!: updated interface; split output directories
  * BREAKING CHANGE: there are now 3 positional arguments for the script: 1) $MODE, 2) $INPUT, & 3) $OUTPUT.
  * BREAKING CHANGE: $OUTPUT_PARENT deprecated, use $DERIVATIVES & $ANALYSIS instead.
  * Overhauled script help output to reflect new interface.
  * Outputs from the script have been separated: derivatives from the pre-processing steps (i.e., steps 1-3) are still stored under "derivatives" (location defined by $DERIVATIVES) but data derived from analysis of the derivatives (i.e., step 4) are now stored under "analysis" (location defined by $ANALYSIS).
