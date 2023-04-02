#!/bin/bash
#########
# Script to clean up big repetitive files and zip fastqs. Run after you are 
# sure the pipeline ran successfully.

hicpath=$1


total=`ls -l ${hicpath}/aligned/merged_sort.txt | awk '{print $5}'`
total2=`ls -l ${hicpath}/aligned/merged_nodups.txt ${hicpath}/aligned/dups.txt ${hicpath}/aligned/opt_dups.txt | awk '{sum = sum + $5}END{print sum}'`
if [ $total -eq $total2 ] 
then 
    rm ${hicpath}/aligned/merged_sort.txt 
    rm -r ${hicpath}/splits 
    # for i in ${hicpath}/fastq/*.fastq
    # do
    #     gzip $i
    # done
    gzip ${hicpath}/aligned/merged_nodups.txt
    gzip ${hicpath}/aligned/dups.txt
    gzip ${hicpath}/aligned/opt_dups.txt
    gzip ${hicpath}/aligned/abnormal.sam
    gzip ${hicpath}/aligned/collisions.txt
    gzip ${hicpath}/aligned/unmapped.sam
else 
    echo "Problem: The sum of merged_nodups and the dups files is not the same size as merged_sort.txt"
    echo "Did NOT clean up";
fi
