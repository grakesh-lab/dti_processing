#!/usr/bin/env bash
#
# Perform diffusion-weighted imaging preprocessing pipeline.
#
# Depends on GNU Parallel, realpath, & dc (for tbss_1_preproc)
# TODO: add check for coreutils/realpath, dc, & parallel programs
# TODO: add OS & program version checks to ensure thaat script will run

# Global variables
readonly PROGRAM=$(basename $0)
readonly PROJECT_ROOT=$(dirname $0)
readonly ENIGMA_ROOT="/home/pavan/share/enigma"
readonly CORES=6

# Exported globals
export PROJECT_ROOT
export ENIGMA_ROOT

# Importing libraries
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
  | parallel -j ${CORES} "${PROJECT_ROOT}/utils/preprocess.sh" {} ${DERIVATIVES}
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

# TODO: add more "DEBUG" outputs & documenting comments
${PROJECT_ROOT}/utils/tbss.sh ${ANALYSIS}

matches=$(find ${ANALYSIS}/FA -maxdepth 1 -mindepth 1 -type f -name "*.nii.gz")
names=$(for result in ${matches}; do echo "$(basename ${result})" | sed -r "s/_FA.*//g"; done \
  | sort \
  | uniq \
  | grep "sub-.*")
for label in ${names}; do
  mkdir -p "${ANALYSIS}/individual/${label}/"{stats,FA}
done

find ${ANALYSIS}/individual -mindepth 1 -maxdepth 1 -type d \
  | parallel -j ${CORES} "${PROJECT_ROOT}/utils/skeletonize.sh" {} ${ANALYSIS}

find ${ANALYSIS}/individual -mindepth 1 -maxdepth 1 -type d \
  | parallel -j ${CORES} "${PROJECT_ROOT}/utils/analyze_roi.sh" {} ${ANALYSIS}

echo "DEBUG: starting diffusion analyses."
# MD/AD/RD analyses
for individual in $(find ${ANALYSIS}/individual -mindepth 1 -maxdepth 1 -type d); do
  mkdir -p ${individual}/{MD,AD,RD}/{origdata,stats,intermediary}
  readonly MD_ROOT=${individual}/MD
  readonly AD_ROOT=${individual}/AD
  readonly RD_ROOT=${individual}/RD
  for file in $(find ${DERIVATIVES}/$(basename ${individual}) -mindepth 1 -type f -name "*_MD.nii.gz"); do
    cp ${file} ${MD_ROOT}/origdata/"$(basename ${file})"
  done
  for file in $(find ${DERIVATIVES}/$(basename ${individual}) -mindepth 1 -type f -name "*_L1.nii.gz"); do
    cp ${file} ${AD_ROOT}/origdata/"$(basename ${file} | sed 's/_L1/_AD/g')"
  done
  for study in $(find ${DERIVATIVES}/$(basename ${individual}) -mindepth 1 -type d -regex ".*/derivatives/.*/sub-.*"); do
    fslmaths ${study}/*_L2.nii.gz -add ${study}/*_L3.nii.gz -div 2 ${RD_ROOT}/origdata/$(basename ${study})_RD.nii.gz
  done
  for diff_root in MD_ROOT AD_ROOT RD_ROOT; do
    for file in $(find ${diff_root}/origdata -type f -name "*_$(basename ${diff_root}).nii.gz"); do
      fslmaths ${file} \
        -mas "${individual}/FA/$(basename ${individual})_FA_mask.nii.gz" \
        "${diff_root}/intermediary/$(basename ${file})"
    done
    for file in $(find ${individual}/intermediary -type f -name "*_$(basename ${diff_root}).nii.gz"); do
      applywarp \
        -i ${file} \
        -o ${diff_root}/intermediary/$(basename ${file})_to_target.nii.gz \
        -r ${FSLDIR}/data/standard/FMRIB58_FA_1mm \
        -w ${individual}/FA/$(basename ${individual})_FA_to_target_warp.nii.gz
    done
    for file in $(find ${individual}/intermediary -type f -name "*_to_target.nii.gz"); do
      fslmaths ${file} \
        -mas "${ENIGMA_ROOT}/ENIGMA_DTI_FA_mask.nii.gz" \
        "${diff_root}/intermediary/$(basename ${individual})_masked_$(basename ${diff_root}).nii.gz"
    done
    for file in $(find ${diff_root}/intermediary -type f -name "*_masked_*.nii.gz"); do
      tbss_skeleton \
        -i ${ENIGMA_ROOT}/ENIGMA_DTI_FA.nii.gz \
        -p 0.049 \
        ${ENIGMA_ROOT}/ENIGMA_DTI_FA_skeleton_mask_dst.nii.gz \
        ${FSLDIR}/data/standard/LowerCingulum_1mm.nii.gz \
        ${individual}/FA/$(basename ${individual})_masked_FA.nii.gz \
        ${diff_root}/stats/$(basename ${individual})_masked_$(basename ${diff_root})_skel.nii.gz \
        -a ${diff_root}/intermediary/$(basename ${individual})_masked_$(basename ${diff_root}).nii.gz \
        -s ${ENIGMA_ROOT}/ENIGMA_DTI_FA_mask.nii.gz
    done
  done
done
