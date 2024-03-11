#!/bin/bash
set -e # stop script if there is an error
printf "\n START: DiffPreproc_rodent.sh \n"

# Preprocessing Pipeline for rodent diffusion MRI. Generates the "data" directory that can be used as input to fibre orientation estimation.
# Stamatios Sotiropoulos, Analysis Group, FMRIB Centre, 2013.
# Jenna Hanmer, CoNI Lab, University of Nottingham, 2021.
 

#Hard-Coded variables for the pipeline
b0dist=150     #Minimum distance in volumes between b0s considered for preprocessing
b0maxbval=250  #Volumes with a bvalue smaller than that will be considered as b0s

#ScriptsDir=$(dirname "$(readlink -f "$0")") #Absolute path where scripts are
ScriptsDir=/home/lpxjh11/Scripts

if [ "x$SGE_ROOT" = "x" ] ; then
    if [ -f /usr/local/share/sge/default/common/settings.sh ] ; then
	. /usr/local/share/sge/default/common/settings.sh
    elif [ -f /usr/local/sge/default/common/settings.sh ] ; then
	. /usr/local/sge/default/common/settings.sh
    fi
fi

make_absolute(){
    dir=$1;
    if [ -d ${dir} ]; then
	OLDWD=`pwd`
	cd ${dir}
	dir_all=`pwd`
	cd $OLDWD
    else
	dir_all=${dir}
    fi
    echo ${dir_all}
}



Usage() {
    echo ""
    echo "Usage: DiffPreproc_rodent dataLR1@dataLR2@..dataLRN dataRL1@dataRL2@...dataRLN OutputFolder EchoSpacing PhaseEncodingDir CombineMatchedFlag ParallelImaging_Factor SubjectT2Scan SubjectT2BrainMask"
    echo ""
    echo "For input filenames, if for a LR/RL (AP/PA) pair one of the two files are missing set the entry to EMPTY"
    echo "Output durectory will be {OutputFolder}/DiffusionPreproc. Please provide absolute path"
    echo "EchoSpacing should be in secs"
    echo "PhaseEncodingDir: 1 for LR/RL, 2 for AP/PA"
    echo "CombineMatchedFlag: 2 for including in the ouput all volumes uncombined,"
    echo "                    1 for including in the ouput and combine only volumes where both LR/RL (or AP/PA) pairs have been acquired," 
    echo "                    0 for including (uncombined) single volumes as well"
    echo "ParallelImaging_Factor: In-plane parallel imaging factor (set to 1 for No_Parallel_Imaging)"
    echo ""
    echo "SubjectT2Scan: Subject's anatomical scan generated in structural (T2) processing pipeline"
    echo ""
    echo ""
    echo "SubjectT2BrainMask: Subject's brain mask generated in structural (T2) processing pipeline"
    echo ""
    echo ""
    echo ""
    echo ""
    exit 1
}

[ "$1" = "" ] && Usage
if [ $# -ne 9 ]; then
    echo "Wrong Number of Arguments!"
    Usage
fi

OutputFolder=`make_absolute $3`
OutputFolder=`echo ${OutputFolder} | sed 's/\/$/$/g'` # replace / at end of line with nothing
echospacing=$4
PEdir=$5
CombineMatched=$6
PIFactor=$7
T2scan=$8 # T2 anatomical scan in subject space
BrainMask=$9 # T2 brain mask in subject space
printf "\n BrainMask="
echo ${BrainMask}

# ErrorHandling -check PEdir either LR/RL (1) or AP/PA (2)
if [ ${PEdir} -ne 1 ] && [ ${PEdir} -ne 2 ]; then
    echo ""
    echo "Wrong Input Argument! PhaseEncodingDir flag can be 1 or 2."
    echo ""
    exit 1
fi
 
outdir="${OutputFolder}/preproc"
if [ -d ${outdir} ]; then
    rm -rf ${outdir} # force deletion of current directory, sub directories and contents if already exists
fi
mkdir -p ${outdir} # make new one
echo " OutputDir is "${outdir}
mkdir ${outdir}/regMask
mkdir ${outdir}/rawdata
mkdir ${outdir}/topup
mkdir ${outdir}/eddy
mkdir ${outdir}/data
mkdir ${outdir}/logs

InputImages=`echo "$1"`
InputImages2=`echo "$2"`

printf "\n  Data Handling\n"
${ScriptsDir}/data_copy.sh ${outdir} ${InputImages} ${InputImages2} ${PEdir}

printf "\n  Basic Preprocessing\n"
${ScriptsDir}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval} ${PIFactor}

printf "\n  Queueing Topup\n"
${ScriptsDir}/run_topup_rodent.sh ${outdir}/topup

printf "\n  Registering structural brain mask to diffusion space\n"
hifib0=${outdir}/topup/hifib0.nii.gz
printf "\n hifib0="
echo ${hifib0}
${ScriptsDir}/regMask_str2diff.sh ${outdir}/regMask ${hifib0} ${T2scan} ${BrainMask}

printf "\n  Performing brain extraction on the hifi b0 using brain mask in diffusion space\n"
b0mask=${outdir}/regMask/hifib0_mask.nii.gz
${FSLDIR}/bin/fslmaths ${hifib0} -mul ${b0mask} ${outdir}/topup/nodif_brain.nii.gz
${FSLDIR}/bin/imcp ${b0mask} ${outdir}/topup/nodif_brain_mask.nii.gz

printf "\nCheck if topup provides a benefit"
${ScriptsDir}/post_topup_cc.sh ${outdir} ${T2scan} ${BrainMask}

printf "\n  Queueing Eddy\n"
${ScriptsDir}/run_eddy_rodent.sh ${outdir}/eddy 

printf "\n  Queueing Eddy PostProcessing\n"
${ScriptsDir}/eddy_postproc.sh ${outdir} ${CombineMatched}

printf "\n END: DiffPreproc_rodent.sh \n"
