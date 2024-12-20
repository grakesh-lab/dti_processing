#!/usr/bin/env bash

# run_pipeline.sh
# ---------------
# Perform ENIGMA diffusion-weighted imaging processing protocol.

# Reference: https://youtu.be/pglMlWL8bSA?si=jcy-944upmipHYt5
# u: script stops with an error if an undefined variable is used
# o pipefail: script stops if any intermediary step returns a non-zero exit code
set -uo pipefail

# Global variables
readonly PROGRAM="$(basename "${0}")"
readonly SCRIPT_ROOT="$(dirname "${0}")"
readonly TOTAL_PROCS="$(nproc)"

# Exported globals
export SCRIPT_ROOT

# Importing libraries
source "${SCRIPT_ROOT}/lib/helpers.sh"

function print_purpose() {
  echo "
This  script  wraps  discrete  parts of the DTI pre-processing,  processing,  &
statistical analyses pipelines.  Altogether, the following steps are performed:
  1. Pre-processing
  2. Tract-based spatial statistics
  3. Skeletonization
  4. Extraction of fractional anisotropy, mean diffusivity, axial diffusivity,
     & radial diffusivity measures (WIP)

IMPORTANT: Ensure that  your data are  structured in a  BIDS-conformant manner.
           This  script  assumes that they are and might break if not.  It also
           assumes that  the tools that ENIGMA  provides for these analyses are
           located under a  directory  titled  \"enigma_tools\"  under  the  root
           BIDS directory. See \"${PROGRAM} -h\" for more info."

  return 0
}

# NOTE: variable spacing within paragraphs for STDOUT text justification
function print_help() {
  echo "
Usage:
  $ ${PROGRAM} [ -v | -h | -c | -w ] [ -p N_PROC ] INPUT OUTPUT

Options:
  -v  Print script version
  -h  Print this help message
  -c  Print copyright & acknowledgement information
  -w  Print warranty information
  -p  Number of processors to use for parallelization

      NOTE: N_PROC must be a numeric value, must be at least 1, & cannot exceed
      the number of processors available (as detected by the nproc command)

Positional arguments:
  INPUT   Directory containing at least 1 session subdirectory
  OUTPUT  Name  of  directories  within   \"derivatives\"  and  \"analysis\"  sub-
          directories of \"<BIDS_ROOT>\" to store script outputs

See README for more examples and in-depth documentation."

  return 0
}

# Default number of processors
N_PROCS=$(("$(nproc)"/2))  # Number of processors to be used (default = 1/2 available)
function set_processors() {
  local _desired_processors="${1}"

  if ! [[ "${_desired_processors}" =~ ^[0-9]+$ ]]; then
    echo -e "ERROR: the -p option requires a numeric argument."
    exit 1
  fi

  if [[ "${_desired_processors}" -le 0 ]] || [[ "${_desired_processors}" -gt "${TOTAL_PROCS}" ]]; then
    echo "ERROR: processor count must be between 1 & ${TOTAL_PROCS} for your system."
    exit 1
  fi

  # Ideally, this value would be echo'ed & used to set N_PROCS via assignment
  N_PROCS="${_desired_processors}"
  return 0
}

# Exclusive option flags
version=false
help=false
copyright=false
warranty=false

set_custom_processors=false # -p option flag
opts="vhcwp:"
while getopts "${opts}" option; do
  case ${option} in
    v) version=true;;
    h) help=true;;
    c) copyright=true;;
    w) warranty=true;;
    p) # Set number of processors to use for parallelization
      set_custom_processors=true
      desired_processors="${OPTARG}"
      ;;
    \?)
      echo -e "ERROR: invalid option. Use \"${PROGRAM} -h\" for more info."
      exit 1
      ;;
  esac
done

exclusive_opts_count=0
for opt in "${version}" "${help}" "${copyright}" "${warranty}"; do
  if [[ "${opt}" == "true" ]]; then
    ((exclusive_opts_count++))
  fi
done

shift $(("${OPTIND}" - 1))

if [[ "${exclusive_opts_count}" -gt 0 ]] && [[ "${exclusive_opts_count}" -ne 1 ]]; then
  echo "ERROR: expect exactly one of the following options at a time:
    -v  print script version text
    -h  print script help text
    -c  print script copyright text
    -w  print script warranty text"
  exit 1
elif [[ "${exclusive_opts_count}" -eq 1 ]] && [[ $# -ne 0 ]]; then
  echo "ERROR: no positional arguments should be provided after any of the following:
    -v  print script version text
    -h  print script help text
    -c  print script copyright text
    -w  print script warranty text"
  exit 1
elif [[ "${exclusive_opts_count}" -eq 0 ]] && [[ $# -ne 2 ]]; then
  echo "ERROR: expected 2 positional arguments. See \"${PROGRAM} -h\" for help."
  exit 1
elif [[ "${exclusive_opts_count}" -eq 1 ]] && [[ "${set_custom_processors}" == "true" ]]; then
  echo "ERROR: cannot set number of processors with exclusive flag."
  exit 1
fi

if [[ "${version}" == "true" ]]; then
  helpers::print_version
  exit 0
elif [[ "${help}" == "true" ]]; then
  print_purpose
  print_help
  echo "" # Inserting padding for readability
  helpers::print_example
  exit 0
elif [[ "${copyright}" == "true" ]]; then
  helpers::print_copyright
  exit 0
elif [[ "${warranty}" == "true" ]]; then
  helpers::print_warranty
  exit 0
fi

if [[ "${set_custom_processors}" == "true" ]]; then
  set_processors "${desired_processors}"
fi
readonly N_PROCS

# Aliases for positional arguments
readonly INPUT="$(realpath "${1}")"
readonly OUTPUT="${2}"

#count_subdirectories ${INPUT} "sub-*"
n=$(find "${INPUT}" -mindepth 1 -maxdepth 1 -type d -name "sub-*" | wc -l)
echo "DEBUG: found ${n} subjects in INPUT."
if [ "${n}" -eq 0 ]; then  # Trust that INPUT is a subject...
  echo "DEBUG: Starting subject-level analysis."
  bids_root="$(realpath "${INPUT}/../..")"
  # TODO: replace following line with function
  n="$(find "${INPUT}" -mindepth 1 -maxdepth 1 -type d -name "ses-*" | wc -l)"
  echo "DEBUG: found ${n} sessions in INPUT."
  if [ "${n}" -eq 0 ]; then  # ... but verify that it is
    # exit_error would be good to have...
    echo "Error: INPUT contains no session subdirectories."
    exit 1
  fi
else  # INPUT is a project
  echo "DEBUG: Starting project-level analysis."
  bids_root="$(realpath "${INPUT}/..")"
fi

if [ ! -d "${bids_root}/reference" ]; then
  echo -e "DEBUG: \"reference\" directory not found within BIDS root; creating now..."
  readonly _dti_archive_name="enigma_dti_templates"
  readonly _dti_archive_location="${bids_root}/${_dti_archive_name}"
  readonly _dti_url="http://enigma.ini.usc.edu/wp-content/uploads/2013/02/enigmaDTI.zip"
  mkdir -p "${bids_root}/reference/"{ENIGMA,JHU}
  wget -O "${_dti_archive_location}.zip" "${_dti_url}"
  unzip "${_dti_archive_location}.zip" -d "${bids_root}/reference/ENIGMA"
  rm -rf "${_dti_archive_location}.zip"
fi

if [ ! -d "${bids_root}/utils" ]; then
  echo -e "DEBUG: \"utils\" directory not found within BIDS root; creating now..."
  readonly _reference_archive_name="enigma_roi_extraction_tools"
  readonly _reference_archive_location="${bids_root}/${_reference_archive_name}"
  readonly _reference_url="http://enigma.ini.usc.edu/wp-content/uploads/2012/06/ROIextraction_info.zip"
  mkdir "${bids_root}/utils"
  wget -O "${_reference_archive_location}.zip" "${_reference_url}"
  unzip "${_reference_archive_location}.zip" -d "${bids_root}"
  rm -rf "${bids_root}/__MACOSX"
  mv "${bids_root}/ROIextraction_info" "${_reference_archive_location}"
  cp "${_reference_archive_location}/averageSubjectTracts_exe" "${bids_root}/utils/average_subject_tracts"
  cp "${_reference_archive_location}/combine_subject_tables.R" "${bids_root}/utils/combine_subject_tables.R"
  cp "${_reference_archive_location}/singleSubjROI_exe" "${bids_root}/utils/single_subject_roi"
  cp "${_reference_archive_location}/JHU-WhiteMatter-labels-1mm.nii.gz" "${bids_root}/reference/JHU/JHU_atlas.nii.gz"
  cp "${_reference_archive_location}/ENIGMA_look_up_table.txt" "${bids_root}/reference/JHU/JHU_roi_look_up_table.txt"
  rm -rf "${_reference_archive_location}.zip"
  rm -rf "${_reference_archive_location}"
fi

readonly ENIGMA_TOOLS="${bids_root}/utils"
export ENIGMA_TOOLS
readonly REFERENCE_ROOT="${bids_root}/reference"
export REFERENCE_ROOT
readonly DERIVATIVES="${bids_root}/derivatives/${OUTPUT}"
export DERIVATIVES
#create_dir ${DERIVATIVES} ${FALSE}  # Would be nice to have create_dir...
mkdir -p "${DERIVATIVES}"
echo -e "\n\nDEBUG: starting preprocessing pipeline"
find "${INPUT}" -type d -name "ses-*" \
  | parallel -j "${N_PROCS}" "${SCRIPT_ROOT}/utils/preprocess.sh" "{}" "${DERIVATIVES}"

# TODO: add option to enable saving of all intermediate/temporary files
readonly ANALYSIS="${bids_root}/analysis/${OUTPUT}"
export ANALYSIS
#create_dir "${ANALYSIS}" ${FALSE}
mkdir -p "${ANALYSIS}"
# TODO: relocate identify_file() to helpers.sh to import here
# TODO: make use of identify_file() for the following
# TODO: modify identify_file() to be compatible with above requirement
echo -e "DEBUG: moving files from \"derivatives\" into \"analysis\"."
for _file in $(find "${DERIVATIVES}" -name "*_FA.nii.gz"); do
  cp "${_file}" "${ANALYSIS}/$(echo $(basename ${_file}) | sed -r 's/_FA//g')"
done

echo -e "\n\nDEBUG: starting TBSS pipeline."
"${SCRIPT_ROOT}"/utils/tbss.sh "${ANALYSIS}"

echo -e "\n\nDEBUG: moving analyzed files into individual session subdirectories."
matches=$(find "${ANALYSIS}/FA" -maxdepth 1 -mindepth 1 -type f -name "*.nii.gz")
names=$(for result in ${matches}; do echo $(basename ${result}) | sed -r "s/_FA.*//g"; done \
  | sort \
  | uniq \
  | grep "sub-.*")
for _label in ${names}; do
  mkdir -p "${ANALYSIS}/individual/${_label}/"{stats,FA}
done

echo -e "\n\nDEBUG: starting skeletonization process."
find "${ANALYSIS}/individual" -mindepth 1 -maxdepth 1 -type d \
  | parallel -j "${N_PROCS}" "${SCRIPT_ROOT}/utils/skeletonize.sh" "{}" "${ANALYSIS}"

# Clean up individua/FA directory
echo -e "DEBUG: cleaning up analyzed file directory."
for _stats_dir in "${ANALYSIS}/individual/"*"/stats"; do
  _fa_dir="${_stats_dir%/stats}/FA"
  mv "${_stats_dir}" "${_fa_dir}"
done

for _dir in $(find "${ANALYSIS}/individual" -mindepth 1 -maxdepth 1 -type d); do
  _subject="$(basename "${_dir}")"
  _target="${_subject}_FA.nii.gz"
  mkdir -p "${_dir}/FA/origdata"
  mv "${_dir}/FA/${_target}" "${_dir}/FA/origdata"
done

for _dir in $(find "${ANALYSIS}/individual" -mindepth 1 -maxdepth 1 -type d); do
  mkdir "${_dir}/FA/intermediary"
  for _file in $(find "${_dir}/FA" -mindepth 1 -maxdepth 1 -type f); do
    mv "${_file}" "${_dir}/FA/intermediary"
  done
done

echo -e "\n\nDEBUG: starting diffusion analyses."
find "${ANALYSIS}/individual" -mindepth 1 -maxdepth 1 -type d \
  | xargs -I "{}" basename "{}" \
  | parallel -j "${N_PROCS}" "${SCRIPT_ROOT}/utils/diffusivity.sh" "{}"

echo -e "\n\nDEBUG: starting ROI analyses."
export INPUT
find "${ANALYSIS}/individual" -type f -path "*/stats/*" -name "*_masked_*_skel.nii.gz" \
  | parallel -j "${N_PROCS}" "${SCRIPT_ROOT}/utils/analyze_roi.sh" "{}"

for _measure in "MD" "AD" "RD"; do
  find "${ANALYSIS}" -path "*/${_measure}/stats*" -name "*_roi_avg.csv" | sort > "${ANALYSIS}/_data.txt"
  find "${ANALYSIS}" -path "*/${_measure}/stats*" -name "*_roi_avg.csv" | sort | xargs -I {} basename {} | cut -d "_" -f 1-2 > "${ANALYSIS}/_session.txt"
  paste -d "," "${ANALYSIS}/_session.txt" "${ANALYSIS}/_data.txt" > "${ANALYSIS}/subject_list-${_measure}.csv"
done
rm "${ANALYSIS}/_data.txt" "${ANALYSIS}/_session.txt"

for _measure in "MD" "AD" "RD"; do
  table="${INPUT}/metadata.tsv"
  subject_id_col="id"
  subject_list="${ANALYSIS}/subject_list-${_measure}.csv"
  output_filename="roi_summary-${_measure}.csv"
  n_covariates=2
  covariates="age;sex"
  n_rois="all"
  rois="all"
  R --no-save --slave --args ${table} ${subject_id_col} ${subject_list} ${output_filename} ${n_covariates} ${covariates} ${n_rois} ${rois} < "${bids_root}/utils/combine_subject_tables.R"
done

exit 0
