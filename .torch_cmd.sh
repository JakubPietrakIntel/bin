#!/bin/bash
torchLib=("pytorch" "pytorch_sparse" "pytorch_scatter" "pytorch_geometric" "pyg-lib")
declare -A torchGit=(["pytorch"]='https://github.com/pytorch/pytorch.git' ["pytorch_sparse"]='https://github.com/rusty1s/pytorch_sparse.git' ["pytorch_scatter"]='https://github.com/rusty1s/pytorch_scatter.git' ["pytorch_geometric"]='https://github.com/pyg-team/pytorch_geometric.git' ["pyg-lib"]='https://github.com/pyg-team/pyg-lib.git')

function ptsetup() {

	while true; do
		echo "Provide new env vars or press Enter to selected [default]"
		read -p "Full path to TORCH_DIR [$TORCH_DIR], i.e. /home/usr/pyg: " dir
		dir=${dir:-$TORCH_DIR}
		read -p "Name for conda env TORCH_ENV [$TORCH_ENV]: " env
		env=${env:-$TORCH_ENV}

		ptsetdir $dir
		ptsetenv $env

		read -p "Do you want to [U] update or [I] install new Pytorch Stack now? Press [Q] to exit. " uie
		case $uie in
		[Uu]*)
			ptupdate stack
			break
			;;
		[Ii]*)
			ptinstall stack
			break
			;;
		[Qq]*)
			echo "Quit"
			return 1
			;;
		*) echo "I don't know what to do. Valid options: [U]ptade / [I]nstall / [Q]uit" ;;
		esac
	done
}

function ptupdate() {

	if [[ $1 == "stack" ]]; then
		echo "*** ***** Updating full pytorch stack! ***** ***"
		for i in ${!torchLib[@]}; do ptupdate ${torchLib[$i]}; done
	else
		echo "*** ***** Updating torch repo in "$TORCH_DIR"/"$1" ***** ***"
		pttest
		conda activate $TORCH_ENV
		export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
		cd $TORCH_DIR/$1
		git pull origin master
		git submodule sync
		git submodule update --init --recursive
		python setup.py clean
		ptpip $1 --force-reinstall
		ptgitlog $1

		printf "%0.s-" {1..10} && echo " UPDATE COMPLETED!"
		cd ~

	fi
}

function ptinstall() {

	if [[ $1 == "stack" ]]; then
		echo "*** ***** Updating full pytorch stack! ***** ***"
		for i in ${!torchLib[@]}; do ptinstall ${torchLib[$i]}; done

	else
		echo "*** ***** Installing torch repo in "$TORCH_DIR"/"$1" ***** ***"
		pttest
		conda activate $TORCH_ENV
		export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
		cd $TORCH_DIR
		git clone --recursive ${torchGit["$1"]}
		cd $TORCH_DIR/$1
		ptpip $1
		ptgitlog $1
		#git config --global --add safe.directory $TORCH_DIR/$1
		printf "%0.s-" {1..10} && echo " INSTALLATION COMPLETED!"
		cd ~
	fi

}

function pttest() {

	if [[ ! -z "$TORCH_ENV" ]]; then ptgetenv; else echo "TORCH_ENV not defined. Use ptsetenv <env_name> to define active torch environment."; fi
	if [[ ! -z "$TORCH_DIR" ]]; then ptgetdir; else echo "TORCH_DIR not defined. Use ptsetdir <dir_name> to define active torch installation directory."; fi

}

function ptpip() {
	if [[ $1 == "pytorch" ]]; then
		REL_WITH_DEB_INFO=false USE_CUDA=false python -m pip install --verbose -e . $2 >> ../install_${1}.log
	else
		python -m pip install --verbose -e . $2 >> ../install_${1}.log
	fi
}

function ptsetdir() {
	echo $1
	if [[ ! -d "$1" ]]; then
		while true; do
			read -p "$1 doesn't exist. Do you want to create it now? [y/n] " yn
			case $yn in
			[Yy]*)
				mkdir -p $1
				break
				;;
			[Nn]*) return 1 ;;
			*) echo "Please answer yes or no." ;;
			esac
		done
	fi
	export TORCH_DIR=$1
	ptgetdir
}

function ptgetdir() {
	cd $TORCH_DIR
	echo "Selected active TORCH_DIR=$TORCH_DIR"
}

function find_in_conda_env(){
    conda env list | grep "${@}" >/dev/null 2>/dev/null
}

function ptsetenv() {
	env="$(conda env list | grep -w $1 | cut -f1 -d' ' | xargs)"
	if [[ $env != $1 ]]; then
		while true; do
			read -p "$1 doesn't exist. Do you want to create a new conda env now? [y/n] " yn
			case $yn in
			[Yy]*)
				ptconda $1
				break
				;;
			[Nn]*) return 1 ;;
			*) echo "Please answer yes or no." ;;
			esac
		done
	fi
	export TORCH_ENV=$1
	ptgetenv
}

function ptgetenv() {
	conda activate $TORCH_ENV
	echo "Selected active TORCH ENV=$TORCH_ENV"
}

function ptconda() {
	echo "Creating new environment \"$1\" and installing required packages."
	yes | conda create -n $1 python=3.9
	conda activate $1
	conda info
	conda update -n base -c defaults conda
	conda install -y mkl=2022.0.1
	conda install -y mkl-include=2022.0.1
	conda install -y gcc_linux-64 gxx_linux-64
	conda install -y astunparse numpy ninja pyyaml cmake cffi typing_extensions future six requests dataclasses pandas pytest
	python -m pip install --upgrade setuptools
	python -m pip install ogb --no-deps
	python -m pip install psutil
}

function ptgitlog() {
	name=$1
	if [[ $name != 'pyg-lib' ]]; then
		short=${name:2}
	else
		short=$name
	fi
	printf "%0.s-" {1..10} && echo "$short Version: " && python -c "import $short; print($short.__version__)"
	cd $TORCH_DIR/$1
	printf "%0.s-" {1..10} && echo ' Git Log'
	git log -1
}
