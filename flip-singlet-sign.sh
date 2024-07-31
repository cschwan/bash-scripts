#!/bin/bash

set -euo pipefail

if [[ ${#} != 2 ]]; then
    echo >&2 "Usage: $0 <INPUT> <OUTPUT>"
    exit 1
fi

if [[ ! -f ${1} ]]; then
    echo >&2 "error: file '${1}' doesn't exist"
    exit 1
fi

if [[ -e ${2} ]]; then
    echo >&2 "error: file '${2}' already exists"
    exit 1
fi

tmpfile=$(mktemp -u --suffix .pineappl.lz4)

# rotate into the evolution basis
pineappl write --rotate-pid-basis=EVOL --split-channels --optimize "${1}" "${tmpfile}"

# read in the channel definition of the grid
readarray -t channels < <(pineappl read --channels "${tmpfile}" | tail -n +3)

arguments=()

for channel in "${channels[@]}"; do
    # parse each channel
    IFS=" ,()" read -r id factor _ a b <<<"${channel}"

    # `1`: keep the original sign, `-1`: flip the sign
    sign=1

    case "${a}" in
        # singlet
        100)
            # flip the sign
            sign=$(( sign * -1 ))
            ;;
        # singlet-like contributions
        103|108|115|124|135)
            ;;
        # valence
        200)
            ;;
        # valence-like contributions
        203|208|215|224|235)
            ;;
        # gluon and photon
        21|22)
            ;;
        *)
            echo >&2 "error: unknown PID '${a}'"
            ;;
    esac

    case "${b}" in
        # singlet
        100)
            # flip the sign
            sign=$(( sign * -1 ))
            ;;
        # singlet-like contributions
        103|108|115|124|135)
            ;;
        # valence
        200)
            ;;
        # valence-like contributions
        203|208|215|224|235)
            ;;
        # gluon and photon
        21|22)
            ;;
        *)
            echo >&2 "error: unknown PID '${b}'"
            ;;
    esac

    if [[ ${sign} -eq -1 ]]; then
        if [[ ${factor:0:1} = - ]]; then
            # remove sign
            factor=${factor#-}
        else
            # add sign
            factor="-${factor}"
        fi
    fi

    arguments+=( "--rewrite-channel" "${id}" "${factor} * (${a}, ${b})" )
done

# actually flip signs
pineappl write "${tmpfile}" "${2}" "${arguments[@]}"

# remove temporary file
rm "${tmpfile}"
