#!/bin/bash

set -euo pipefail

switch=0

lhs=()
rhs=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --with)
            switch=1
            shift
            ;;
        --*)
            echo >&1 "error: unkown switch: '$1'"
            exit 1
            ;;
        *)
            if [[ ${switch} -eq 0 ]]; then
                lhs+=( "$1" )
            else
                rhs+=( "$1" )
            fi
            shift
            ;;
    esac
done

function create_result_table() {
    for dir in "$@"; do
        awk 'NR == 26 { print $5, $7 }' "${dir}"/result/scale_factor_1/cross_section.dat
    done
}

function matrix_elements() {
    for dir in "$@"; do
        xs_file="${dir}"/result/scale_factor_1/cross_section.dat
        int_type=$(grep "Integration type" "${xs_file}" | awk '{ print $4 }')

        case "${int_type}" in
            born | virt | idip)
                section=partonic_process
                ;;
            real)
                section=real_process
                ;;
            *)
                echo >&1 "error: unknown integration type: '${int_type}'"
                exit 1
                ;;
        esac

        pp_file="${dir}"/data/init/user_input/user_input_partonic_process.dat

        incoming=$(awk "/begin ${section}/,/end ${section}/" "${pp_file}" | grep incoming | \
            awk '{ for (i = 3; i <= NF; ++i) { printf "%s ", $i }; printf "->" }')
        awk "/begin ${section}/,/end ${section}/" "${pp_file}" | grep outgoing | \
            awk "{ printf \"%s \", \"${incoming}\"; for (i = 3; i <= NF; ++i) { printf \"%s \", \$i }; printf \"(${dir})\\n\" }"
    done
}

readarray -t mes < <(matrix_elements "${lhs[@]}")

echo "LHS = ${mes[0]}"
for me in "${mes[@]:1}"; do
    echo "    + ${me}"
done

readarray -t mes < <(matrix_elements "${rhs[@]}")
echo "RHS = ${mes[0]}"
for me in "${mes[@]:1}"; do
    echo "    + ${me}"
done

echo "---"
echo

create_result_table "${lhs[@]}" > lhs
create_result_table "${rhs[@]}" > rhs

Rscript - <<'EOF'
options(scipen=-2)

lhs <- read.table('lhs')
rhs <- read.table('rhs')

lhs_sum <- sum(lhs$V1)
lhs_unc <- sqrt(sum(lhs$V2^2))
rhs_sum <- sum(rhs$V1)
rhs_unc <- sqrt(sum(rhs$V2^2))

pull <- (rhs_sum-lhs_sum)/sqrt(rhs_unc^2+lhs_unc^2)
rel_diff <- (rhs_sum/lhs_sum-1)*100

cat("LHS        [fb] : ", lhs_sum,  "\n", sep = "")
cat("LHS unc.   [fb] : ", lhs_unc,  "\n", sep = "")
cat("RHS        [fb] : ", rhs_sum,  "\n", sep = "")
cat("RHS unc.   [fb] : ", rhs_unc,  "\n", sep = "")
cat("pull        [σ] : ", pull,     "\n", sep = "")
cat("rel. diff.  [%] : ", rel_diff, "\n", sep = "")
EOF

rm lhs rhs
