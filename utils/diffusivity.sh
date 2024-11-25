#!/usr/bin/env bash

# diffusivity.sh
# -------------
# Derive mean, radial, & axial diffusivity measures.

# Assumes that $FSLDIR & $ENIGMA_ROOT are defined in the calling script

set -uo pipefail

readonly SUBJECT="${1}"
readonly INDIVIDUAL="${ANALYSIS}/individual"

function derive_diffusivity_measures() {
  mkdir -p "${INDIVIDUAL}/${SUBJECT}"/{MD,AD,RD}/{origdata,stats,intermediary}
  cp "${DERIVATIVES}/${SUBJECT}/${SUBJECT}_MD.nii.gz" "${INDIVIDUAL}/${SUBJECT}/MD/origdata/${SUBJECT}_MD.nii.gz"
  cp "${DERIVATIVES}/${SUBJECT}/${SUBJECT}_L1.nii.gz" "${INDIVIDUAL}/${SUBJECT}/AD/origdata/${SUBJECT}_AD.nii.gz"
  fslmaths "${DERIVATIVES}/${SUBJECT}/${SUBJECT}_L2.nii.gz" -add "${DERIVATIVES}/${SUBJECT}/${SUBJECT}_L3.nii.gz" -div 2 "${INDIVIDUAL}/${SUBJECT}/RD/origdata/${SUBJECT}_RD.nii.gz"
  return 0
}

function mask_diffusivity_measures() {
  local -r _subject_dir="${INDIVIDUAL}/${SUBJECT}"
  for _measure in "MD" "AD" "RD"; do
    local _filename="${SUBJECT}_${_measure}.nii.gz"
    fslmaths "${_subject_dir}/${_measure}/origdata/${_filename}" -mas \
      "${_subject_dir}/FA/intermediary/${SUBJECT}_FA_mask.nii.gz" \
      "${_subject_dir}/${_measure}/intermediary/${SUBJECT}"
  done
  return 0
}

function warp_masked_measures() {
  local -r _subject_dir="${INDIVIDUAL}/${SUBJECT}"
  for _measure in "MD" "AD" "RD"; do
    local -r _intermediary_dir="${_subject_dir}/${_measure}/intermediary"
    applywarp \
      -i "${_intermediary_dir}/${SUBJECT}.nii.gz" \
      -o "${_intermediary_dir}/${SUBJECT}_to_target.nii.gz" \
      -r "${FSLDIR}/data/standard/FMRIB58_FA_1mm" \
      -w "${_subject_dir}/FA/intermediary/${SUBJECT}_FA_to_target_warp.nii.gz"
  done
  return 0
}

function mask_measure_targets() {
  local -r _subject_dir="${INDIVIDUAL}/${SUBJECT}"
  for _measure in "MD" "AD" "RD"; do
    local -r _intermediary_dir="${_subject_dir}/${_measure}/intermediary"
    fslmaths "${_intermediary_dir}/${SUBJECT}_to_target.nii.gz" \
      -mas "${ENIGMA_ROOT}/ENIGMA_DTI_FA_mask.nii.gz" \
      "${_intermediary_dir}/${SUBJECT}_masked_${_measure}.nii.gz"
  done
  return 0
}

function skeletonize_measures() {
  local -r _subject_dir="${INDIVIDUAL}/${SUBJECT}"
  for _measure in "MD" "AD" "RD"; do
    tbss_skeleton \
      -i "${ENIGMA_ROOT}/ENIGMA_DTI_FA.nii.gz" \
      -p 0.049 \
      "${ENIGMA_ROOT}/ENIGMA_DTI_FA_skeleton_mask_dst.nii.gz" \
      "${FSLDIR}/data/standard/LowerCingulum_1mm.nii.gz" \
      "${_subject_dir}/FA/intermediary/${SUBJECT}_masked_FA.nii.gz" \
      "${_subject_dir}/${_measure}/stats/${SUBJECT}_masked_${_measure}_skel.nii.gz" \
        -a "${_subject_dir}/${_measure}/intermediary/${SUBJECT}_masked_${_measure}.nii.gz" \
        -s "${ENIGMA_ROOT}/ENIGMA_DTI_FA_mask.nii.gz"
  done
  return 0
}

# Make GNU parallel aware of these variables & functions
export ANALYSIS
export DERIVATIVES
export ENIGMA_ROOT
export -f derive_diffusivity_measures
export -f mask_diffusivity_measures
export -f warp_masked_measures
export -f mask_measure_targets
export -f skeletonize_measures

derive_diffusivity_measures
mask_diffusivity_measures
warp_masked_measures
mask_measure_targets
skeletonize_measures

exit 0
