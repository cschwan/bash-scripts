#!/bin/bash

set -euo pipefail

if [[ ! -z ${1+x} ]]; then
    if [[ -d $1 ]]; then
        cd "$1"
    fi
fi

# from https://unix.stackexchange.com/a/174818
tmpdir=$(dirname $(mktemp tmp.XXXXXXXXXX -ut))

# download the following file *only* if we don't already have it
wget 'http://mirrors.ctan.org/graphics/axodraw/axodraw.sty' -P "${tmpdir}" --no-clobber

tmp=$(mktemp -d)

cp feynman_diagrams_survey.tex "${tmpdir}"/axodraw.sty "${tmp}"/
cd "${tmp}"
latexmk -ps feynman_diagrams_survey
xdg-open feynman_diagrams_survey.pdf
