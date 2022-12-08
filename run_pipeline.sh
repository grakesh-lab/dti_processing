#!/usr/bin/env bash
#
# Perform diffusion-weighted imaging preprocessing pipeline.
#
# Depends on GNU Parallel, realpath, & dc (for tbss_1_preproc)
# TODO: add check for coreutils/realpath, dc, & parallel programs
# TODO: add OS & program version checks to ensure thaat script will run

readonly PROGRAM=$(basename $0)
readonly PROJECT_ROOT=$(dirname $0)
export PROJECT_ROOT

source "${PROJECT_ROOT}/lib/helpers.sh"

N=0  # Counter variable

print_purpose() {
  echo "
This  script  wraps  discrete  parts of the DTI pre-processing,  processing,  &
statistical analyses pipelines.  Altogether, the following steps are performed:
  1. Pre-processing
  2. Tract-based spatial statistics
  3. Skeletonization
  4. Extraction of fractional anisotropy, mean diffusivity, axial diffusivity,
     & radial diffusivity measures 

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
  INPUT   Directory containing at least 1 session subdirectory
  OUTPUT  Name of directories within \"<BIDS_ROOT>/derivatives\" and
          \"<BIDS_ROOT>/analysis\" used to store script outputs

Example usage:
  $ ${PROGRAM} ~/data/flanker/sub-01 flanker_analysis

This will run an analysis on all sessions for subject  1  within the  \"flanker\"
project.  <BIDS_ROOT>, in this  case,  is  \"~/data\",  as  it houses the project
directory  (i.e.,  \"~/data/flanker\")  on which the analysis is to be performed.
The component scripts will search for  (and create, if absent)  a \"derivatives\"
&  an \"analysis\" sub-directory under <BIDS_ROOT>, inside which they will create
a \"flanker_analysis\" sub-directory.

Altogether, this example's outputs would be stored under:

  * \"~/data/derivatives/flanker_analysis\"
  * \"~/data/analysis/flanker_analysis\"
"  # NOTE: weird spacing within paragraphs for STDOUT text justification
  
# TODO: add examples & more in-depth documentation to README
# TODO: uncomment following line when examples/extra info added to README
# See README for more examples and in-depth documentation."

exit 1
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

# TODO: function-ize following logic
#count_subdirectories ${INPUT} "sub-*"
N=$(find ${INPUT} -mindepth 1 -maxdepth 1 -type d -name "sub-*" | wc -l)
echo "DEBUG: found ${N} subjects in INPUT."
if [ ${N} -eq 0 ]; then  # Trust that INPUT is a subject...
  echo "DEBUG: Starting subject-level analysis."
  bids_root=$(realpath ${INPUT}/../..)
  # TODO: replace following line with function
  N=$(find ${INPUT} -mindepth 1 -maxdepth 1 -type d -name "ses-*" | wc -l)
  echo "DEBUG: found ${N} sessions in INPUT."
  if [ ${N} -eq 0 ]; then  # ... but verify that it is
    # exit_error would be good to have...
    echo "Error: INPUT contians no session subdirectories."
    exit 1
  fi
else  # INPUT is a project
  echo "DEBUG: Starting project-level analysis."
  bids_root=$(realpath ${INPUT}/..)
fi

readonly DERIVATIVES="${bids_root}/derivatives/${OUTPUT}"
#create_dir ${DERIVATIVES} ${FALSE}  # Would be nice to have create_dir...
mkdir -p ${DERIVATIVES}
find ${INPUT} -type d -name "ses-*" \
  | parallel -j 4 "${PROJECT_ROOT}/utils/preprocess.sh" {} ${DERIVATIVES}
# TODO: add option to specify how many cores to use

# TODO: add option to disable TBSS
# TODO: add option to enable saving of all intermediate/temporary files
readonly ANALYSIS="${bids_root}/analysis/${OUTPUT}"
#create_dir "${ANALYSIS}" ${FALSE}
mkdir -p ${ANALYSIS}
# TODO: relocate identify_file() to helpers.sh to import here
# TODO: make use of identify_file() for the following
# TODO: modify identify_file() to be compatible with above requirement
for file in $(find "${DERIVATIVES}" -name "*_FA.nii.gz"); do
  cp "${file}" "${ANALYSIS}/$(echo $(basename ${file}) | sed -r 's/_FA//g')"
done

cd ${ANALYSIS}
readonly ENIGMA="${bids_root}/enigma"
tbss_1_preproc *.nii.gz  # Produces FA mask
tbss_2_reg -t ${ENIGMA}/ENIGMA_DTI_FA.nii.gz  # Registered to ENIGMA target
tbss_3_postreg -S  # Produces mean/all FA, mean FA mask, & mean FA skeleton
