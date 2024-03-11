#!/bin/bash
set -e
printf "\n START: post_topup_cc" # echo must interpret \n

# Script which tests whether topup leads to an improvement in b0 (i.e., whether b0 after topup is more correlated with T2 scan than the b0's (both in the Neg and Pos direction) before topup

# Define arguments
preprocdir=$1
T2_reorient=$2
BrainMask=$3

# Define variables
topupdir=${preprocdir}/topup
regMaskdir=${preprocdir}/regMask

printf "\n Checking how many volumes are in Pos_Neg_b0"

dim4=`${FSLDIR}/bin/fslval ${topupdir}/Pos_Neg_b0.nii.gz dim4`

echo ""
echo " Number of volumes in Pos_Neg_b0: "${dim4}
echo ""

halfdim=$((dim4/2))

printf "\n Splitting Pos_Neg_b0 into Pos_b0 and Neg_b0"
# Get Pos_b0 and Neg_b0
${FSLDIR}/bin/fslroi ${topupdir}/Pos_Neg_b0.nii.gz ${regMaskdir}/Pos_b0 0 1
${FSLDIR}/bin/fslroi ${topupdir}/Pos_Neg_b0.nii.gz ${regMaskdir}/Neg_b0 ${halfdim} 1

printf "\n Registering Pos_b0 and Neg_b0 to structural scan"
# Register these to structural scan (after reorientation)
${FSLDIR}/bin/flirt -in ${regMaskdir}/Pos_b0 -ref ${T2_reorient} -searchrz -270 270 -searchry -270 270 -searchrx -270 270 -out ${regMaskdir}/Pos_b0_2str -dof 6 # -omat ${regMaskdir}/Pos_b0_2str.mat
${FSLDIR}/bin/flirt -in ${regMaskdir}/Neg_b0 -ref ${T2_reorient} -searchrz -270 270 -searchry -270 270 -searchrx -270 270 -out ${regMaskdir}/Neg_b0_2str -dof 6 # -omat ${regMaskdir}/Neg_b0_2str.mat 

# Check that registration was successful and see distortions corrected
${FSLDIR}/bin/slicer ${regMaskdir}/Pos_b0_2str ${BrainMask} -a ${regMaskdir}/Pos_b0_2str.png
${FSLDIR}/bin/slicer ${regMaskdir}/Neg_b0_2str ${BrainMask} -a ${regMaskdir}/Neg_b0_2str.png

# Invert these transformations
# ${FSLDIR}/bin/convert_xfm -omat ${regMaskdir}/str2_Pos_b0.mat -inverse ${regMaskdir}/Pos_b0_2str.mat
# ${FSLDIR}/bin/convert_xfm -omat ${regMaskdir}/str2_Neg_b0.mat -inverse ${regMaskdir}/Neg_b0_2str.mat

# Apply inverted transformations to take the brain mask to diffusion space
# ${FSLDIR}/bin/flirt -in ${BrainMask} -ref ${regMaskdir}/Pos_b0 -applyxfm -init ${regMaskdir}/str2_Pos_b0.mat -out ${regMaskdir}/Pos_b0_mask -interp nearestneighbour
# ${FSLDIR}/bin/flirt -in ${BrainMask} -ref ${regMaskdir}/Neg_b0 -applyxfm -init ${regMaskdir}/str2_Neg_b0.mat -out ${regMaskdir}/Neg_b0_mask -interp nearestneighbour

printf "\n Determining whether topup improves correlation between b0 and structural scan"
# Create txt file containing correlations
hifib0_2str_cc=`${FSLDIR}/bin/fslcc -m ${BrainMask} -p 5 ${T2_reorient} ${regMaskdir}/hifib0_2str.nii.gz`
Pos_b0_2str_cc=`${FSLDIR}/bin/fslcc -m ${BrainMask} -p 5 ${T2_reorient} ${regMaskdir}/Pos_b0_2str.nii.gz`
Neg_b0_2str_cc=`${FSLDIR}/bin/fslcc -m ${BrainMask} -p 5 ${T2_reorient} ${regMaskdir}/Neg_b0_2str.nii.gz`
touch ${preprocdir}/topup/correl.txt
echo "correlation between hifib0 and structural           = ${hifib0_2str_cc}" >> ${preprocdir}/topup/correl.txt
echo "correlation between Pos_b0 and structural           = ${Pos_b0_2str_cc}" >> ${preprocdir}/topup/correl.txt
echo "correlation between Neg_b0 and structural           = ${Neg_b0_2str_cc}" >> ${preprocdir}/topup/correl.txt

# Print correlations as check
printf "\nCORRELATIONS OF B0 BEFORE AND AFTER TOPUP:\n"
cat ${preprocdir}/topup/correl.txt
printf "END OF CORRELATIONS FILE\n"

printf "\n END: post_topup_cc"
