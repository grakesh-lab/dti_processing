#!/usr/bin/env bash
#
# Perform diffusion-weighted imaging preprocessing pipeline.
#
# Depends on GNU Parallel, realpath, & dc (for tbss_1_preproc)
# TODO: add check for coreutils/realpath, dc, & parallel programs
# TODO: add OS & program version checks to ensure thaat script will run

# Credit: The Mouseless Dev on YouTube (https://youtu.be/pglMlWL8bSA?si=jcy-944upmipHYt5)
# e: script stops when an error is encountered (i.e., non-zero exit code)
# u: script stops with an error if an undefined variable is used
# o pipefail: script stops if any intermediary step returns a non-zero exit code
# x: output each line (helpful for debugging)
# FIX: set -e causes the script to fail on Linux with Bash 5.0.17
#set -euo pipefail
set -uo pipefail

# Global variables
readonly PROGRAM=$(basename $0)
readonly SCRIPT_ROOT=$(dirname $0)
readonly TOTAL_PROCS=$(nproc)

# Exported globals
export SCRIPT_ROOT

# Importing libraries
source "${SCRIPT_ROOT}/lib/helpers.sh"

n=0  # Generic counter variable
n_procs=$(($(nproc)/2))  # Number of processors to be used (default = 1/2 available)

print_purpose() {
  echo "
This  script  wraps  discrete  parts of the DTI pre-processing,  processing,  &
statistical analyses pipelines.  Altogether, the following steps are performed:
  1. Pre-processing
  2. Tract-based spatial statistics
  3. Skeletonization
  4. Extraction of fractional anisotropy, mean diffusivity, axial diffusivity,
     & radial diffusivity measures

IMPORTANT: Ensure that  your data are  structured in a  BIDS-conformant manner.
           This  script  assumes that they are and might break if not.  It also
           assumes that  the tools that ENIGMA  provides for these analyses are
           located under a  directory  titled  \"enigma_tools\"  under  the  root
           BIDS directory. See \"${PROGRAM} -h\" for more info."
}

# NOTE: weird spacing within paragraphs for STDOUT text justification
# Text may exceed 80 char/line in code to account for special characters when
# targetting 80-character terminal output.
print_help() {
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

Example usage:
  $ ${PROGRAM} ~/data/flanker/sub-01 flanker_analysis

This  will run an analysis on all  sessions for subject  1  within the  \"flanker\"
project.  <BIDS_ROOT>,  in  this  case,  is  \"~/data\",  as  it houses the project
directory  (i.e.,  \"~/data/flanker\")  on  which the  analysis is to be performed.
The component scripts  will search  for  (and create, if absent)  a \"derivatives\"
&  an \"analysis\"  sub-directory under  <BIDS_ROOT>, inside which they will create
a \"flanker_analysis\" sub-directory.

Altogether, this example's outputs would be stored under:

  * \"~/data/derivatives/flanker_analysis\"
  * \"~/data/analysis/flanker_analysis\"
"

# TODO: add examples & more in-depth documentation to README
# TODO: uncomment following line when examples/extra info added to README
# See README for more examples and in-depth documentation."
}

# Alas! Associative arrays are a product of Bash 4.0, which does not
# ship with macOS by default. To ensure my machine doesn't break, I
# will not be updating macOS's shipped version and therefore have to
# redesign this implementation to work with Bash 3.2 instead.
# TODO: decide whether Bash 4.0 should be our minimum target
# declare -A exclusive_opts=(
#  [version]=false
#  [help]=false
#  [copyright]=false
#  [warranty]=false
# )
version=false
help=false
copyright=false
warranty=false

# TODO: implement verbose option without conflicting with version option
opts=":vhcwp:"
while getopts "${opts}" option; do
  case ${option} in
    v) # Print version
      # exclusive_opts[version]=true # Uncomment if using associative arrays
      version=true # Comment if using associative arrays
      ;;
    h) # Print purpose & help
      # exclusive_opts[help]=true # Uncomment if using associative arrays
      help=true # Comment if using associative arrays
      ;;
    c) # Print copyright
      # exclusive_opts[copyright]=true # Uncomment if using associative arrays
      copyright=true # Comment if using associative arrays
      ;;
    w) # Print warranty
      # exclusive_opts[warranty]=true # Uncomment if using associative arrays
      warranty=true # Comment if using associative arrays
      ;;
    p)
      if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        echo -e "\nError: the -p option requires a numeric argument.\n"
        exit 1
      fi

      if [[ "${OPTARG}" -le 0 ]] || [[ "${OPTARG}" -gt $TOTAL_PROCS ]]; then
        echo -e "
Error: processor count must be between 1 & $TOTAL_PROCS for your system.\n"
        exit 1
      fi

      n_procs="${OPTARG}"
      ;;
    \?)
      echo -e "\nError: invalid option. Use \"${PROGRAM} -h\" for more info.\n"
      exit 1
      ;;
  esac
done

exclusive_opts_count=0
# Uncomment the following block if using associative arrays
# for opt in "${!exclusive_opts}"; do
#  if [[ "${exclusive_opts[$opt]}" == "true" ]]; then ((exclusive_opts_count++)); fi
# done
# Uncomment the following block if not using associative arrays
for opt in "$version" "$help" "$copyright" "$warranty"; do
  if [[ "$opt" == "true" ]]; then
    ((exclusive_opts_count++))
  fi
done

shift $((${OPTIND} - 1))  # TODO: test what happens if no opts given

if [[ $exclusive_opts_count -gt 0 ]] && [[ $exclusive_opts_count -ne 1 ]]; then
  echo "
Error: expect exactly one of the following options at a time:
    -v  print script version text
    -h  print script help text
    -c  print script copyright text
    -w  print script warranty text
"
  exit 1
elif [[ $exclusive_opts_count -eq 1 ]] && [[ $# -ne 0 ]]; then
  echo "
Error: no positional arguments should be provided after any of the following:
    -v  print script version text
    -h  print script help text
    -c  print script copyright text
    -w  print script warranty text
"
  exit 1
elif [[ $exclusive_opts_count -eq 0 ]] && [[ $# -ne 2 ]]; then
  echo -e "
Error: expected 2 positional arguemnts. See \"${PROGRAM} -h\" for help.
"
  exit 1
fi

# Uncomment this block if using associative arrays
# if [[ "${exclusive_opts[version]}" == "true" ]]; then
#   helpers::print_version
#   exit 0
# elif [[ "${exclusive_opts[help]}" == "true" ]]; then
#   print_purpose
#   print_help
#   exit 0
# elif [[ "${exclusive_opts[copyright]}" == "true" ]]; then
#   helpers::print_copyright
#   exit 0
# elif [[ "${exclusive_opts[warranty]}" == "true" ]]; then
#   helpers::print_warranty
#   exit 0
# fi
if [[ "$version" == "true" ]]; then
  helpers::print_version
  exit 0
elif [[ "$help" == "true" ]]; then
  print_purpose
  print_help
  exit 0
elif [[ "$copyright" == "true" ]]; then
  helpers::print_copyright
  exit 0
elif [[ "$warranty" == "true" ]]; then
  helpers::print_warranty
  exit 0
fi

# Aliases for positional arguments
readonly INPUT=$(realpath $1)
readonly OUTPUT=$2

# TODO: function-ize following logic
#count_subdirectories ${INPUT} "sub-*"
n=$(find ${INPUT} -mindepth 1 -maxdepth 1 -type d -name "sub-*" | wc -l)
echo "DEBUG: found ${n} subjects in INPUT."
if [ ${n} -eq 0 ]; then  # Trust that INPUT is a subject...
  echo "DEBUG: Starting subject-level analysis."
  bids_root=$(realpath ${INPUT}/../..)
  # TODO: replace following line with function
  n=$(find ${INPUT} -mindepth 1 -maxdepth 1 -type d -name "ses-*" | wc -l)
  echo "DEBUG: found ${n} sessions in INPUT."
  if [ ${n} -eq 0 ]; then  # ... but verify that it is
    # exit_error would be good to have...
    echo "Error: INPUT contians no session subdirectories."
    exit 1
  fi
else  # INPUT is a project
  echo "DEBUG: Starting project-level analysis."
  bids_root=$(realpath ${INPUT}/..)
fi

readonly ENIGMA_ROOT="${bids_root}/enigma_tools"
export ENIGMA_ROOT
readonly DERIVATIVES="${bids_root}/derivatives/${OUTPUT}"
#create_dir ${DERIVATIVES} ${FALSE}  # Would be nice to have create_dir...
mkdir -p ${DERIVATIVES}
find ${INPUT} -type d -name "ses-*" \
  | parallel -j ${n_procs} "${SCRIPT_ROOT}/utils/preprocess.sh" {} ${DERIVATIVES}

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
${SCRIPT_ROOT}/utils/tbss.sh ${ANALYSIS}

matches=$(find ${ANALYSIS}/FA -maxdepth 1 -mindepth 1 -type f -name "*.nii.gz")
names=$(for result in ${matches}; do echo "$(basename ${result})" | sed -r "s/_FA.*//g"; done \
  | sort \
  | uniq \
  | grep "sub-.*")
for label in ${names}; do
  mkdir -p "${ANALYSIS}/individual/${label}/"{stats,FA}
done

find ${ANALYSIS}/individual -mindepth 1 -maxdepth 1 -type d \
  | parallel -j ${n_procs} "${SCRIPT_ROOT}/utils/skeletonize.sh" {} ${ANALYSIS}

find ${ANALYSIS}/individual -mindepth 1 -maxdepth 1 -type d \
  | parallel -j ${n_procs} "${SCRIPT_ROOT}/utils/analyze_roi.sh" {} ${ANALYSIS}
