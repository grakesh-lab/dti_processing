#!/usr/bin/env bash
#
# Perform diffusion-weighted imaging preprocessing pipeline
#
# NOTE: Depends upon package "coreutils" for command "realpath"
#   $ brew install coreutils

readonly VERSION="0.2.0"
readonly PROGRAM="$(basename $0)"
readonly AUTHORS="Pavan A. Anand"
readonly COPYRIGHT_YEARS="2022"

readonly TRUE=1 YES=1 NO=0 FALSE=0
readonly START_TIME="$(date +"%Y-%m-%d_%H.%M.%S")"

print_purpose() {
    echo "
This script carries out the following steps for preprocessing DWI data:
    1. Eddy current correction
    2. Brain extraction (a.k.a. \"skull stripping\")
    3. Fitting tensors to each voxel
    4. Tract-based spatial statistics

IMPORTANT: Ensure that your data are structured in a BIDS-conformant manner.
           This script assumes that they are and might break if not."
}

print_help() {
    echo "
Usage:
    $ ${PROGRAM} [ -h | -c | -w | -s SESSION | -b SUBJECT | -p PROJECT ] OUTPUT

Options:
    h    Print this help message and exit
    c    Print copyright & acknowledgement information
    w    Print warranty information
    s    Analyze files within a single session
    b    Analyze all runs for a single subject
    p    Analyze all runs of several subjects

Positional arguments:
    OUTPUT  Directory under which \"derivatives\" directory will be created
            to store outputs from preprocessing steps"
}

print_copyright() {
    echo "
${PROGRAM}, version ${VERSION}, Copyright (C) ${COPYRIGHT_YEARS} ${AUTHORS}.

This script is free software; see the \"LICENSE\" file distributed with the
script to learn about copying conditions. The script is provided with
absolutely no warranty: use it at your own discretion.

To view more information about the warranty (or lack thereof), execute:
    $ ${PROGRAM} -w"
}

print_warranty() {
    echo "
This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
It should be distributed with this script under the name \"LICENSE\". If not,
please see <https://www.gnu.org/licenses/>.

To see a copyright notice, please execute:
    $ ${PROGRAM} -c"
}

exit_error() {
    echo "Error: $1"
    exit 1
}

create_dir(){
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

identify_file(){
    local -r scope="$1"
    local -r pattern="$2"
    IFS=$'\n'; local matches=$(find ${scope} -name ${pattern}); unset IFS
    local -r match_count="${#matches[@]}"
    if [ ${match_count} -gt 1 ]; then
        echo "More than 1 file matches pattern \"${pattern}\""
    elif [ ${match_count} -eq 1 ]; then
        echo "DEBUG: file matched is ${matches[0]}"
        selected_file="${matches[0]}"
    else
        exit_error "no files matched pattern \"${pattern}\""
        echo "No files matched the search pattern."
    fi
}

eddy_correction(){
    # Eddy current correction
    #
    # Usage:
    #   $ eddy_correct <input (.nii)> <output (.nii.gz & .ecclog)> [options]
    #
    # Outputs several tmp files, then combined to eddy_corrected.nii.gz
    # and logged to eddy_corrected.ecclog
    #
    # Reference: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide

    echo "Correcting for eddy currents within ${selected_file}..."
    # NOTE: does *not* like spaces in input/output file path!
    eddy_output="${working_dir}/${2}_eddy_corrected"
    eddy_correct $1 ${eddy_output} 0
}

brain_extraction(){
    # Skull strip the DTI
    #
    # Reference: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET/UserGuide
    #
    # Outputs brain.nii.gz & brain_mask.nii.gz in $RESULTS

    echo "Extracting binary brain mask..."
    # TODO: investigate feasibility of using `bet2` instead
    bet_output="${working_dir}/${2}_${file_basename}"
    bet "$1" ${bet_output} -F -f .3
}

analyze_session() {
    local -r session=$1

    if [ -d ${session} ]; then
        echo "DEBUG: analyzing \"${session}\"..."
        cd ${session}
    else
        exit_error "please pass a (existing) directory to the script"
    fi

    if [ ! -d "${session}/dwi" ]; then
        exit_error "no \"dwi\" subdirectory present

This script expects a BIDS-formatted directory as input
(i.e., the parent of the \"dwi\" directory). Please reformat
the current directory to comply with the BIDS specification or
point the script to an existing BIDS-compliant directory."
    fi

    local -r subject_id="$(basename $(dirname $(pwd)))"
    local -r session_id="$(basename $(pwd))"
    local -r prefix="${subject_id}_${session_id}"
    local -r session_outputs="${OUTPUT_PARENT}/${prefix}"
    local -r working_dir="${session_outputs}/tmp"

    create_dir ${session_outputs} ${TRUE}
    create_dir ${working_dir} ${FALSE}

    local -r file_basename="brain"

    identify_file "${session}/dwi" "*.nii.gz"
    echo "Unzipping ${selected_file} to ${working_dir}..."
    local filename="${prefix}_${file_basename}.nii"
    gunzip < "${selected_file}" > "${working_dir}/${filename}"

    # Correct eddy currents
    eddy_correction "${working_dir}/${filename}" "${prefix}"

    # Skull strip eddy-corrected images
    brain_extraction "${eddy_output}" "${prefix}"

    # Cleanup
    rm "${bet_output}.nii.gz"
    mv "${bet_output}_mask.nii.gz" \
       "${bet_output}_mask-nodif.nii.gz"

    # Select first image in temporal sequence of eddy-corrected scan
    echo "Splitting eddy-corrected scan into snapshots..."
    fslsplit "${eddy_output}" "${working_dir}/split" -t
    mv "${working_dir}/split0000.nii.gz" "${bet_output}-nodif.nii.gz"

    # Run dtifit
    echo "Fitting diffusion tensor model at each voxel..."
    local -r BVAL="$(find ${session} -name "*.bval")"
    local -r BVEC="$(find ${session} -name "*.bvec")"
    dtifit \
        -k "${eddy_output}" \
        -m "${bet_output}_mask-nodif.nii.gz" \
        -o "${session_outputs}/${prefix}" \
        -r "${BVEC}" \
        -b "${BVAL}"

    # Remove "${session_outputs}/tmp" directory
    rm -rf "${working_dir}"
}

analyze_subject() {
    subject=$1
    local session
    for session in $(ls -d ${subject}/*); do
        analyze_session ${session}
    done
}

analyze_project() {
    project=$1
    local subject
    for subject in $(ls -d ${project}/*); do
        analyze_subject ${subject}
    done
}

# TODO: add "-m" flag to encapsulate mode behavior & simplify interface
opts="hcws:b:p:"
while getopts ${opts} option; do
    case ${option} in
        h)
            print_purpose
            print_help
            exit
            ;;
        c)
            print_copyright
            ;;
        w)
            print_warranty
            ;;
        s) 
            mode="session"
            data_dir="${OPTARG}"
            bids_parent="$(realpath ${data_dir}/../../../)"
            ;;
        b)
            mode="subject"
            data_dir="${OPTARG}"
            bids_parent=$(realpath ${data_dir}/../..)
            ;;
        p)
            mode="project"
            data_dir="${OPTARG}"
            bids_parent=$(realpath ${data_dir}/..)
            ;;
        \?)
            print_help
            exit
            ;;
    esac
done

shift $((${OPTIND} - 1))

if [ -z "$1" ] && [ -z "${OUTPUT_PARENT}" ]; then
    exit_error "\"OUTPUT\" not specified"
elif [ -z "$1" ] && [ ! -z "${OUTPUT_PARENT}" ]; then
    echo "DEBUG: \"OUTPUT_PARENT\" already specified (\"${OUTPUT_PARENT}\")"
else
    echo "DEBUG: \"OUTPUT_PARENT\" specified as \"$1\""
    OUTPUT_PARENT="${bids_parent}/derivatives/$1"
    export OUTPUT_PARENT="${bids_parent}/derivatives/$1"
fi
create_dir ${OUTPUT_PARENT} ${FALSE}

case ${mode} in
    "session")
        echo "DEBUG: Starting session-level analysis."
        analyze_session ${data_dir}
        ;;
    "subject")
        echo "DEBUG: Starting subject-level analysis."
        analyze_subject ${data_dir}
        ;;
    "project")
        echo "DEBUG: Starting project-level analysis."
        analyze_project ${data_dir}
        ;;
esac

# TODO: rewrite following code to be modular & parallel-izable
# TODO: split code off into separate script if needed to do so
readonly TBSS_DIR="${OUTPUT_PARENT}/analysis"
create_dir "${TBSS_DIR}" ${FALSE}
# TODO: make use of select_file for the following
# TODO: modify select_file to be compatible with above requirement
for file in $(find "${OUTPUT_PARENT}" -name "*_FA.nii.gz"); do
    cp "${file}" "${TBSS_DIR}"
done
cd ${TBSS_DIR}
tbss_1_preproc *.nii.gz
tbss_2_reg -T
tbss_3_postreg -S
tbss_4_prestats 0.2