#!/bin/bash


SCRIPT_DIR="$(dirname $0)"
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh"
MINICONDA_PATH="${HOME}/miniconda3"
ENVIRONMENT_PATH="${SCRIPT_DIR}/environment.yml"
ENVIRONMENT_NAME="hic_pipeline"


if ! command -v conda --version &> /dev/null
then
    wget ${MINICONDA_URL} -O conda.sh
    bash conda.sh -b -p ${MINICONDA_PATH}
    rm -f conda.sh
    ${MINICONDA_PATH}/bin/conda init bash
    

    echo "IMPORTANT: CLOSE THIS TERMINAL AND LOGIN AGAIN FOR THE CHANGES TO BE EFFECTIVE"
    echo "----> THEN RUN install_hic_pipeline.sh AGAIN <----"
    exit
fi

if conda info --envs | grep -q ${ENVIRONMENT_NAME}; then 
	echo "Environment ${ENVIRONMENT_NAME} already exists"
else 
	conda env create -f ${ENVIRONMENT_PATH}
fi

eval "$(conda shell.bash hook)"
conda activate ${ENVIRONMENT_NAME}