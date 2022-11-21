# Rakesh Lab DTI Processing Pipeline

## Background

This script was created by Pavan Anand, M.D. as a member of the Rakesh Lab at the University of Kentucky Psychiatry Department in 2022.

## Purpose

The script combine several preprocessing steps for diffusion weighted imaging data for use in tractography. The pipeline's steps are as follows:

1. Eddy current correction
2. Brain extraction (a.k.a. "skull stripping")
3. Fitting tensors to each voxel

## Usage

The script expects to work on (and indeed, assumes) a BIDS-conformant file hierarchy, though there is no strict check in place at the time of writing as to whether the target directory structure is conformant. Such a check may be added at a later stage. The reasons for this presupposition/imposition are twofold:

1. Our lab's data were structured as such for use with other BIDS-reliant applications
2. A standardized file hierarchy eases logistics of scripting (e.g., where to place the output directory or where the input files are located within the target)

### `preprocess.sh`

#### Syntax

`$ preprocess.sh [ -h | -c | -w | -s SESSION | -b SUBJECT | -p PROJECT ] OUTPUT`

Options:

* `-h`: Display help text
* `-c`: Display copyright text
* `-w`: Display warranty text
* `-s SESSION`: Initiate single session-level analysis on `SESSION`, a directory containing data from an individual session
  * "[Session](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#session)" refers to the BIDS definition of a session
* `-b SUBJECT`: Initiate single subject-level (i.e., multi-session) analysis on `SUBJECT`, a directory containing one subdirectory for each individual session of data collected for a subject
  * Must contain at least one session subdirectory
  * "[Session](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#session)" & "[subject](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject)" refer to their respective BIDS definitions
* `-p PROJECT`: Initiate project-level (i.e., multi-subject) on `PROJECT`, a directory containing one subdirectory for each subject participating in the study, each with respective subdirectories for all of a subject's session
  * Must contain at least one subject with at least one session for that subject
  * "[Session](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#session)," "[subject](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#subject)," & "[project](https://bids-standard.github.io/bids-starter-kit/folders_and_files/folders.html#project)" refer to their respective BIDS definitions

Positional parameters:

* `OUTPUT`: A name for the directory in which the temporary & permanent output data will be stored. Temporary data are deleted at the script's end. The script automatically locates the project root directory for any session, subject, or project directory passed as input data to the project. It also creates a `derivatives` directory outside the project root (within the project root's parent directory) if it doesn't exist. If `OUTPUT` does not exist within `derivatives`, it creates the directory; if it does, it uses that directory. If no name is provided for `OUTPUT`, the script generates a timestamped directory corresponding to the time & date the analyses it contains were started.

**CAUTION**: in cases in which `derivatives` exists and there is already a subdirectory of the same name passed to `OUTPUT`, the program *may* overwrite data within that subdirectory should there be a conflict of subdirectory names within `derivatives/OUTPUT`

## CHANGELOG

### v 0.1.0

`README.md`

* Initial commit

`preprocess.sh`

* Initial commit

`LICENSE`

* Initial commit
