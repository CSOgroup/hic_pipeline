#!/bin/bash

SCRIPT_DIR="$(dirname $0)/src"
JUICER_SCRIPT="${SCRIPT_DIR}/juicer.sh"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup.sh"
N_THREADS=15
ALLOWED_CALDER_GENOMES="hg19 hg38 mm9 mm10"
CALDER_BINSIZE=50000
CONFIG_FILE=$1


parse_line(){
	local line=$1

	sample_path=$(echo $line | cut -d',' -f 1)
	raw_path=$(echo $line | cut -d',' -f 2)
	raw_path=$(realpath ${raw_path})
	restriction_enzyme=$(echo $line | cut -d',' -f 3)
	genome_assembly=$(echo $line | cut -d',' -f 4)
	genome_sequence=$(echo $line | cut -d',' -f 5)
	genome_sequence=$(realpath ${genome_sequence})
	chromsizes=$(echo $line | cut -d',' -f 6)
	chromsizes=$(realpath ${chromsizes})
}


prepare_sample_path(){
	mkdir -p ${sample_path}
	sample_path="$(realpath ${sample_path})"
	log_file=${sample_path}/log.txt
	>> ${log_file}
	fastq_dir="${sample_path}/fastq"
	mkdir -p ${fastq_dir}
	for f in `find "${raw_path}" -name "*.fastq*"`
	do
		if [[ ! -e ${fastq_dir}/$(basename ${f}) ]]; then 
			echo "Linking ${f} to ${fastq_dir}" | tee -a ${log_file}
			ln -s ${f} ${fastq_dir}/
		fi
	done
}

run_fastqc(){
	r1_path=$(ls -l ${fastq_dir}/*_R1_*.fastq* | awk 'NR==1{print $9}')
	r2_path=$(ls -l ${fastq_dir}/*_R2_*.fastq* | awk 'NR==1{print $9}')
	qc_path="${fastq_dir}/qc"
	if [[ ! -d ${qc_path} ]]; then
		mkdir -p ${qc_path}
		fastqc ${r1_path} ${r2_path} -o ${qc_path}
	fi
}

run_juicer(){
	if [ ! -f ${sample_path}/aligned/inter.hic ]; then
		echo "Running Juicer pipeline with the following parameters:"
		echo " - Sample path: ${sample_path}"
		echo " - Genome assembly: ${genome_assembly}"
		echo " - Genome sequence: ${genome_sequence}"
		echo " - Chromosome sizes: ${chromsizes}"
		echo " - Restriction enzyme: ${restriction_enzyme}"
		echo " - N. threads: ${N_THREADS}"
		${JUICER_SCRIPT} -d ${sample_path} \
						 -g ${genome_assembly} \
						 -p ${chromsizes} \
						 -s ${restriction_enzyme} \
						 -z ${genome_sequence} \
						 -t ${N_THREADS}
	fi
}

mcool(){	
	if [ ! -f ${sample_path}/aligned/inter_30.mcool ]; then
		echo "Converting ${sample_path}/aligned/inter_30.hic into mcool"
		hic2cool convert -r 0 ${sample_path}/aligned/inter_30.hic ${sample_path}/aligned/inter_30.mcool
	fi
}

clean(){
	# Cleaning unnecessary files to save space
	if [ -f ${sample_path}/aligned/merged_nodups.txt ]; then
		echo "Cleaning up Juicer files"
		${CLEANUP_SCRIPT} ${sample_path}
	fi
}

########## CALDER ##########

isIn(){
	element=$1
	list=$2
	for e in `echo ${list} | tr ' ' '\n'`
	do
		if [[ "${e}" == "${element}" ]]; then 
			return 0
		fi
	done
	return -1
}


isCalderDone(){
	path=$1
	if [[ ! -e ${path}/sub_compartments/all_sub_compartments.bed ]]; then
		return -1
	elif [[ ! -e ${path}/sub_domains/all_nested_boundaries.bed ]]; then
		return -1
	else
		return 0
	fi
}


compartments(){
	mkdir -p ${sample_path}/compartments
	calder_out_path="${sample_path}/compartments/calder"

	if isIn ${genome_assembly} $ALLOWED_CALDER_GENOMES && \
		! isCalderDone ${calder_out_path}; then

		calder --input ${sample_path}/aligned/inter_30.hic \
			   --type hic \
			   --bin_size ${CALDER_BINSIZE} \
			   --genome ${genome_assembly} \
			   --nproc ${N_THREADS} \
			   --outpath ${calder_out_path}
	fi
}

############################


if [[ -z ${CONFIG_FILE} ]]; then
	echo "Usage: $(basename $0) <config_file>"
	exit -1
fi


line_count=0
while read line
do
	# Skipping header
	line_count=$((line_count+1))
	if [[ ${line_count} -eq 1 ]]; then continue; fi
	parse_line ${line}
	prepare_sample_path
	run_fastqc | tee -a ${log_file}
	run_juicer | tee -a ${log_file}
	mcool | tee -a ${log_file}
	clean | tee -a ${log_file}
done < ${CONFIG_FILE}



