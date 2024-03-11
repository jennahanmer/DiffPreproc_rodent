#!/bin/bash
set -e
printf "\n START: eddy_postproc"


workingdir=$1
CombineMatchedFlag=$2

eddydir=${workingdir}/eddy
topupdir=${workingdir}/topup
datadir=${workingdir}/data

if [ ${CombineMatchedFlag} -eq 2 ]; then
    ${FSLDIR}/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
    ${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${datadir}/nodif_brain_mask
    cp ${eddydir}/Pos_Neg.bvals ${datadir}/bvals
    cp ${eddydir}/Pos_Neg.bvecs ${datadir}/bvecs
else 
    PosVols=`wc ${eddydir}/Pos.bval | awk {'print $2'}`
    NegVols=`wc ${eddydir}/Neg.bval | awk {'print $2'}`    #Split Pos and Neg Volumes
    ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Pos 0 ${PosVols}
    ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Neg ${PosVols} ${NegVols}
    ${FSLDIR}/bin/eddy_combine ${eddydir}/eddy_unwarped_Pos ${eddydir}/Pos.bval ${eddydir}/Pos.bvec ${eddydir}/Pos_SeriesVolNum.txt \
        ${eddydir}/eddy_unwarped_Neg ${eddydir}/Neg.bval ${eddydir}/Neg.bvec ${eddydir}/Neg_SeriesVolNum.txt ${datadir} ${CombineMatchedFlag}

    ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Pos
    ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Neg
fi

#Remove negative intensity values (caused by spline interpolation) from final data
${FSLDIR}/bin/fslmaths ${datadir}/data -thr 0 ${datadir}/data
#${FSLDIR}/bin/bet ${datadir}/data ${datadir}/nodif_brain -m -f 0.25

#Run dtifit
${FSLDIR}/bin/dtifit -k ${datadir}/data -m ${datadir}/nodif_brain_mask -r ${datadir}/bvecs -b ${datadir}/bvals -o ${datadir}/dti

#Cleaning up unnecessary files
rm -rf ${workingdir}/rawdata
${FSLDIR}/bin/imrm ${eddydir}/Pos_Neg
#${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_images

printf "\n END: eddy_postproc"
