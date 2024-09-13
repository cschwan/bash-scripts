#!/bin/bash

set -euo pipefail

if [[ ${#} != 3 ]]; then
    echo "usage: ${0} <GRID> <PDFSET> <OUTPUT>"
    exit 1
fi

grid=${1}
pdfset=${2}
output=${3}

# read in bins limits - we assume they are one-dimensional!
pineappl read --bins "${grid}" | tail -n +3 > bins

values=$(python3 - <<EOF
import lhapdf
import pandas as pd

df = pd.read_csv('bins', header = None, sep = '\s+')
# harmonic mean
points = 2.0 / df[[1, 2]].apply(lambda x: 1.0 / x).sum(axis=1)

lhapdf.setVerbosity(0)

pdf = lhapdf.mkPDF('${pdfset}')
values = [1.0 / pdf.alphasQ(point) for point in points]
print(','.join("{}".format(value) for value in values))
EOF
)

rm bins

# divide out one power of alphas and correct the order definition to increase by one power of alphas
pineappl write \
    --scale-by-bin "${values}" \
    --rewrite-order 0 as1a1 \
    --rewrite-order 1 as2a1 \
    "${grid}" "${output}"

# compare
pineappl diff --ignore-orders "${grid}" "${output}" "${pdfset}"
