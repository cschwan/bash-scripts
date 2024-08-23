#!/bin/bash

set -euo pipefail

# determine which workload manager we'll use
case ${HOSTNAME} in
    julia)
        workload_manager=SLURM
        ;;
    matrix*)
        workload_manager=SGE
        ;;
    *)
        echo "error: unknown cluster, please set 'workload_manager' in script manually"
        exit 1
        ;;
esac

# if there are arguments to the script, assume this are the run IDs of the jobs
# we shall run. Otherwise read them from the run card, which is assumed to be
# in the 'cards' directory in the same folder as this script
if [[ $# -gt 0 ]]; then
    run_ids=( "$@" )
else
    readarray -t run_ids < <(sed -n 's/[[:space:]]*<[[:space:]]*run[[:space:]]*id[[:space:]]*=[[:space:]]*"\([^"]*\)"[[:space:]]*>/\1/p' cards/run_card.xml | sort -n)

    if [[ ${#run_ids[@]} -eq 0 ]]; then
        echo "error: no run ids in 'cards/run_card.xml' found"
        exit 1
    fi
fi

workload_manager=SLURM
mocanlo_path=~/MoCaNLO/MoCaNLO/bin/mocanlo
h_vmem=1G
h_rt=36:00:00
name=mocanlo
seed=${RANDOM}
jobname=${name}-${seed}

jobscript=${name}-${seed}.sh

cat <<EOF
workload_manager: ${workload_manager}
mocanlo_path:     ${mocanlo_path}
name:             ${name}
seed:             ${seed}
jobname:          ${jobname}
run_ids:          ${run_ids[@]}
EOF

cat > "${jobscript}" <<EOF
#!/bin/bash

set -euo pipefail

# each workload manager has a different name for the task IDs that make up an
# array job
case ${workload_manager} in
    SLURM)
        task_id=\${SLURM_ARRAY_TASK_ID}
        ;;
    SGE)
        task_id=\${SGE_TASK_ID}
        ;;
esac

# copy the array into the jobscript
run_ids=( ${run_ids[@]} )

# SGE's task IDs always start at 1 and must be consecutive, but our run IDs can
# start anywhere and are not necessarily consecutive. To fix this problem, we
# use the array above as a map
run=\${run_ids[\$(( \${task_id} - 1 ))]}

# redirect stdout and stderr to a file containing the run id
exec &> stdouterr-\$(printf '%03d' \${run})-${seed}

"${mocanlo_path}" . \${run} ${seed}
EOF

case ${workload_manager} in
    SLURM)
        # TODO: SLURM's `--mem-per-cpu` and SGE's `h_vmem` aren't the same
        sbatch \
            -D "$(pwd)" \
            -e /dev/null \
            --mem-per-cpu ${h_vmem} \
            -t ${h_rt} \
            -J ${jobname} \
            -o /dev/null \
            -a 1-${#run_ids[@]} \
            -c 2 \
            "${jobscript}"
        ;;
    SGE)
        qsub \
            -cwd \
            -e /dev/null \
            -l h_vmem=${h_vmem} \
            -l h_rt=${h_rt} \
            -N ${jobname} \
            -o /dev/null \
            -S /bin/bash \
            -t 1-$(( ${#run_ids[@]} )) \
            "${jobscript}"
        ;;
    *)
        echo "error: unknown workload manager, didn't start any jobs"
        ;;
esac

rm "${jobscript}"
