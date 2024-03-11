#!/bin/bash
set -e
printf "\n START: MD_single-shell"

# Script name: rodent_struct

# Description: Script to calculate MD from single-shell data
# The noise floor is high relative to the single when acquiring diffusion data at high bvalues so the MD estimates for multishell data will be inaccurate
# It is better to calculate MD on single shell diffusion data acquired at low bval
# As a sanity check, verify what the MD in the ventricles is, it should be ~0.0003mm^2/s at body temperature

# 1. Use select_dwi_vols to extract volumes with lowest b-value (e.g., 4000) from a 4D diffusion-weighted dataset. This command will create a new 4D file containg only those volumes with b-values ~=0 and ~=4000. It will also generate two new bvals and bvecs files containing only the selected b-values and b-vectors

# Authors: Jenna Hanmer

# Usage
# $1 - working directory
# $2 - low bval

# Dependencies
# 1. FSL (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)
# This script assumes that the DiffPreproc_rodent.sh script has been run

# Define arguments
workingdir=$1
low_bval=$2

# Define variables 
eddydir=${workingdir}/eddy
datadir=${workingdir}/data

# 1. Extract volumes with b-values ~=0 and ~=4000 and create new bvals and bvecs files
# Usage: select_dwi_vols <data> <bvals> <output> <approx_bval(to within 100 s/mm2)> [other options]
${FSLDIR}/bin/select_dwi_vols ${eddydir}/eddy_unwarped_images.nii.gz ${datadir}/bvals ${datadir}/single_shell 0 -b ${low_bval} -obv ${datadir}/bvecs ${datadir}/single_shell

# 2. Run dtifit on single_shell data
${FSLDIR}/bin/dtifit -k ${datadir}/single_shell -m ${datadir}/nodif_brain_mask -r ${datadir}/single_shell.bvec -b ${datadir}/single_shell.bval -o ${datadir}/dti_single_shell

# 3. Cleaning up unnecessary files
rm ${datadir}/dti_single_shell_F* ${datadir}/dti_single_shell_V* ${datadir}/dti_single_shell_L* ${datadir}/dti_single_shell_S* ${datadir}/dti_single_shell_MO.nii.gz

printf "\n END: MD_single-shell"
