#!/usr/bin/env bash
# Coleta perfis do Algoritmo Genético com Intel VTune Profiler.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EXPERIMENTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR=$(cd "$EXPERIMENTS_DIR/.." && pwd)
source "$EXPERIMENTS_DIR/configuracoes.sh"

ANALYSIS=${1:-all}
INPUT_SET=${2:-grande}
THREADS=${3:-8}
GENERATION_MULTIPLIER=${4:-5}
VTUNE_VARS=${VTUNE_VARS:-/home/intel/oneapi/vtune/2021.1.1/vtune-vars.sh}

usage() {
    cat <<'EOF'
Uso: ./experimentos_hype/vtune/coletar_vtune.sh [analise] [conjunto] [threads] [multiplicador_geracoes]

analise: snapshot, hotspots, hpc ou all (padrão: all)
conjunto: nome definido em experimentos_hype/configuracoes.sh (padrão: grande)
threads: quantidade de threads OpenMP (padrão: 8)
multiplicador_geracoes: prolonga apenas a execução perfilada (padrão: 5)

Exemplo:
  ./experimentos_hype/vtune/coletar_vtune.sh all grande 8 5
EOF
}

if [[ "$ANALYSIS" == "-h" || "$ANALYSIS" == "--help" ]]; then
    usage
    exit 0
fi

case "$ANALYSIS" in
    snapshot|hotspots|hpc|all) ;;
    *)
        echo "Erro: análise inválida: $ANALYSIS" >&2
        usage >&2
        exit 1
        ;;
esac

if ! [[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || ! [[ "$GENERATION_MULTIPLIER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Erro: threads e multiplicador de gerações devem ser inteiros positivos." >&2
    exit 1
fi

population=""
bits=""
generations=""
mutation_rate=""
seed=""
for input in "${INPUT_SETS[@]}"; do
    read -r name candidate_population candidate_bits candidate_generations candidate_mutation candidate_seed <<< "$input"
    if [[ "$name" == "$INPUT_SET" ]]; then
        population=$candidate_population
        bits=$candidate_bits
        generations=$candidate_generations
        mutation_rate=$candidate_mutation
        seed=$candidate_seed
        break
    fi
done

if [[ -z "$population" ]]; then
    echo "Erro: conjunto '$INPUT_SET' não encontrado em configuracoes.sh." >&2
    exit 1
fi

if ! command -v vtune >/dev/null; then
    if [[ -f "$VTUNE_VARS" ]]; then
        # shellcheck disable=SC1090
        source "$VTUNE_VARS"
    else
        echo "Erro: VTune não está no PATH e o ambiente não foi encontrado em:" >&2
        echo "  $VTUNE_VARS" >&2
        echo "Defina VTUNE_VARS com o caminho correto do vtune-vars.sh na máquina de coleta." >&2
        exit 1
    fi
fi

if ! command -v vtune >/dev/null; then
    echo "Erro: o comando vtune continua indisponível após carregar o ambiente." >&2
    exit 1
fi

available_threads=$(getconf _NPROCESSORS_ONLN)
if (( THREADS > available_threads )); then
    echo "Erro: $THREADS threads excedem as $available_threads CPUs lógicas disponíveis." >&2
    exit 1
fi

profile_generations=$((generations * GENERATION_MULTIPLIER))
run_id="$(date +%Y%m%d_%H%M%S)_${INPUT_SET}_p${THREADS}_g${profile_generations}"
run_dir=${VTUNE_OUTPUT_DIR:-"$SCRIPT_DIR/resultados/$run_id"}

if [[ -e "$run_dir" ]]; then
    echo "Erro: o diretório de resultado já existe: $run_dir" >&2
    exit 1
fi

mkdir -p "$run_dir"
make -C "$PROJECT_DIR/ga_seq_paralelizado" all

{
    printf '# Coleta Intel VTune Profiler\n\n'
    printf -- '- Data: `%s`\n' "$(date -Iseconds)"
    printf -- '- Análise solicitada: `%s`\n' "$ANALYSIS"
    printf -- '- Conjunto base: `%s`\n' "$INPUT_SET"
    printf -- '- População: `%s`\n' "$population"
    printf -- '- Bits por indivíduo: `%s`\n' "$bits"
    printf -- '- Gerações do experimento de desempenho: `%s`\n' "$generations"
    printf -- '- Gerações perfiladas: `%s`\n' "$profile_generations"
    printf -- '- Taxa de mutação: `%s`\n' "$mutation_rate"
    printf -- '- Seed: `%s`\n' "$seed"
    printf -- '- Threads: `%s`\n' "$THREADS"
    printf -- '- Variáveis OpenMP: `OMP_DYNAMIC=FALSE`, `OMP_PROC_BIND=true`, `OMP_PLACES=cores`\n'
    printf -- '- VTune: `%s`\n' "$(vtune -version | head -n 1)"
    printf '\nA multiplicação de gerações existe apenas para obter uma duração adequada de amostragem. Estes resultados não devem substituir os tempos usados nos gráficos de speedup.\n'
} > "$run_dir/metadados.md"

"$EXPERIMENTS_DIR/coletar_ambiente.sh" "$run_dir/ambiente.md" "antes da coleta VTune"

collect_analysis() {
    local label=$1
    local vtune_analysis=$2
    local result_dir="$run_dir/$label"
    local report_file="$result_dir/resumo.txt"
    local command=(vtune -collect "$vtune_analysis" -result-dir "$result_dir")

    if [[ "$label" == "hotspots" ]]; then
        command+=(-knob sampling-mode=sw)
    fi

    command+=(-- "$PROJECT_DIR/ga_seq_paralelizado/ga_seq_paralelizado"
              "$population" "$bits" "$profile_generations" "$mutation_rate" "$seed")

    printf '\n## Comando: %s\n\n```bash\n' "$label" >> "$run_dir/metadados.md"
    printf 'OMP_NUM_THREADS=%q OMP_DYNAMIC=FALSE OMP_PROC_BIND=true OMP_PLACES=cores ' "$THREADS" >> "$run_dir/metadados.md"
    printf '%q ' "${command[@]}" >> "$run_dir/metadados.md"
    printf '\n```\n' >> "$run_dir/metadados.md"

    echo "Coletando $label..."
    OMP_NUM_THREADS="$THREADS" OMP_DYNAMIC=FALSE OMP_PROC_BIND=true OMP_PLACES=cores "${command[@]}"

    vtune -report summary -result-dir "$result_dir" > "$report_file"
    if [[ "$label" == "hotspots" ]]; then
        vtune -report hotspots -result-dir "$result_dir" -group-by function > "$result_dir/hotspots_por_funcao.txt"
    fi
}

case "$ANALYSIS" in
    snapshot)
        collect_analysis snapshot performance-snapshot
        ;;
    hotspots)
        collect_analysis hotspots hotspots
        ;;
    hpc)
        collect_analysis hpc hpc-performance
        ;;
    all)
        collect_analysis snapshot performance-snapshot
        collect_analysis hotspots hotspots
        collect_analysis hpc hpc-performance
        ;;
esac

"$EXPERIMENTS_DIR/coletar_ambiente.sh" "$run_dir/ambiente.md" "depois da coleta VTune"
echo "Coleta concluída. Resultados salvos em: $run_dir"
