#!/usr/bin/env bash
#
# Perform diffusion-weighted imaging preprocessing pipeline.

# Adding boolean logic aliases
readonly TRUE=1
readonly FALSE=0

readonly PROGRAM="$(basename $0)"

if [ ! -z PROJECT_ROOT ]; then  # $PROJECT_ROOT set in run_pipeline.sh
  source "${PROJECT_ROOT}/helpers.sh"
else
  # TODO: handle calling script independent of run_pipeline.sh
  echo "ERROR: \"PROJECT_ROOT\" not set"
  exit 1
fi

print_purpose() {
  echo "
This script carries out the following steps for preprocessing DWI data:
  1. Eddy current correction
  2. Brain extraction (a.k.a. \"skull stripping\")
  3. Fitting tensors to each voxel

IMPORTANT: Ensure that your data are structured in a BIDS-conformant manner.
           This script assumes that they are and might break if not."
}

print_help() {
  echo "
Usage:
  $ ${PROGRAM} [ -h | -c | -w ] INPUT OUTPUT

Options:
  h  Print this help message and exit
  c  Print copyright & acknowledgement information
  w  Print warranty information

Positional arguments:
  INPUT   Directory containing at least 1 subdirectory containing session data
  OUTPUT  Name of directories within \"<BIDS_ROOT>/derivatives\" and
          \"<BIDS_ROOT>/analysis\" used to store script outputs

Example usage:
  $ ${PROGRAM} ~/data/flanker/sub-01/ses-01 flanker_analysis

This will run an analysis on session  1  for  subject  1  within the  \"flanker\"
project.  <BIDS_ROOT>, in this  case,  is  \"~/data\",  as  it houses the project
directory (i.e., \"~/data/flanker\") on which the analysis is to be performed. It
will  search  for  (and create, if absent)  a \"derivatives\" sub-directory under
<BIDS_ROOT>, inside which it will create the \"flanker_analysis\" sub-directory.

Outputs from this example would be stored under:

  * \"~/data/derivatives/flanker_analysis\"
"  # NOTE: weird spacing within paragraphs for STDOUT text justification
  
# TODO: add examples & more in-depth documentation to README
# TODO: uncomment following line when examples/extra info added to README
# See README for more examples and in-depth documentation."

exit 1
}

exit_error() {  # TODO: relocate to helpers.sh
  #######################################
  # Exit program after printing custom error message
  # Arguments:
  #   $1: Custom error message, a string
  # Outputs:
  #  Writes error message to STDOUT
  #######################################
  echo "Error: $1"  # TODO: consider printing to STDERR (+/- STDOUT)
  exit 1  # TODO: allow use of different exit codes
}

create_dir(){  # TODO: relocate to helpers.sh
  #######################################
  # Create a directory; optionally, exit if it already exists
  # Arguments:
  #   $1: Name of directory to be created, a string
  #   $2: Whether to exit if "$1" already exists, an integer
  # Outputs:
  #   Prints debug message if directory does not exist
  #######################################
  if [ ! -d "${1}" ]; then
    echo "DEBUG: \"${1}\" does not exist; creating now..."
    mkdir -p $1
  else
    if [[ $2 -eq 1 ]]; then
      exit_error "specified directory \"${1}\" already exists"
    else
      :
    fi
  fi
}

identify_file(){  # TODO: relocate to helpers.sh
  #######################################
  # Save path of a file to a global variable
  # Globals:
  #   selected_file: defined
  # Arguments:
  #   $1: Top-level directory for file search execution
  #   $2: File name pattern to match, a string
  # Outputs:
  #   Prints information about pattern match status to STDOUT
  #######################################
  local -r _scope="$1"
  local -r _pattern="$2"
  # TODO: rewrite match count logic to match main logic (i.e., using wc -l)
  IFS=$'\n'; local _matches=$(find ${_scope} -name ${_pattern}); unset IFS
  local -r _match_count="${#_matches[@]}"
  if [ ${_match_count} -gt 1 ]; then
    # TODO: consider passing & handling a warning instead of an error
    # NOTE: "handling" this case would mean selecting the largest file out of
    #       the match results, which mirrors what we have been doing manually
    exit_error "more than 1 file matches pattern \"${_pattern}\""
  elif [ ${_match_count} -eq 1 ]; then
    echo "DEBUG: file matched is ${_matches[0]}."
    selected_file="${_matches[0]}"  # TODO: use JSON to pass value (e.g., `jq`)
    # NOTE: using  `jq`  would allow non-integer "returns,"  avoiding confusing
    #       cases of global variable  creation within  a function  (as in here)
    # NOTE: otherwise,  consider  rudimentary  "echo-as-return"  functionality,
    #       which  could  replace  ${eddy_output} & ${bet_output} constructors,
    #       meaning  their  respective  functions  could  be  merged  back into
    #       analyze_session()
  else
    exit_error "no files matched pattern \"${_pattern}\""
  fi
}

eddy_correction(){  # TODO: minimize creation of extraneous functions
  #######################################
  # Perform eddy current correction
  # Globals:
  #   tmp_dir:       used
  #   eddy_output:   defined
  # Arguments:
  #   $1: Input, an .nii file
  #   $2: Output file prefix, a string
  # Outputs:
  #   Prints script status update to STDOUT
  #######################################
  echo "Correcting for eddy currents within $1..."
  # WARN: does *not* like spaces anywhere in file path arguments!
  # TODO: redefine tmp_dir as global, rename to all-caps to signify
  # WARN: Using local, readonly variable ($tmp_dir) in separate function...
  eddy_output="${tmp_dir}/${2}_eddy_corrected"
  eddy_correct "$1" ${eddy_output} 0
}

brain_extraction(){  # TODO: minimize creation of extraneous functions
  #######################################
  # Skull strip the input image
  # Globals:
  #   tmp_dir:       used
  #   file_basename: used
  #   bet_output:    defined
  # Arguments:
  #   $1: Input, an .nii file
  #   $2: Output file prefix, a string
  # Outputs:
  #   Prints script status update to STDOUT
  #######################################
  echo "Extracting binary brain mask..."
  # TODO: investigate feasibility of using `bet2` instead
  # TODO: redefine tmp_dir as global, rename to all-caps to signify
  # WARN: Using local, readonly variable ($tmp_dir) in separate function...
  bet_output="${tmp_dir}/${2}_${file_basename}"
  bet "$1" ${bet_output} -F -f .3
}

analyze_session() {
  #######################################
  # Conduct analysis of an individual session's data
  # Globals:
  #   tmp_dir:       defined
  #   file_basename: defined
  #   selected_file: used
  #   eddy_output:   used
  #   bet_output:    used
  # Arguments:
  #   $1: Directory containing at only one "dwi" subdirectory
  # Outputs:
  #   Prints script status update to STDOUT
  #######################################
  local -r _session=$1

  if [ -d ${_session} ]; then
    echo "DEBUG: analyzing \"${_session}\"..."
    cd ${_session}
  else
    exit_error "please pass a (existing) directory to the script"
  fi

  if [ ! -d "${_session}/dwi" ]; then
    exit_error "no \"dwi\" subdirectory present

This script expects a BIDS-formatted directory as input
(i.e., the parent of the \"dwi\" directory). Please reformat
the current directory to comply with the BIDS specification or
point the script to an existing BIDS-compliant directory."
  fi

  # subject: $(basename $(dirname $(pwd)))
  # session: $(basename $(pwd))
  local -r _prefix="$(basename $(dirname $(pwd)))_$(basename $(pwd))"
  local -r _session_outputs="${OUTPUT}/${_prefix}"
  readonly tmp_dir="${_session_outputs}/tmp"  # TODO: make $tmp_dir local

  create_dir ${_session_outputs} ${TRUE}
  create_dir ${tmp_dir} ${FALSE}

  readonly file_basename="brain"  # TODO: make $file_basename local

  identify_file "${_session}/dwi" "*.nii.gz"
  echo "Unzipping ${selected_file} to ${tmp_dir}..."
  local _filename="${_prefix}_${file_basename}.nii"
  gunzip < "${selected_file}" > "${tmp_dir}/${_filename}"

  # Correct eddy currents
  eddy_correction "${tmp_dir}/${_filename}" "${_prefix}"

  # Skull strip eddy-corrected images
  brain_extraction "${eddy_output}" "${_prefix}"

  # Cleanup unneeded intermediary files
  rm "${bet_output}.nii.gz"
  mv "${bet_output}_mask.nii.gz" \
     "${bet_output}_mask-nodif.nii.gz"

  # Select first image in temporal sequence of eddy-corrected scan
  echo "Splitting eddy-corrected scan into snapshots..."
  fslsplit "${eddy_output}" "${tmp_dir}/split" -t
  mv "${tmp_dir}/split0000.nii.gz" "${bet_output}-nodif.nii.gz"

  # Run dtifit
  echo "Fitting diffusion tensor model at each voxel..."
  local -r _bval="$(find ${_session} -name "*.bval")"
  local -r _bvec="$(find ${_session} -name "*.bvec")"
  dtifit \
    -k "${eddy_output}" \
    -m "${bet_output}_mask-nodif.nii.gz" \
    -o "${_session_outputs}/${_prefix}" \
    -r "${_bvec}" \
    -b "${_bval}"

  # Cleanup remaining temporary/intermediary files
  rm -rf "${tmp_dir}"
}

opts="hcw"  # TODO: add -v/--verbose option
while getopts ${opts} option; do
  case ${option} in
    h) print_purpose && print_help ;;
    c) helpers::print_copyright ;;
    w) helpers::print_warranty ;;
    \?) print_help ;;
  esac
done

shift $((${OPTIND} - 1))  # TODO: test what happens if no opts given

# Aliases for positional arguments
readonly INPUT=$(realpath $1)
readonly OUTPUT=$2

# TODO: create main() & call that here instead
analyze_session ${INPUT} ${OUTPUT}
