#!/usr/bin/env bash

# skeletonize.sh
# --------------
# Carry out NIFTI skeletonization.

# NOTE: uses $ENIGMA_ROOT, exported by run_analysis.sh.
# NOTE: assumes FSLDIR has been set (see https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FslInstallation(2f)ShellSetup.html)
# TODO: handle error case in which $ENIGMA_ROOT is unset, e.g., running this
#       script directly instead of being called by run_analysis.sh
# TODO: add "DEBUG" outputs to script

readonly session="${1}"
readonly analysis_root="${2}"

id="$(basename "${session}")"

cp "${analysis_root}/FA/${id}_"*".nii.gz" "${session}/FA"

fslmaths "${session}/FA/${id}_FA_to_target.nii.gz" \
  -mas "${REFERENCE_ROOT}/ENIGMA/ENIGMA_DTI_FA_skeleton_mask.nii.gz" \
  "${session}/FA/${id}_masked_FA.nii.gz"

tbss_skeleton \
  -i "${session}/FA/${id}_masked_FA.nii.gz" \
  -p 0.049 \
  "${REFERENCE_ROOT}/ENIGMA/ENIGMA_DTI_FA_skeleton_mask_dst.nii.gz" \
  "${FSLDIR}/data/standard/LowerCingulum_1mm.nii.gz" \
  "${session}/FA/${id}_masked_FA.nii.gz" \
  "${session}/stats/${id}_masked_FA_skel.nii.gz" \
  -s "${REFERENCE_ROOT}/ENIGMA/ENIGMA_DTI_FA_mask.nii.gz"

exit 0
