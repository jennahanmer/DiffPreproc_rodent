#!/bin/bash
set -e
printf "\n START: run_topup_rodent \n"


workingdir=$1 # ${outdir}/topup

topup_config_file=${FSLDIR}/etc/flirtsch/b02b0.cnf


${FSLDIR}/bin/topup --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${topup_config_file} --fout=${workingdir}/myfield --out=${workingdir}/topup_Pos_Neg_b0 -v
# potentially add iout and check movement parameters (i.e., topup_Pos_Neg_b0_movpar.txt)

dimt=`${FSLDIR}/bin/fslval ${workingdir}/Pos_b0 dim4`
dimt=$((${dimt} + 1))

printf "\n Applying topup to get a hifi b0" # This is just a sanity check
# to avoid resampling more than once, don't correct for susceptibility field until eddy
# get first b0 for each PE direction
${FSLDIR}/bin/fslroi ${workingdir}/Pos_b0 ${workingdir}/Pos_b01 0 1 
${FSLDIR}/bin/fslroi ${workingdir}/Neg_b0 ${workingdir}/Neg_b01 0 1
${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/hifib0

${FSLDIR}/bin/imrm ${workingdir}/Pos_b0*
${FSLDIR}/bin/imrm ${workingdir}/Neg_b0*

# ${FSLDIR}/bin/slicer ${workingdir}/myfield.nii.gz -a ${workingdir}/suscept_field.png

# echo "Running BET on the hifi b0"
# bet won't work on rodent data 
# ${FSLDIR}/bin/bet ${workingdir}/hifib0 ${workingdir}/nodif_brain -m -f 0.2

# Visualise results
# slicer ../topup/hifib0.nii.gz hifib0_mask.nii.gz -a hifib0_mask.png
# slicer myfield.nii.gz -a suscept_field.png
# slicer nodif_brain.nii.gz nodif_brain_mask.nii.gz -a nodif_brain.png

printf "\n END: run_topup_rodent"

