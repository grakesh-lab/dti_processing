# DTI Processing Pipeline

## Purpose

The script combines several preprocessing steps for diffusion weighted imaging data for use in tractography. The pipeline's steps are as follows:

1. Eddy current correction
2. Brain extraction (a.k.a. "skull stripping")
3. Fitting tensors to each voxel
4. Tract-based spatial statistics
5. Skeletonization
6. Extraction of fractional anisotropy, mean diffusivity, axial diffusivity, & radial diffusivity measures

## Usage

The main script, `run_analysis.sh` expects to work on (and indeed, assumes) a BIDS-conformant file hierarchy, though there is no strict check in place at the time of writing as to whether the target directory structure is conformant. Such a check may be added at a later stage. The reasons for this presupposition/imposition are twofold:

1. Our lab's data were structured as such for use with other BIDS-reliant applications
2. A standardized file hierarchy eases logistics of scripting (e.g., where to place the output directory or where the input files are located within the target)

### Syntax

`$ run_pipeline.sh [ -h | -c | -w ] INPUT OUTPUT`

Options:

* `-h`: Display help text
* `-c`: Display copyright text
* `-w`: Display warranty text

Positional parameters:

* `INPUT`: Directory containing at least 1 session subdirectory, either a session's data or a set of sessions (i.e., a subject)
* `OUTPUT`: A name for the directory in which the temporary & permanent output data will be stored. Temporary data are deleted at the script's end. The script automatically locates the "BIDS root directory" (i.e., the parent folder of the [project](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject)) for any session, subject, or project directory passed as input data to the project. It also creates a `derivatives` & `analysis` directories outside the project root (within the project root's parent directory) if it doesn't exist. If `OUTPUT` does not exist within `derivatives` or `analysis`, it creates the respective directories; if it does, it uses that directory.

**CAUTION**: in cases in which `derivatives` and/or `analysis` exist(s) and there is already a subdirectory within either of the same name passed to `OUTPUT`, the program *may* overwrite data within that subdirectory should there be a conflict of subdirectory names within `[ derivatives | analysis ]/OUTPUT`

## Acknowledgements

This script was created by Pavan Anand, M.D. as a member of the University of Kentucky Lab for Addiction Neuromodulation in 2022.

## CHANGELOG

### version 0.5.0

* feat!: add skeletonization, modularize script
  * BREAKING CHANGE: split off TBSS & skeletonization steps into discrete files (`tbss.sh` & `skeletonize.sh`, respectively)
  * Discrete skeletonization script facilitated implementation of parallelization
