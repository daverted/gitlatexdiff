#!/bin/bash

#############################################
#  Dave Snyder                              #
#  daverted@gmail.com                       #
#  https://github.com/daverted/gitlatexdiff #
#############################################
set -e

# Variables
verbose=false
true=0 # functions like to return numbers
false=1 # bash likes these to be backward
usage="Usage: $0 [-v|--verbose] [-b|--bibtex] [-q|--quiet] [-x|--no-open] file.tex"
pdflatexCommand="pdflatex --file-line-error"
bibtexCommand="bibtex"
noOpen=false

# Errors
ERROR_MISSING=400
ERROR_PERMISSIONS=401
ERROR_DEPENDENCY=402
ERROR_NUMARGS=403
ERROR_BADARGS=404

# Success
NO_DIFFERENCE=200
DIFF_CREATED=100

# Helper Functions

# $1 is the file or folder to check for rwx permissions
function userHasPermissions() {

    # exit if the file doesn't exist
    if [ ! -e $1 ]
    then
    printf "Error: The file '$1' is missing.\n" >&2
    exit $ERROR_MISSING
    fi

    # use sed to get first line for directories
    if [ -d $1 ]
    then
        filePermissions=`ls -la $1 | sed -n 2p | awk '{print $1}'`
        fileUser=`ls -la $1 | sed -n 2p | awk '{print $3}'`
    else
        filePermissions=`ls -la $1 |  awk '{print $1}'`
        fileUser=`ls -la $1 | awk '{print $3}'`
    fi

    # if working directory permissions are $2 in the first position (user)
    if [[ ${filePermissions:1:3} == $2 && $fileUser == `whoami` ]]
    then
        if $verbose; then printf "\tuser permissions passed\n"; fi
        return $true
    else
        if $verbose; then printf "\tuser permissions failed\n"; fi
        return $false
    fi  
}

# $1 is the file or folder to check for $2 permissions
function groupHasPermissions() {
    
    # exit if the file doesn't exist
    if [ ! -e $1 ]
    then
        printf "Error: The file '$1' is missing.\n" >&2
        exit $ERROR_MISSING
    fi
    
    # use sed to get first line for directories
    if [ -d $1 ]
    then
        filePermissions=`ls -la $1 | sed -n 2p | awk '{print $1}'`
        fileGroup=`ls -la $1 | sed -n 2p | awk '{print $4}'`
    else
        filePermissions=`ls -la $1 | awk '{print $1}'`
        fileGroup=`ls -la $1 | awk '{print $4}'`
    fi
    
    # if working directory permissions are rwx in the second position (group)
    if [[ ${filePermissions:4:3} == $2 ]]
    then
        # loop all groups, return true on working directory group
        for i in `groups`
        do
            if [ $fileGroup == $i ]
            then
                if $verbose; then printf "\tgroup permissions passed\n"; fi
                return $true
            fi  
        done
    fi

    if $verbose; then printf "\tgroup permissions failed\n"; fi
    return $false 
}

# $1 is the file or folder to check for $2 permissions
function worldHasPermissions() {
    
    # exit if the file doesn't exist
    if [ ! -e $1 ]
    then
        printf "Error: The file '$1' is missing.\n" >&2
        exit $ERROR_MISSING
    fi
    
    # use sed to get first line for directories
    if [ -d $1 ]
    then
        filePermissions=`ls -la $1 | sed -n 2p | awk '{print $1}'`
    else
        filePermissions=`ls -la $1 | awk '{print $1}'`
    fi


    # if working directory permissions are rwx in third position (world)
    if [[ ${filePermissions:7:3} == $2 ]]
    then
        if $verbose; then printf "\tworld permissions passed\n"; fi
        return $true
    else
        if $verbose; then printf "\tworld permissions failed\n"; fi
        return $false
    fi
}

# $1 is the file or folder to check for $2 permissions
function hasPermissions() {
    
    if $verbose; then printf "  hasRWX $1 $2\n"; fi
        
    if userHasPermissions $1 $2; then return $true;
    elif groupHasPermissions $1 $2; then return $true;
    elif worldHasPermissions $1 $2; then return $true;
    else
        # print error
        printf "Error: $0 requires $2 permissions" >&2
        printf " on the file '$1' to run.\n" >&2
        exit $ERROR_PERMISSIONS
    fi
}

function require() {
    if [ -z `which $1` ]
    then
        if $verbose; then printf "\t$1 is missing.\n"; fi
        # print error
        printf "Error: $0 cannot find '$1'. Make sure it's installed and" >&2
        printf " in your path. Usually $1 is located in $2. Try adding" >&2
        printf " export PATH=\$PATH:$2 to your ~/.bashrc and restarting" >&2
        printf " your terminal session.\n"
        exit $ERROR_DEPENDENCY
    fi
    
    if $verbose; then printf "\t$1 found\n"; fi    
    return $true
}

function _run() {
    # Hello World ##########################
    if $verbose; then printf "$0 running as `whoami`\n"; fi

    # Preflight Check  #####################
    if $verbose; then printf "Preflight Check...\n"; fi

    # -- permissions
    if $verbose; then printf "Permissions:\n"; fi
    hasPermissions `pwd` rwx
    hasPermissions $1 r*
    
    # -- dependencies
    if $verbose; then printf "Dependencies:\n"; fi
    require git /usr/local/git/bin/git
    require patch /usr/bin
    require pdflatex /usr/texbin
    require latexdiff /usr/texbin
    require bibtex /usr/texbin/bibtex
    
    # Liftoff! ############################
    if $verbose; then printf "Litoff!\n"; fi
    
    filebase=`basename "$1"`
    ext="${filebase##*.}"
    filename="${filebase%.*}"    
    
    if [ $quiet ]
    then 
        if $verbose; then printf "\tquiet mode enabled\n"; fi
        pdflatexCommand="$pdflatexCommand $filename.ldiff.$ext > /dev/null"
        bibtexCommand="$bibtexCommand $filename.ldiff.aux > /dev/null"
    else
        if $verbose; then printf "\tquiet mode disabled\n"; fi
        pdflatexCommand="$pdflatexCommand $filename.ldiff.$ext"
        bibtexCommand="$bibtexCommand $filename.ldiff.aux"
    fi
    
    if $verbose; then printf "\tgit diff\n"; fi
    git diff HEAD -- $filebase > $filename.gitdiff.$ext
    
    # check if there's a difference
    if [ ! -s $filename.gitdiff.$ext ]
    then
        rm $filename.gitdiff.$ext
        printf "Nothing to do for file: '$1'\n"
        exit $NO_DIFFERENCE
    fi

    if $verbose; then printf "\tdiff patch\n"; fi
    patch $filebase -R -i $filename.gitdiff.$ext -o $filename.patch.$ext > /dev/null
    
    if $verbose; then printf "\tlatexdiff\n"; fi
    latexdiff $filename.patch.$ext $filebase > $filename.ldiff.$ext

    if $verbose; then printf "\tpdflatex diff file (first pass)\n"; fi
    eval $pdflatexCommand

    if [ $enableBibtex ]
    then
        if $verbose; then printf "\tbibtex diff file\n"; fi
        eval $bibtexCommand
        
        if $verbose; then printf "\tpdflatex diff file (bibtex pass)\n"; fi
        eval $pdflatexCommand
    fi

    if $verbose; then printf "\tpdflatex diff file (second pass)\n"; fi
    eval $pdflatexCommand
    
    #clean up
    rm $filename.gitdiff.$ext
    rm $filename.patch.$ext
    rm $filename.ldiff.aux
    rm $filename.ldiff.log
    rm $filename.ldiff.out
    if [ $enableBibtex ]
    then
        rm $filename.ldiff.bbl
        rm $filename.ldiff.blg
    fi
    
    #if Mac; open pdf
    if [ `uname` != 'Darwin' -o $noOpen == true ]
    then 
        # do nothing
        eval "echo \"do nothing\" > /dev/null"
    else
        if $verbose; then printf "\topening pdf\n"; fi
        open $filename.ldiff.pdf
    fi
    
    printf "Created $filename.ldiff.$ext and $filename.ldiff.pdf\n"
    exit $DIFF_CREATED
} 

# Require more than zero arguments
if [ $# -eq 0 ]; then echo $usage; exit $ERROR_NUMARGS; fi

# Require more than two arguments if flags are set
if [ ${1:0:1} == "-" -a $# -le 1 ]; then echo $usage; exit $ERROR_NUMARGS; fi

## TODO: create init function that runs many checks once when given multiple
## input files

# Parse command line arguments
for i in "$@"
do
    case "$i" in
        -v|--verbose) verbose=true
            ;;
        -b|--bibtex) enableBibtex=true
            ;;
        -q|--quiet) quiet=true
            ;;
        -x|--no-open) noOpen=true
            ;;
        -*) echo $usage; exit $ERROR_BADARGS;
            ;;
        *) _run $i
            ;;    
    esac
done