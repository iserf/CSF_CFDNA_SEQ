#!/bin/bash

#Input arguments
ID_T=$1
ID_N=$2
BAM_T=$3
home_dir=$4
classifier=$5
BED=$6

#Directories
work_dir=$home_dir/data/results/${ID_T}/variants/somaticseq
OUT_DIR=$work_dir/classify_variants
mkdir -p $OUT_DIR

#Files
BAM_DIR=$home_dir/data/results/${ID_T}/bam_ready
BAM_N=$home_dir/data/results/${ID_N}/bam_ready/${ID_N}.aligned.deduped.bam

#Resources
REFERENCE=$home_dir/reference/hg38/v0/Homo_sapiens_assembly38.fasta
classifier_SNV=$home_dir/reference/somaticseq_training/classifiers_in_use/${classifier}/*.SNV.classifier
classifier_INDEL=$home_dir/reference/somaticseq_training/classifiers_in_use/${classifier}/*.INDEL.classifier

#Single caller vcfs
mutect2=$work_dir/somaticseq_callers/MuTect2.vcf
varscan_snv=$work_dir/somaticseq_callers/VarScan2.snp.vcf
varscan_indel=$work_dir/somaticseq_callers/VarScan2.indel.vcf
vardict=$work_dir/somaticseq_callers/VarDict.vcf
strelka_snv=$work_dir/somaticseq_callers/Strelka/results/variants/somatic.snvs.vcf.gz
strelka_indel=$work_dir/somaticseq_callers/Strelka/results/variants/somatic.indels.vcf.gz
scalpel=$work_dir/somaticseq_callers/Scalpel.vcf 
octopus_snv=$work_dir/octopus/${ID_T}_octopus_calls.snv.vcf
octopus_indel=$work_dir/octopus/${ID_T}_octopus_calls.indel.vcf
muse=$work_dir/somaticseq_callers/MuSE.vcf
lofreq_snv=$work_dir/somaticseq_callers/LoFreq.somatic_final.snvs.vcf.gz
lofreq_indel=$work_dir/somaticseq_callers/LoFreq.somatic_final.indels.vcf.gz

##Script##

#SomaticSeq Prediction mode
docker run --rm -v ${home_dir}:${home_dir} -u $UID --memory 100G lethalfang/somaticseq:latest /bin/bash -c \
"somaticseq_parallel.py \
--output-directory  $OUT_DIR \
--genome-reference  $REFERENCE \
--inclusion-region  $BED \
--algorithm         xgboost \
--threads           1 \
--classifier-snv $classifier_SNV \
--classifier-indel $classifier_INDEL \
paired \
--tumor-bam-file    $BAM_DIR/$BAM_T \
--normal-bam-file   $BAM_N \
--tumor-sample $ID_T \
--normal-sample $ID_N \
--mutect2-vcf       $mutect2 \
--vardict-vcf       $vardict \
--varscan-snv       $varscan_snv \
--varscan-indel     $varscan_indel \
--strelka-snv       $strelka_snv \
--strelka-indel     $strelka_indel \
--scalpel-vcf $scalpel \
--muse $muse \
--lofreq-snv $lofreq_snv \
--lofreq-indel $lofreq_indel \
--arbitrary-snvs $octopus_snv \
--arbitrary-indels $octopus_indel"
wait

grep -v "REJECT" $OUT_DIR/SSeq.Classified.sSNV.vcf > $OUT_DIR/SSeq.Classified.sSNV.pass.vcf
grep -v "REJECT" $OUT_DIR/SSeq.Classified.sINDEL.vcf > $OUT_DIR/SSeq.Classified.sINDEL.pass.vcf