#!/bin/bash

set -euo pipefail

if [[ ${#} != 4 ]]; then
    echo "usage: ${0} <GRID> <PDFSET> <OUTPUT> <P>"
    exit 1
fi

grid=${1}
pdfset=${2}
output=${3}
p=${4}

# read in bins limits - we assume they are one-dimensional!
pineappl read --bins "${grid}" | tail -n +3 > bins

values=$(python3 - <<EOF
import lhapdf
import numpy as np
import pandas as pd

df = pd.read_csv('bins', header = None, sep = '\s+')
# harmonic mean
p = ${p}.0
points = np.pow(df[[1, 2]].apply(lambda x: pow(x, p)).sum(axis=1) / 2, 1 / p)

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
