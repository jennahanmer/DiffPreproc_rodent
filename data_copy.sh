#!/bin/bash
set -e # stop script if there's an error
printf "\n START: data_copy" # echo must interpret \n

MissingFileFlag="EMPTY" #String used in the input arguments to indicate that a complete series is missing


min(){
  if [ $1 -le $2 ]; then
     echo $1
  else
     echo $2
  fi
}

outdir=$1
InputImages=$2
InputImages2=$3
PEdir=$4


if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    basePos="RL"
    baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    basePos="AP"
    baseNeg="PA"
fi



printf "\n Copying raw data"
#Copy RL/AP images to workingdir
#First for InputImages
InputImages=`echo ${InputImages} | sed 's/@/ /g'` # replace slash with space
Pos_count=1
for Image in ${InputImages} ; do
	if [[ ${Image} =~ ^.*EMPTY$  ]]  ;  # regular expression match for any string (.*) at the start of a line (^) which ends in ($) EMPTY
	then
		Image=?EMPTY?
	fi
	
    if [ ${Image} = ${MissingFileFlag} ];
    then	
        PosVols[${Pos_count}]=0
    else
	PosVols[${Pos_count}]=`${FSLDIR}/bin/fslval ${Image} dim4` # report number of volumes
	absname=`${FSLDIR}/bin/imglob ${Image}` # expands the full filename of the image
	${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
	cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
	cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
    fi	
    Pos_count=$((${Pos_count} + 1))
done

#Copy LR/PA images to workingdir
#Second for InputImages2
InputImages=`echo ${InputImages2} | sed 's/@/ /g'`
Neg_count=1
for Image in ${InputImages} ; do
	if [[ ${Image} =~ ^.*EMPTY$  ]]  ;  
	then
		Image=?EMPTY?
	fi
	
    if [ ${Image} = ${MissingFileFlag} ];
    then	
	NegVols[${Neg_count}]=0
    else
	NegVols[${Neg_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
	absname=`${FSLDIR}/bin/imglob ${Image}`
	${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
	cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
	cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
    fi	
    Neg_count=$((${Neg_count} + 1))
done

#Will usually only go through loop once as 1 image for each PE direction (may have a different number of volumes though)
if [ ${Pos_count} -ne ${Neg_count} ]; then
    echo "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
    echo "If the respective file does not exist, use EMPTY in the input arguments."
    exit 1
fi

#Create two files for each phase encoding direction, that for each series contains the number of corresponding volumes and the number of actual volumes.
#The file e.g. RL_SeriesCorrespVolNum.txt will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M from RLseries J
#has corresponding LR pairs. This file is used in basic_preproc to generate topup/eddy indices and extract corresponding b0s for topup.
#The file e.g. Pos_SeriesVolNum.txt will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J indicates that the RLSeries J has its 0-M volumes corresponding to LRSeries J and RLJ has N volumes in total. This file is used in eddy_combine.
Paired_flag=0
for (( j=1; j<${Pos_count}; j++ )) ; do # (postfix ++) return j's value before it has been incremented by 1
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    echo ${CorrVols} ${PosVols[${j}]} >> ${outdir}/eddy/Pos_SeriesVolNum.txt
    if [ ${PosVols[${j}]} -ne 0 ]; then
	echo ${CorrVols} >> ${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
	if [ ${CorrVols} -ne 0 ]; then
	    Paired_flag=1 # Paired_flag redefined
	fi
    fi	
done
for (( j=1; j<${Neg_count}; j++ )) ; do
    CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
    echo ${CorrVols} ${NegVols[${j}]} >> ${outdir}/eddy/Neg_SeriesVolNum.txt
    if [ ${NegVols[${j}]} -ne 0 ]; then
	echo ${CorrVols} >> ${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
    fi	
done

if [ ${Paired_flag} -eq 0 ]; then
    echo "Wrong Input! No pairs of phase encoding directions have been found!"
    echo "At least one pair is needed!"
    exit 1
fi

# Visualise results
# fslroi AP_1.nii.gz AP_b0.nii.gz 0 1
# slicer AP_b0.nii.gz -a AP_b0.png
# fslroi PA_1.nii.gz PA_b0.nii.gz 0 1
# slicer PA_b0.nii.gz -a PA_b0.png

printf "\n END: data_copy \n"

