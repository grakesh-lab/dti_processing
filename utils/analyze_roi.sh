#!/usr/bin/env bash

# NOTE: uses $ENIGMA_ROOT, exported by run_analysis.sh
# TODO: handle error case in which $ENIGMA_ROOT is unset, e.g., running this
#       script directly instead of being called by run_analysis.sh
# TODO: add "DEBUG" outputs to script

readonly session="$1"

id="$(basename ${session})"

${ENIGMA_ROOT}/single_subject_roi ${ENIGMA_ROOT}/JHU_roi_look_up_table.txt \
  ${ENIGMA_ROOT}/ENIGMA_DTI_FA_skeleton.nii.gz \
  ${ENIGMA_ROOT}/JHU_atlas.nii.gz \
  ${session}/stats/${id}_roi \
  ${session}/stats/${id}_masked_FA_skel.nii.gz

${ENIGMA_ROOT}/average_subject_tracts \
  ${session}/stats/${id}_roi.csv \
  ${session}/stats/${id}_roi_avg.csv
