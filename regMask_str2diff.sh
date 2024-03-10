#!/bin/bash
set -e
printf "\n START: regMask_str2diff.sh \n" # echo must interpret \n"

# Script registers structural brain mask to diffusion space

# Note that this script assumes that have run reorient_n_label.sh (i.e., it expects specific filing structure, naming convention and b0 to have already been created)
# Alternatively, the script can be run using hifib0 from topup

# Define arguments
outdir=$1
InputImages=$2 # diffusion scan (can be b0 if being run post-topup)
T2_scan=$3
BrainMask=$4 # T2 brain mask in subject space (created by rodent structural pipeline)
printf "\n T2_scan="
echo ${T2_scan}
printf "\n BrainMask="
echo ${BrainMask}

# Create variables
imagename=`${FSLDIR}/bin/imglob ${InputImages}`
basename=`echo "${imagename##*/}"` # shortened version of imagename that used as suffix
printf "\n imagename="
echo ${imagename}
printf "\n basename="
echo ${basename}

# printf "\n Extracting b0 from volume"
# Extract b0 (i.e., first volume) from volume, this will be used for registration
# ${FSLDIR}/bin/fslroi ${InputImages} ${basename}_b0 0 1

printf "\n Checking if input image is a b0 (i.e., 1 volume)"

# Check if image is a b0 (i.e., hifib0) or whole diffusion scan (i.e., dwi_fwd_reorint or dwi_rvs_reorient)
dim4=`${FSLDIR}/bin/fslval ${imagename} dim4`

printf "\n Registering b0 to subject's structural scan"

# Generate the rigid body transform (6DOF) to align b0 to the structural scan, expand the registration search space, i.e., to allow bigger rotations/translations
if [ ${dim4} -ne 1 ];
then
    echo ""
    echo " b0 being accessed from reorientdir"
    echo ""
    ${FSLDIR}/bin/flirt -in ${imagename}_b0 -ref ${T2_scan} -searchrz -270 270 -searchry -270 270 -searchrx -270 270 -out ${imagename}_2str -omat ${imagename}_2str.mat -dof 6
    # assumes that InputImages is in reorientdir with the b0

    # Check that the linear registration was successful
    ${FSLDIR}/bin/slicer ${imagename}_2str ${BrainMask} -a ${imagename}_2str.png

    # Invert the transform so that it can be used to take the mask from structural to diffusion space
    ${FSLDIR}/bin/convert_xfm -omat ${outdir}/str2_${basename}.mat -inverse ${imagename}_2str.mat
    # assumes that have specified reorientdir as outdir

else
    echo ""
    echo " input is a b0"
    echo ""
    ${FSLDIR}/bin/flirt -in ${imagename} -ref ${T2_scan} -searchrz -270 270 -searchry -270 270 -searchrx -270 270 -out ${outdir}/${basename}_2str -omat ${outdir}/${basename}_2str.mat -dof 6
    # doesn't assume location of InputImage

    # Check that the linear registration was successful
    ${FSLDIR}/bin/slicer ${outdir}/${basename}_2str ${BrainMask} -a ${outdir}/${basename}_2str.png

    # Invert the transform so that it can be used to take the mask from structural to diffusion space
    ${FSLDIR}/bin/convert_xfm -omat ${outdir}/str2_${basename}.mat -inverse ${outdir}/${basename}_2str.mat

fi

printf "\n Generating subject's brain mask (should be binary) in diffusion space"

# Apply the transform to get subject's structural mask to diffusion space
if [ ${dim4} -ne 1 ];
then
    ${FSLDIR}/bin/flirt -interp nearestneighbour -in ${BrainMask} -ref ${imagename}_b0.nii.gz -init ${outdir}/str2_${basename}.mat -out ${imagename}_mask.nii.gz
    # Removed -applyxfm & reordered options
    # Check that the transformation of the mask to diffusion space was successful
    ${FSLDIR}/bin/slicer ${imagename}_b0 ${imagename}_mask -a ${imagename}_mask.png

else
    echo "${FSLDIR}/bin/flirt -interp nearestneighbour -in ${BrainMask} -ref ${InputImages} -init ${outdir}/str2_${basename}.mat -out ${outdir}/${basename}_mask.nii.gz"
    ${FSLDIR}/bin/flirt -interp nearestneighbour -in ${BrainMask} -ref ${InputImages} -init ${outdir}/str2_${basename}.mat -out ${outdir}/${basename}_mask.nii.gz
    # Removed -applyxfm & reordered options
    # Check that the transformation of the mask to diffusion space was successful
    echo "${FSLDIR}/bin/slicer ${InputImages} ${outdir}/${basename}_mask.nii.gz -a ${outdir}/${basename}_mask.png"
    ${FSLDIR}/bin/slicer ${InputImages} ${outdir}/${basename}_mask.nii.gz -a ${outdir}/${basename}_mask.png
fi

printf "\n END: regMask_str2diff.sh"
