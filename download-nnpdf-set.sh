#!/bin/bash

set -euo pipefail

if [[ ${#} != 2 ]]; then
    echo "Usage: ${0} <PDFID> <LHAPDF-DIRECTORY>"
    exit 1
fi

if [[ ! -d ${2} ]]; then
    echo "${2} is not a directory"
    exit 1
fi

tmp=$(mktemp -d)
cd "${tmp}"

wget "https://data.nnpdf.science/fits/${1}.tar.gz" -O- | tar xzf -
cd "${1}"/postfit

# important: resolve all symbolic links when copying the PDFs
cp -rL "${1}" "${2}"/

# cleanup
cd - >/dev/null
rm -r "${tmp}"
