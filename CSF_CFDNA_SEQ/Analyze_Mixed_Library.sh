#!/bin/bash

# Script to perform SNV/INDEL/CNV calling for a library prepared with the SureSelect XT HS2 DNA Reagent Kit
# Library preparation and sequencing should be performed according to the manufacturers protocol with the modifications recommended in my thesis
# This script starts with raw bcl files
#Raw data have to be arranged as the following:
#1. raw_data_drive: complete file path to sequencing data $Library folder
#2. Folder $Library containing the Run folder (output from Sequencer)
#3. run_name = Run folder name
#4. SampleSheet within the Run folder (template can be found here: /CSF_CFDNA_SEQ/reference/templates)
#5. Sample_list_PAIRED.txt within $Library Folder (template can be found here: /CSF_CFDNA_SEQ/reference/templates)
#5. Sample_list_SINGLE.txt within $Library Folder (template can be found here: /CSF_CFDNA_SEQ/reference/templates)

#Arguments
raw_data_drive=$1
Library=$2
run_name=$3
home_dir=$4

#Ressources
Sample_list_SINGLE=$raw_data_drive/$Library/Sample_list_SINGLE.txt
Sample_list_PAIRED=$raw_data_drive/$Library/Sample_list_PAIRED.txt
BED=$home_dir/reference/bed/NPHD2022A_3383431_Covered_adaptedChrom_padded_2_hg38.bed
BED2=NPHD2022A_3383431_Covered_adaptedChrom_padded_2_hg38
INTERVALS=$home_dir/reference/bed/NPHD2022A_3383431_Covered_adaptedChrom_padded_2_hg38.interval_list
classifier_PAIRED=classifier_DUPLEX
classifier_SINGLE=classifier_DUPLEX_single
results=$home_dir/data/results
work_dir=$home_dir/CSF_CFDNA_SEQ



######################
#####BCL-CONVERT######
######################

echo "RUN BCL convert for Library $Library with SampleSheet"
echo "Processing date:"
date

$work_dir/prepare_bam/bcl_convert.sh $raw_data_drive $Library $run_name
wait

######################
######Pipeline########
######################

######################
#######PAIRED#########
######################

#####Read in file as array###########
while IFS=$'\t' read -r -a myArray
do
 ID_T="${myArray[0]}"
 ID_N="${myArray[1]}"

 echo $ID_T
 echo $ID_N

 #cp files into WSL
 mkdir -p $results/$ID_T/fastq
 cp -r $raw_data_drive/$Library/fastq/${ID_T}*.fastq.gz $results/$ID_T/fastq
 mkdir -p $results/$ID_N/fastq
 cp -r $raw_data_drive/$Library/fastq/${ID_N}*.fastq.gz $results/$ID_N/fastq
 wait

 ###Prepare run scripts###
 OUT_DIR=$results/$ID_T
 mkdir -p $OUT_DIR/run_scripts

 #Deduplicate Tumor#
 touch $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 echo $work_dir/prepare_bam/run_preprocess_bam.sh $ID_T $BED DUPLEX $home_dir >> $OUT_DIR/run_scripts/${ID_T}.dedup.sh

 #Deduplicate Normal#
 touch $OUT_DIR/run_scripts/${ID_N}.dedup.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_N}.dedup.sh
 echo $work_dir/prepare_bam/run_preprocess_bam.sh $ID_N $BED HYBRID $home_dir >> $OUT_DIR/run_scripts/${ID_N}.dedup.sh

 #qc Tumor & Normal#
 touch $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh
 echo $work_dir/prepare_bam/run_sequencing_qc.sh $ID_T $INTERVALS $home_dir >> $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh
 echo 'wait' >> $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh
 echo $work_dir/prepare_bam/run_sequencing_qc.sh $ID_N $INTERVALS $home_dir >> $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh

 #Variant calling#
 touch $OUT_DIR/run_scripts/${ID_T}.${ID_N}.variant_calling.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.${ID_N}.variant_calling.sh
 echo $work_dir/Paired_samples/run_pipeline.sh $ID_T $ID_N $classifier_PAIRED $BED $home_dir >> $OUT_DIR/run_scripts/${ID_T}.${ID_N}.variant_calling.sh

 #CNV Kit#
 touch $OUT_DIR/run_scripts/${ID_T}.${ID_N}.cnvkit.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.${ID_N}.cnvkit.sh
 echo $work_dir/cnvkit/cnvkit.sh $ID_T $ID_N $BED2 $home_dir >> $OUT_DIR/run_scripts/${ID_T}.${ID_N}.cnvkit.sh

 chmod +x $OUT_DIR/run_scripts/*.sh
 wait

 ####Run Pipeline####

 date
 #Preprocess tumor bam
 $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 wait

 date
 #Preprocess normal bam
 $OUT_DIR/run_scripts/${ID_N}.dedup.sh
 wait

 date
 #variant calling
 $OUT_DIR/run_scripts/${ID_T}.${ID_N}.variant_calling.sh
 wait

 date
 #QC & CNVkit
 parallel ::: $OUT_DIR/run_scripts/${ID_T}.${ID_N}.qc.sh $OUT_DIR/run_scripts/${ID_T}.${ID_N}.cnvkit.sh
 wait

 #cp files back
 mkdir -p  $raw_data_drive/$Library/results
 mv $results/$ID_T $raw_data_drive/$Library/results
 mv $results/$ID_N $raw_data_drive/$Library/results
 wait


done < $Sample_list_PAIRED


######################
#######SINGLE#########
######################

#####Read in file as array###########
while IFS=$'\t' read -r -a myArray
do
 ID_T="${myArray[0]}"

 echo $ID_T

 #cp files into WSL
 mkdir -p $results/$ID_T/fastq
 cp -r $raw_data_drive/$Library/fastq/${CSF}*.fastq.gz $results/$ID_T/fastq
 wait
 
 ###Prepare run scripts###
 OUT_DIR=$results/$ID_T
 mkdir -p $OUT_DIR/run_scripts

 #Deduplicate Tumor#
 touch $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 echo $work_dir/prepare_bam/run_preprocess_bam.sh $ID_T $BED DUPLEX $home_dir >> $OUT_DIR/run_scripts/${ID_T}.dedup.sh

 #qc Tumor#
 touch $OUT_DIR/run_scripts/${ID_T}.qc.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.qc.sh
 echo $work_dir/prepare_bam/run_sequencing_qc.sh $ID_T $INTERVALS $home_dir >> $OUT_DIR/run_scripts/${ID_T}.qc.sh

 #Variant calling#
 touch $OUT_DIR/run_scripts/${ID_T}.variant_calling.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.variant_calling.sh
 echo $work_dir/Single_sample/run_pipeline.sh $ID_T $classifier_SINGLE $BED $home_dir >> $OUT_DIR/run_scripts/${ID_T}.variant_calling.sh

 #CNV Kit#
 touch $OUT_DIR/run_scripts/${ID_T}.cnvkit.sh
 echo '#!/bin/bash' > $OUT_DIR/run_scripts/${ID_T}.cnvkit.sh
 echo $work_dir/cnvkit/cnvkit_single.sh $ID_T $BED2 $home_dir >> $OUT_DIR/run_scripts/${ID_T}.cnvkit.sh

 chmod +x $OUT_DIR/run_scripts/*.sh
 wait

 ####Run Pipeline####

 date
 #Preprocess tumor bam
 $OUT_DIR/run_scripts/${ID_T}.dedup.sh
 wait

 date
 #variant calling
 $OUT_DIR/run_scripts/${ID_T}.variant_calling.sh
 wait

 date
 #QC & CNVkit
 parallel ::: $OUT_DIR/run_scripts/${ID_T}.qc.sh $OUT_DIR/run_scripts/${ID_T}.cnvkit.sh
 wait

 #cp files back
 mkdir -p  $raw_data_drive/$Library/results
 mv $results/$ID_T $raw_data_drive/$Library/results
 wait


done < $Sample_list_SINGLE