#!/bin/bash
set -e
printf "\n START: run_eddy_rodent \n"

workingdir=$1
topupdir=`dirname ${workingdir}`/topup

# Copy brain mask from topup folder to eddy folder
${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

# Run eddy
# Note: eddy_cuda has been parallelised with CUDA. This allows eddy to use an Nvidia GPU if one is available on the system
${FSLDIR}/bin/eddy_cuda --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_unwarped_images --cnr_maps -v

# Do QC checks
${FSLDIR}/bin/eddy_quad ${workingdir}/eddy_unwarped_images -idx ${workingdir}/index.txt -par ${workingdir}/acqparams.txt -m ${workingdir}/nodif_brain_mask -b ${workingdir}/Pos_Neg.bvals -g ${workingdir}/Pos_Neg.bvecs

printf "\n END: run_eddy_rodent \n"
