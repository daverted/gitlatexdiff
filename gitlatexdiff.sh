#!/bin/bash

#######################################
#  Dave Snyder                        #
#  daverted@gmail.com                 #
#######################################
set -e

# Variables
verbose=false
true=0 # functions like to return numbers
false=1 # bash likes these to be backward
requiredPermissions="rwx"

# Errors
ERROR_PERMISSIONS=401
ERROR_DEPENDENCY=402

# Helper Functions
function userHasRWX() {
    cwd=`pwd`
    if [ -r $cwd -a -w $cwd -a -x $cwd ]
    then
        if $verbose; then printf "\tuser permissions passed\n"; fi
        return $true
     else
         if $verbose; then printf "\tuser permissions failed\n"; fi
         return $false
     fi
}

function groupHasRWX() {
    
    # variables
    cwdPermissions=`ls -la | sed -n 2p | cut -d " " -f1`
    cwdGroup=`ls -la | sed -n 2p | cut -d " " -f6`
    
    # if working directory permissions are rwx in the second position (group)
    if [ ${cwdPermissions:4:3} == "rwx" ]
    then
        # loop all groups, return true on working directory group
        for i in `groups`
        do
            if [ $cwdGroup == $i ]
            then
                if $verbose; then printf "\tgroup permissions passed\n"; fi
                return $true
            fi  
        done
    fi

    if $verbose; then printf "\tgroup permissions failed\n"; fi
    return $false 
}

function worldHasRWX() {
    # variables
    cwdPermissions=`ls -la | sed -n 2p | cut -d " " -f1`

    # if working directory permissions are rwx in third position (world)
    if [ ${cwdPermissions:7:3} == "rwx" ]
    then
        if $verbose; then printf "\tworld permissions passed\n"; fi
        return $true
    else
        if $verbose; then printf "\tworld permissions failed\n"; fi
        return $false
    fi
}

function checkPermissions() {
    
    if userHasRWX; then return $true;
    elif groupHasRWX; then return $true;
    elif worldHasRWX; then return $true;
    else
        # print error
        printf "Whoops! $0 requires read, write, and execute" >&2
        printf " permissions in your working directory to run. \n" >&2
        printf "Try running: sudo chmod 755 .\n" >&2
        exit $ERROR_PERMISSIONS
    fi
}

function require() {
    if [ -z `which $1` ]
    then
        if $verbose; then printf "\t$1 is missing.\n"; fi
        # print error
        printf "Whoops! $0 cannot find $1. Make sure it's installed and" >&2
        printf " in your path. Usually $1 is located in $2. Try adding" >&2
        printf " export PATH=\$PATH:$2 to your ~/.bashrc and restarting" >&2
        printf " your terminal session.\n"
        exit $ERROR_DEPENDENCY
    fi
    
    if $verbose; then printf "\t$1 found\n"; fi    
    return $true
}

## NOTE: the function needs to be defined before it's used (higer up)
function _run() {
    # Hello World ##########################
    if $verbose; then printf "$0 running as `whoami`\n"; fi

    # Preflight Check  #####################
    if $verbose; then printf "Preflight Check...\n"; fi

    # -- permissions
    if $verbose; then printf "Permissions:\n"; fi
    checkPermissions
    
    # -- dependencies
    if $verbose; then printf "Dependencies:\n"; fi
    require git "/usr/local/git/bin/git"
    require patch "/usr/bin"
    require pdflatex "/usr/texbin"
    require latexdiff "/usr/texbin"
    
    # Liftoff! ############################
    if $verbose; then printf "Litoff! \n"; fi
    
} 

# Parse Command Line Arguments
if [ $# -eq 0 ]
then
    printf "Useage: $0 [-v|--verbose]\n"
    exit 0
fi
for i in "$@"
do
    case "$i" in
        -v|--verbose) verbose=true
            ;;
        ?|--help) printf "Useage: $0 [-v|--verbose]\n"
                  exit 0
                  ;;
        *) _run $i
          ;;    
    esac
done



# -- check input file
# check that the file exists and is readable