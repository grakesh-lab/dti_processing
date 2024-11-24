#!/usr/bin/env bash

# analyze_roi.sh
# --------------
# Calculate diffusivity & anisotropy of regions of interest.

# NOTE: uses $ENIGMA_ROOT, exported by run_analysis.sh
# TODO: handle error case in which $ENIGMA_ROOT is unset, e.g., running this
#       script directly instead of being called by run_analysis.sh
# TODO: add "DEBUG" outputs to script

readonly SKELETON="${1}"
readonly MEASURE_PATH="$(dirname "$(dirname "${SKELETON}")")"
readonly SESSION="$(basename "$(dirname "${MEASURE_PATH}")")"

${ENIGMA_ROOT}/single_subject_roi "${ENIGMA_ROOT}/JHU_roi_look_up_table.txt" \
  "${ENIGMA_ROOT}/ENIGMA_DTI_FA_SKELETON.nii.gz" \
  "${ENIGMA_ROOT}/JHU_atlas.nii.gz" \
  "${MEASURE_PATH}/stats/${SESSION}_roi" \
  "${SKELETON}"

${ENIGMA_ROOT}/average_subject_tracts \
  "${MEASURE_PATH}/stats/${SESSION}_roi.csv" \
  "${MEASURE_PATH}/stats/${SESSION}_roi_av"g.csv
