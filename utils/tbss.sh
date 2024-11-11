#!/usr/bin/env bash

# tbss.sh
# -------
# Carry out tract-based spatial statistics ("TBSS").

# NOTE: uses $ENIGMA_ROOT, exported by run_analysis.sh
# TODO: handle error case in which $ENIGMA_ROOT is unset, e.g., running this
#       script directly instead of being called by run_analysis.sh
# TODO: add "DEBUG" outputs to script

readonly INPUT="$1"

cd ${INPUT}
tbss_1_preproc *.nii.gz  # Produces FA mask
tbss_2_reg -t ${ENIGMA_ROOT}/ENIGMA_DTI_FA.nii.gz  # Register to ENIGMA target
tbss_3_postreg -S  # Create mean/all FA, mean FA mask, & mean FA skeleton
