# DTI Processing Pipeline

## Status

This script has been finished enough to run [the ENIGMA DTI protocols](https://enigma.ini.usc.edu/protocols/dti-protocols/) (with minor modifications as per our lab's data and needs) until the analysis of MD, AD, and RD values. The derivation and analyses of those data were performed via one-off Bash commands and work is being done on a feature branch to implement those commands into the script to execute the entire pipeline in an automated manner. That code will be merged with this main branch when it is ready, but until then, the main branch's code should suffice for taking data through a majority of the ENIGMA DTI protocol pipeline, while the rest of the steps can be performed according to the materials presented by the ENIGMA Consortium on their website (see earlier link).

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

`$ run_pipeline.sh [ -v | -h | -c | -w ] [ -p N_PROCS ] INPUT OUTPUT`

Options:

* `-v`: Display script version; exclusive
* `-h`: Display help text; exclusive
* `-c`: Display copyright text; exclusive
* `-w`: Display warranty text; exclusive
* `-p N_PROCS`: Set number of processors to use for parallelization
  * `N_PROCS` must be a number between 1 & the maximum number of cores in a system, as determined by the `nproc` command

NOTE: options identified as "exclusive" cannot be chained with any other options, whether those other options are exclusive themselves or not.

Positional parameters:

* `INPUT`: Directory containing at least 1 session subdirectory, either a session's data or a set of sessions (i.e., a subject)
* `OUTPUT`: A name for the directory in which the temporary & permanent output data will be stored. Temporary data are deleted at the script's end. The script automatically locates the "BIDS root directory" (i.e., the parent folder of the [project](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject)) for any session, subject, or project directory passed as input data to the project. It also creates a `derivatives` & `analysis` directories outside the project root (within the project root's parent directory) if it doesn't exist. If `OUTPUT` does not exist within `derivatives` or `analysis`, it creates the respective directories; if it does, it uses that directory.

**CAUTION**: in cases in which `derivatives` and/or `analysis` exist(s) and there is already a subdirectory within either of the same name passed to `OUTPUT`, the program *may* overwrite data within that subdirectory should there be a conflict of subdirectory names within `[ derivatives | analysis ]/OUTPUT`

## Acknowledgements

This script was initially created by Pavan Anand, M.D. as a member of the University of Kentucky Lab for Addiction Neuromodulation in 2022-23 and is based on [the work of the ENIGMA Consortium](https://enigma.ini.usc.edu/about-2/). Work has continued throughout 2024 after having left the lab.

## CHANGELOG

### version 0.8.1

This version represents a functional, stable, presentable, product for production use and is ready for others to test the whole DTI processing pipeline end-to-end. Huzzah! 🎉

Any remaining changes between stock ENIGMA files that were changed in any way to complete this project will be outlined in either a wiki in this GitHub repository or in this README file.
