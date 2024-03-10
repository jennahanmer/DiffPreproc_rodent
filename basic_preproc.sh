#!/bin/bash
set -e
printf "\n START: basic_preproc \n"

workingdir=$1
echo_spacing=$2
PEdir=$3
b0dist=$4
b0maxbval=$5
GRAPPA=$6 # PIFactor

isodd(){
    echo "$(( $1 % 2 ))" # check whether a number is divisible by 2 or not
}

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    basePos="RL"
    baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    basePos="AP"
    baseNeg="PA"
fi


#Compute Total_readout in secs with up to 6 decimal places
any=`ls ${rawdir}/${basePos}*.nii* |head -n 1` # print first line
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    dimP=`${FSLDIR}/bin/fslval ${any} dim1` # number of voxels x direction
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    dimP=`${FSLDIR}/bin/fslval ${any} dim2` # number of voxels x direction
fi
nPEsteps=$(($dimP - 1))                         #If GRAPPA is used this needs to include the GRAPPA factor!
#Total_readout=Echo_spacing*(#of_PE_steps-1)   
ro_time=`echo "${echo_spacing} / ${GRAPPA} * ${nPEsteps} " | bc -l` #bc=basic calculator
ro_time=`echo "scale=6; ${ro_time} / 1000" | bc -l` # to give in seconds
printf "\n Total readout time is $ro_time secs"


################################################################################################
## Intensity Normalisation across Series 
################################################################################################
printf "\n Rescaling series to ensure consistency across baseline intensities"
entry_cnt=0
for entry in ${rawdir}/${basePos}*.nii* ${rawdir}/${baseNeg}*.nii*  #For each series, get the mean b0 and rescale to match the first series baseline
do
   basename=`imglob ${entry}`
    printf "\n Processing $basename"
    ${FSLDIR}/bin/fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean
    Posbvals=`cat ${basename}.bval`
    mcnt=0
    for i in ${Posbvals} #extract all b0s for the series
    do
	cnt=`$FSLDIR/bin/zeropad $mcnt 4` # zeropad <input> <length of output> (e.g. zeropad 1 4    gives 0001)
	float=$i
	int=${float%.*}
	if [ $int -lt ${b0maxbval} ]; then # if posbvals < b0max then create an image for b0 that matches mean b0 after rescaling
	    $FSLDIR/bin/fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1
	    #fslroi <input> <output> <tmin> <tsize>
	fi
	mcnt=$((${mcnt} + 1))
    done
    ${FSLDIR}/bin/fslmerge -t ${basename}_mean `echo ${basename}_b0_????.nii*` #concatenate individual b0 images into one 4D image with all b0
    ${FSLDIR}/bin/fslmaths ${basename}_mean -Tmean ${basename}_mean #This is the mean baseline b0 intensity for the series of b0
    ${FSLDIR}/bin/imrm ${basename}_b0_???? # remove individual b0 images 
    if [ ${entry_cnt} -eq 0 ]; then      #Do not rescale the first series
	rescale=`fslmeants -i ${basename}_mean` #average intensity over all voxels in 4D image
    else # if ${entry_cnt} not equal to 0, rescale will have already been defined as average intensity for first b0 image
	scaleS=`fslmeants -i ${basename}_mean`
	${FSLDIR}/bin/fslmaths ${basename} -mul ${rescale} -div ${scaleS} ${basename}_new
	${FSLDIR}/bin/imrm ${basename}   #For the rest, replace the original dataseries with the rescaled one 
        ${FSLDIR}/bin/immv ${basename}_new ${basename}
    fi
    entry_cnt=$((${entry_cnt} + 1))
    ${FSLDIR}/bin/imrm ${basename}_mean
done


################################################################################################
## b0 extraction and Creation of Index files for topup/eddy 
################################################################################################
printf "\n Extracting b0s from PE_Positive volumes and creating index and series files"
declare -i sesdimt #declare sesdimt as integer
tmp_indx=1
while read line ; do  #Read SeriesCorrespVolNum.txt file
    PCorVolNum[${tmp_indx}]=`echo $line | awk {'print $1'}`
    tmp_indx=$((${tmp_indx}+1))
done < ${rawdir}/${basePos}_SeriesCorrespVolNum.txt # < - input to command

scount=1
scount2=1
indcount=0
for entry in ${rawdir}/${basePos}*.nii*  #For each Pos volume
do
  #Extract b0s and create index file
  basename=`imglob ${entry}`
  Posbvals=`cat ${basename}.bval`
  count=0  #Within series counter
  count3=$((${b0dist} + 1))
  for i in ${Posbvals} 
  do  
    float=$i
    int=${float%.*}
    if [ $count -ge ${PCorVolNum[${scount2}]} ]; then
	tmp_ind=${indcount}
	if [ $[tmp_ind] -eq 0 ]; then
	    tmp_ind=$((${indcount}+1))
	fi    
	echo ${tmp_ind} >>${rawdir}/index.txt
    else  #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
	if [ $int -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then  
	    cnt=`$FSLDIR/bin/zeropad $indcount 4`
	    echo "Extracting Pos Volume $count from ${entry} as a b=0. Measured b=$int" >>${rawdir}/extractedb0.txt
	    $FSLDIR/bin/fslroi ${entry} ${rawdir}/Pos_b0_${cnt} ${count} 1
	    if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
		echo 1 0 0 ${ro_time} >> ${rawdir}/acqparams.txt
	    elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
		echo 0 1 0 ${ro_time} >> ${rawdir}/acqparams.txt
	    fi    
	    indcount=$((${indcount} + 1))
	    count3=0
	fi
	echo ${indcount} >>${rawdir}/index.txt
	count3=$((${count3} + 1))
    fi	
    count=$((${count} + 1))
  done

  #Create series file
  sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4` #Number of datapoints per Pos series
  for (( j=0; j<${sesdimt}; j++ ))  
  do
      echo ${scount} >> ${rawdir}/series_index.txt
  done
  scount=$((${scount} + 1))
  scount2=$((${scount2} + 1))
done


printf "\n Extracting b0s from PE_Negative volumes and creating index and series files"
tmp_indx=1
while read line ; do  #Read SeriesCorrespVolNum.txt file
    NCorVolNum[${tmp_indx}]=`echo $line | awk {'print $1'}`
    tmp_indx=$((${tmp_indx}+1))
done < ${rawdir}/${baseNeg}_SeriesCorrespVolNum.txt

Poscount=${indcount}
indcount=0
scount2=1
for entry in ${rawdir}/${baseNeg}*.nii* #For each Neg volume
do
  #Extract b0s and create index file
  basename=`imglob ${entry}`
  Negbvals=`cat ${basename}.bval`
  count=0
  count3=$((${b0dist} + 1))
  for i in ${Negbvals}
  do 
    float=$i
    int=${float%.*}
      if [ $count -ge ${NCorVolNum[${scount2}]} ]; then
	  tmp_ind=${indcount}
	  if [ $[tmp_ind] -eq 0 ]; then
	      tmp_ind=$((${indcount}+1))
	  fi    
	  echo $((${tmp_ind} + ${Poscount})) >>${rawdir}/index.txt
      else #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
	  if [ $int -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then  
	      cnt=`$FSLDIR/bin/zeropad $indcount 4`
	      echo "Extracting Neg Volume $count from ${entry} as a b=0. Measured b=$int" >>${rawdir}/extractedb0.txt
	      $FSLDIR/bin/fslroi ${entry} ${rawdir}/Neg_b0_${cnt} ${count} 1
	      if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
		  echo -1 0 0 ${ro_time} >> ${rawdir}/acqparams.txt
	      elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
		  echo 0 -1 0 ${ro_time} >> ${rawdir}/acqparams.txt
	      fi 
	      indcount=$((${indcount} + 1))
	      count3=0
	  fi
	  echo $((${indcount} + ${Poscount})) >>${rawdir}/index.txt
	  count3=$((${count3} + 1))
      fi
      count=$((${count} + 1))
  done

  #Create series file
  sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4`
  for (( j=0; j<${sesdimt}; j++ ))
  do
      echo ${scount} >> ${rawdir}/series_index.txt #Create series file
  done
  scount=$((${scount} + 1))
  scount2=$((${scount2} + 1))
done


################################################################################################
## Merging Files and correct number of slices 
################################################################################################
printf "\n Merging Pos and Neg images"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_b0 `${FSLDIR}/bin/imglob ${rawdir}/Pos_b0_????.*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg_b0 `${FSLDIR}/bin/imglob ${rawdir}/Neg_b0_????.*`
${FSLDIR}/bin/imrm ${rawdir}/Pos_b0_????
${FSLDIR}/bin/imrm ${rawdir}/Neg_b0_????
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos `echo ${rawdir}/${basePos}*.nii*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg `echo ${rawdir}/${baseNeg}*.nii*`

paste `echo ${rawdir}/${basePos}*.bval` >${rawdir}/Pos.bval
paste `echo ${rawdir}/${basePos}*.bvec` >${rawdir}/Pos.bvec
paste `echo ${rawdir}/${baseNeg}*.bval` >${rawdir}/Neg.bval
paste `echo ${rawdir}/${baseNeg}*.bvec` >${rawdir}/Neg.bvec


dimz=`${FSLDIR}/bin/fslval ${rawdir}/Pos dim3`
if [ `isodd $dimz` -eq 1 ];then
    printf "\n Remove one slice from data to get even number of slices"
    #fslroi <input> <output> <xmin> <xsize> <ymin> <ysize> <zmin> <zsize>
    #indexing (in both time and space) starts with 0 not 1! Inputting -1 for a size will set it to the full image extent for that dimension.
    ${FSLDIR}/bin/fslroi ${rawdir}/Pos ${rawdir}/Posn 0 -1 0 -1 1 -1
    ${FSLDIR}/bin/fslroi ${rawdir}/Neg ${rawdir}/Negn 0 -1 0 -1 1 -1
    ${FSLDIR}/bin/fslroi ${rawdir}/Pos_b0 ${rawdir}/Pos_b0n 0 -1 0 -1 1 -1
    ${FSLDIR}/bin/fslroi ${rawdir}/Neg_b0 ${rawdir}/Neg_b0n 0 -1 0 -1 1 -1
    ${FSLDIR}/bin/imrm ${rawdir}/Pos
    ${FSLDIR}/bin/imrm ${rawdir}/Neg
    ${FSLDIR}/bin/imrm ${rawdir}/Pos_b0
    ${FSLDIR}/bin/imrm ${rawdir}/Neg_b0
    ${FSLDIR}/bin/immv ${rawdir}/Posn ${rawdir}/Pos
    ${FSLDIR}/bin/immv ${rawdir}/Negn ${rawdir}/Neg
    ${FSLDIR}/bin/immv ${rawdir}/Pos_b0n ${rawdir}/Pos_b0
    ${FSLDIR}/bin/immv ${rawdir}/Neg_b0n ${rawdir}/Neg_b0
fi

printf "\n Perform final merge"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg_b0 ${rawdir}/Pos_b0 ${rawdir}/Neg_b0 
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg ${rawdir}/Pos ${rawdir}/Neg
paste ${rawdir}/Pos.bval ${rawdir}/Neg.bval >${rawdir}/Pos_Neg.bvals
paste ${rawdir}/Pos.bvec ${rawdir}/Neg.bvec >${rawdir}/Pos_Neg.bvecs

${FSLDIR}/bin/imrm ${rawdir}/Pos
${FSLDIR}/bin/imrm ${rawdir}/Neg


################################################################################################
## Move files to appropriate directories 
################################################################################################
printf "\n Move files to appropriate directories"
mv ${rawdir}/extractedb0.txt ${topupdir}
mv ${rawdir}/acqparams.txt ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Neg_b0 ${topupdir}

cp ${topupdir}/acqparams.txt ${eddydir}
mv ${rawdir}/index.txt ${eddydir}
mv ${rawdir}/series_index.txt ${eddydir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg ${eddydir}
mv ${rawdir}/Pos_Neg.bvals ${eddydir}
mv ${rawdir}/Pos_Neg.bvecs ${eddydir}
mv ${rawdir}/Pos.bv?? ${eddydir}
mv ${rawdir}/Neg.bv?? ${eddydir}

echo -e "\n END: basic_preproc"
