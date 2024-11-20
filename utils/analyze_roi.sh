#!/usr/bin/env bash

# NOTE: uses $ENIGMA_ROOT, exported by run_analysis.sh
# TODO: handle error case in which $ENIGMA_ROOT is unset, e.g., running this
#       script directly instead of being called by run_analysis.sh
# TODO: add "DEBUG" outputs to script

readonly skeleton="$1"
readonly measure_path=$(basename $(dirname $(dirname "${session}")))
readonly measure=$(basename ${measure_path})
readonly session="$(basename $(dirname "${measure_path}"))"

${ENIGMA_ROOT}/single_subject_roi ${ENIGMA_ROOT}/JHU_roi_look_up_table.txt \
  ${ENIGMA_ROOT}/ENIGMA_DTI_FA_skeleton.nii.gz \
  ${ENIGMA_ROOT}/JHU_atlas.nii.gz \
  ${measure_path}/stats/${session}_roi \
  ${skeleton}

${ENIGMA_ROOT}/average_subject_tracts \
  ${measure_path}/stats/${session}_roi.csv \
  ${measure_path}/stats/${session}_roi_avg.csv
