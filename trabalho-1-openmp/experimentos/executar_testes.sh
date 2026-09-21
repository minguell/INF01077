#!/usr/bin/env bash
# Executa a bateria de testes e salva todas as medições brutas em CSV.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/configuracoes.sh"

DATA_FILE=${DATA_FILE:-"$SCRIPT_DIR/dados/tempos.csv"}
ENVIRONMENT_FILE=${ENVIRONMENT_FILE:-"${DATA_FILE%.csv}_ambiente.md"}
OVERWRITE=${OVERWRITE:-0}

if [[ -e "$DATA_FILE" && "$OVERWRITE" != "1" ]]; then
    echo "O arquivo $DATA_FILE já existe. Use OVERWRITE=1 para substituí-lo." >&2
    exit 1
fi

if [[ -e "$ENVIRONMENT_FILE" && "$OVERWRITE" != "1" ]]; then
    echo "O arquivo $ENVIRONMENT_FILE já existe. Use OVERWRITE=1 para substituí-lo." >&2
    exit 1
fi

if ! command -v make >/dev/null || ! command -v awk >/dev/null; then
    echo "Erro: make e awk devem estar instalados." >&2
    exit 1
fi

available_threads=$(getconf _NPROCESSORS_ONLN)
for threads in "${THREAD_COUNTS[@]}"; do
    if (( threads > available_threads )); then
        echo "Aviso: $threads threads excedem as $available_threads CPUs lógicas disponíveis." >&2
    fi
done

mkdir -p "$(dirname "$DATA_FILE")"
if [[ "$OVERWRITE" == "1" ]]; then
    rm -f "$ENVIRONMENT_FILE"
fi
"$SCRIPT_DIR/coletar_ambiente.sh" "$ENVIRONMENT_FILE" "antes da coleta"
make -C "$PROJECT_DIR/ga_seq" all
make -C "$PROJECT_DIR/ga_seq_paralelizado" all

printf '%s\n' 'timestamp,version,input_set,population,bits,generations,mutation_rate,seed,threads,run,elapsed_seconds,best_fitness' > "$DATA_FILE"
declare -A expected_fitness

record_execution() {
    local version=$1
    local input_set=$2
    local population=$3
    local bits=$4
    local generations=$5
    local mutation_rate=$6
    local seed=$7
    local threads=$8
    local run=$9
    local executable=${10}
    local output elapsed best_fitness

    if [[ "$version" == "paralelizado" ]]; then
        output=$(OMP_NUM_THREADS="$threads" OMP_DYNAMIC=FALSE OMP_PROC_BIND=true OMP_PLACES=cores \
            "$executable" "$population" "$bits" "$generations" "$mutation_rate" "$seed")
    else
        output=$("$executable" "$population" "$bits" "$generations" "$mutation_rate" "$seed")
    fi

    elapsed=$(awk '/^Tempo:/ { print $2 }' <<< "$output")
    best_fitness=$(awk -F'[:/]' '/^Melhor fitness:/ { gsub(/ /, "", $2); print $2 }' <<< "$output")

    if [[ -z "$elapsed" || -z "$best_fitness" ]]; then
        echo "Erro: não foi possível interpretar a saída de $executable." >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi

    if [[ -n ${expected_fitness[$input_set]+defined} &&
          "${expected_fitness[$input_set]}" != "$best_fitness" ]]; then
        echo "Erro de correção: '$input_set' produziu fitness $best_fitness, mas o esperado era ${expected_fitness[$input_set]}." >&2
        exit 1
    fi
    expected_fitness[$input_set]=$best_fitness

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date -Iseconds)" "$version" "$input_set" "$population" "$bits" \
        "$generations" "$mutation_rate" "$seed" "$threads" "$run" \
        "$elapsed" "$best_fitness" >> "$DATA_FILE"
}

for input in "${INPUT_SETS[@]}"; do
    read -r input_set population bits generations mutation_rate seed <<< "$input"
    echo "Conjunto: $input_set ($population indivíduos, $bits bits, $generations gerações)"

    for run in $(seq 1 "$REPETITIONS"); do
        echo "  sequencial - repetição $run/$REPETITIONS"
        record_execution sequencial "$input_set" "$population" "$bits" "$generations" \
            "$mutation_rate" "$seed" 1 "$run" "$PROJECT_DIR/ga_seq/ga_seq"
    done

    for threads in "${THREAD_COUNTS[@]}"; do
        for run in $(seq 1 "$REPETITIONS"); do
            echo "  paralelo ($threads threads) - repetição $run/$REPETITIONS"
            record_execution paralelizado "$input_set" "$population" "$bits" "$generations" \
                "$mutation_rate" "$seed" "$threads" "$run" \
                "$PROJECT_DIR/ga_seq_paralelizado/ga_seq_paralelizado"
        done
    done
done

"$SCRIPT_DIR/coletar_ambiente.sh" "$ENVIRONMENT_FILE" "depois da coleta"
echo "Medições salvas em: $DATA_FILE"
echo "Ambiente registrado em: $ENVIRONMENT_FILE"
echo "Verificação de correção: fitness idêntico em todas as execuções de cada conjunto."
echo "Gere os gráficos com: python3 $SCRIPT_DIR/gerar_graficos.py $DATA_FILE"
