#!/bin/bash

ENVIRONMENT_NAME="hic_pipeline"
CONFIG_FILE=$1
SCRIPT_DIR="$(dirname $0)/src"
MEGA_SCRIPT="${SCRIPT_DIR}/mega.sh"

parse_line(){
	local line=$1

	sample_path=$(echo $line | cut -d',' -f 1)
	restriction_enzyme=$(echo $line | cut -d',' -f 2)
	genome_assembly=$(echo $line | cut -d',' -f 3)
	chromsizes=$(echo $line | cut -d',' -f 4)
	chromsizes=$(realpath ${chromsizes})
	replicate_paths=$(echo $line | cut -d',' -f 5)
}

create_merge_path(){
	mkdir -p ${sample_path}
	sample_path="$(realpath ${sample_path})"
	log_file=${sample_path}/log.txt
	> ${log_file}
}

prepare_merge_path(){
	for rpath in `echo ${replicate_paths} | tr ':' '\n'`
	do
		rname=$(basename ${rpath})
		rlink="${sample_path}/${rname}"
		if [[ ! -e ${rlink} ]]; then
			ln -s $(realpath ${rpath}) ${rlink}
		fi
	done
}

run_mega(){
	if [[ ! -d ${sample_path}/mega ]]; then
		${MEGA_SCRIPT} -g ${chromsizes} -z ${genome_assembly} -d ${sample_path} -s ${restriction_enzyme}
	fi
	# move mega folder upwards
	mv ${sample_path}/mega/* ${sample_path}
	# remove debug folder
	rm -rf ${sample_path}/debug
	# remove mega folder
	rm -rf ${sample_path}/mega
	# remove symbolic links
	for rpath in `echo ${replicate_paths} | tr ':' '\n'`
	do
		rname=$(basename ${rpath})
		rlink="${sample_path}/${rname}"
		rm ${rlink}
	done
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



if [[ -z ${CONFIG_FILE} ]]; then
	echo "Usage: $(basename $0) <config_file>"
	exit -1
fi

eval "$(conda shell.bash hook)"
conda activate ${ENVIRONMENT_NAME}

line_count=0
while read line
do
	# Skipping header
	line_count=$((line_count+1))
	if [[ ${line_count} -eq 1 ]]; then continue; fi
	parse_line ${line}
	create_merge_path
	if [[ ! -e ${sample_path}/aligned/inter_30.hic ]]; then 
		prepare_merge_path | tee -a ${log_file}
		run_mega | tee -a ${log_file}
	fi
	mcool | tee -a ${log_file}
	clean | tee -a ${log_file}
done < ${CONFIG_FILE}