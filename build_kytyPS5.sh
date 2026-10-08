#!/usr/bin/env zsh

# ANSI color codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

# This gets the location that the script is being run from and moves there.
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

set_vars() {
	echo "setting vars"
	if [ -d ~/Qt ]; then
		Qt6_DIR=$(echo ~/Qt/6*/macos/lib/cmake/Qt6)
		Qt6_VER=${Qt6_DIR#"$HOME/Qt/"}
		Qt6_VER=${Qt6_VER%%/*}
	fi
	DEPS=( cmake ninja glslang )
	Qt6_DIR="~/Qt/$Qt6_VER/macos/lib/cmake/Qt6"
	MVK_VERSION="1.4.2"
	ICON_URL="https://s3-new.macosicons.com/macosicons/parse/PlayStation__Dark__sWaM0BYXEG_icns-20d69fe4b7.icns"
}

introduction() {
	echo "\n${PURPLE}This script is for compiling ${GREEN}KytyPS5${PURPLE}"
	if [ ! -d ~/Qt ]; then
		echo "\n${RED}Qt 6 has not been detected"
		echo "\n${PURPLE}For this script to work, you must install the Univeral Binary version of Qt 6 to your home folder"
		echo "\n${PURPLE}If you install to another location then update the 'Qt6_DIR' variable at the top of this script"
		echo "\n${RED}The Homebrew version of Qt is Arm64-only and will not work"
		echo "\n${PURPLE}Download Qt from:"
		echo "${NC}https://www.qt.io/development/download-qt-installer-oss"
		exit 0
	fi
}

# Functions for checking for Homebrew installation
homebrew_check() {
	echo "${PURPLE}Checking for Homebrew...${NC}"
	if ! command -v brew &> /dev/null; then
		echo "${RED}Homebrew has not been detected${NC}\n"
		homebrew_install_menu
	else
		echo "${GREEN}Homebrew has been detected${NC}\n"
		homebrew_update_menu
	fi
}

homebrew_install_menu() {
	echo "${GREEN}Homebrew${PURPLE} and the ${GREEN}Xcode command-line tools${PURPLE} are required${NC}\n"
	echo "Would you like to install Homebrew? "
	PS3='Enter your selection: '
	OPTIONS=(
		"Install"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Install")
				install_homebrew
				dependencies_check
				break
				;;
			"Quit")
				echo "${PURPLE}The script cannot run without Homebrew${NC}"
				echo "${RED}Quitting${NC}"
				exit 0
				;;
			*)
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

homebrew_update_menu() {
	echo "${PURPLE}You may need to install or update Homebrew packages${NC}"
	echo "${PURPLE}It is recommended to perform this check if it your first time running the script${NC}\n"
	echo "Would you like to check dependencies?"
	PS3='Enter your selection: '
	OPTIONS=(
		"Continue without checking"
		"Install / Update")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Continue without checking")
				echo "\n${RED}Skipping Homebrew checks${NC}"
				echo "${PURPLE}The script will fail if any of the dependencies are missing${NC}\n"
				break
				;;
			"Install / Update")
				update_homebrew
				dependencies_check
				break
				;;
			*)
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

install_homebrew() {
	echo "${PURPLE}Installing Homebrew...${NC}"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [[ "${ARCH}" == "arm64" ]]; then
		(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
		eval "$(/opt/homebrew/bin/brew shellenv)"
	else
		(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
		eval "$(/usr/local/bin/brew shellenv)"
	fi

	# Check for errors
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue installing Homebrew${NC}"
		echo "${PURPLE}Quitting script...${NC}"
		exit 1
	fi
}

update_homebrew() {
	echo "${PURPLE}Updating Homebrew...${NC}"
	brew update

	# Check for errors
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue updating Homebrew${NC}"
		echo "${PURPLE}Quitting script...${NC}"
		exit 1
	fi
}

# Function for checking for an individual dependency
single_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo "${GREEN}Found $1. Checking for updates...${NC}"
		brew upgrade $1
	else
		 echo "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

dependencies_check() {
	echo "${PURPLE}Checking for Homebrew dependencies...${NC}"
	for dep in $DEPS[@]
	do
		single_dependency_check $dep
	done
}

download_moltenvk() {
	echo "${PURPLE}Downloading MoltenVK...${NC}"
	curl -LO "https://github.com/KhronosGroup/MoltenVK/releases/download/v$MVK_VERSION/MoltenVK-macos.tar"
	tar -xf MoltenVK-macos.tar
	mv MoltenVK/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib .
	rm -rf MoltenVK
	rm MoltenVK-macos.tar
}

clone_repo() {
	echo "${PURPLE}Cloning Repository...${NC}"
	if [ ! -d "KytyPS5" ]; then
		git clone https://github.com/KytyPS5/KytyPS5
		cd KytyPS5
		git submodule update --init --recursive

	else
		echo "${PURPLE}Repository already exists${NC}"
		cd KytyPS5
		if [ -d "build" ]; then
			rm -rf build
		fi
		git pull origin main
		git submodule update --init --recursive
	fi

	# Check for errors
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue with the source code repository${NC}"
		echo "${PURPLE}Quitting script...${NC}"
		exit 1
	fi
}

main_menu() {
	echo "\n${PURPLE}Ready to build${NC}"
	echo "${PURPLE}You can modify the code now before building${NC}\n"
	echo "Would you like to continue building? "
	PS3='Enter your selection: '
	OPTIONS=(
		"Continue"
		"Checkout Commit"
		"Checkout Pull Request"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Continue")
				build
				cleanup_menu
				;;
			"Checkout Commit")
				checkout_commit_menu
				main_menu
				;;
			"Checkout Pull Request")
				checkout_pr_menu
				main_menu
				;;
			"Quit")
				echo "${RED}Quitting${NC}"
				exit 0
				;;
			*)
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

build() {
	# Configure build system
	echo "${PURPLE}Configuring build...${NC}"
	cmake . -B build \
	-DCMAKE_OSX_ARCHITECTURES=x86_64 \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_PREFIX_PATH="$Qt6_DIR" \
	-GNinja

	# Check for errors
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue configuring CMake${NC}"
		echo "${PURPLE}Quitting script...${NC}"
		exit 1
	fi

	# Build
	echo "${PURPLE}Building...${NC}"
	cmake --build build --target launcher --parallel
	cmake --install build --prefix build/install

	# Check whether the build was successful
	if [ $? -ne 0 ]; then
		echo "\n${RED}Building failed${NC}\n"
		exit 1
	fi
	
	cd $SCRIPT_DIR

	if [ -d KytyPS5.app ]; then
		rm -rf KytyPS5.app
	fi
	mv KytyPS5/build/install/KytyPS5.app .
	download_moltenvk
	mv libMoltenVK.dylib KytyPS5.app/Contents/Frameworks
	
	curl -o KytyPS5.app/Contents/Resources/KytyPS5.icns $ICON_URL
	sed -i '' $'8i\\\n\t<key>CFBundleIconFile</key><string>KytyPS5.icns</string>' KytyPS5.app/Contents/Info.plist
	
	echo "${PURPLE}Codesigning...${NC}"
	codesign --force --deep --preserve-metadata=entitlements,requirements,flags,runtime --sign - KytyPS5.app/Contents/MacOS/KytyPS5
}

checkout_commit_menu() {
	echo "\n${PURPLE}What commit would you like to checkout?${NC}"
	commit_hash=$(printf '%s' 'Commit Hash: ' >&2; read x && printf '%s' "$x")
	git checkout "$commit_hash"
	if [ $? -ne 0 ]; then
		echo "\n${RED}Could not find the specified commit${NC}\n"
		break
	fi
}

checkout_pr_menu() {
	echo "\n${PURPLE}What pull request would you like to checkout?${NC}"
	pr_id=$(printf '%s' 'Pull Request ID: ' >&2; read x && printf '%s' "$x")
	branch_name=$(printf '%s' 'New Branch Name: ' >&2; read x && printf '%s' "$x")
	git fetch origin pull/$pr_id/head:$branch_name
	if [ $? -ne 0 ]; then
		echo "\n${RED}Could not find the specified pull request${NC}\n"
		break
	fi
	git switch $branch_name
}

cleanup_menu() {
	echo "\n${GREEN}The script has completed${NC}"
	echo "\nWould you like to delete the source folder?"
	PS3='Enter your selection: '
	OPTIONS=(
		"Quit"
		"Delete")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Quit")
				echo "${PURPLE}Quitting${NC}"
				exit 0
				;;
			"Delete")
				echo "${PURPLE}Cleaning up${NC}"
				rm -rf KytyPS5
				exit 0
				;;
			*)
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

set_vars
introduction
homebrew_check
clone_repo
main_menu
