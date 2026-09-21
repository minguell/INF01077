#!/usr/bin/env bash
# Registra o ambiente de uma coleta de desempenho em um arquivo Markdown.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_FILE=${1:-"$SCRIPT_DIR/dados/ambiente_$(date +%Y%m%d_%H%M%S).md"}
STAGE=${2:-"registro manual"}

os_name="não identificado"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    os_name=${PRETTY_NAME:-$os_name}
fi

logical_online=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo "não identificado")
logical_total="não identificado"
physical_cores="não identificado"
cpu_model="não identificado"
sockets="não identificado"
cores_per_socket="não identificado"
threads_per_core="não identificado"

if command -v lscpu >/dev/null; then
    cpu_model=$(LC_ALL=C lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n 1)
    sockets=$(LC_ALL=C lscpu | sed -n 's/^Socket(s):[[:space:]]*//p' | head -n 1)
    cores_per_socket=$(LC_ALL=C lscpu | sed -n 's/^Core(s) per socket:[[:space:]]*//p' | head -n 1)
    threads_per_core=$(LC_ALL=C lscpu | sed -n 's/^Thread(s) per core:[[:space:]]*//p' | head -n 1)
    logical_total=$(LC_ALL=C lscpu | sed -n 's/^CPU(s):[[:space:]]*//p' | head -n 1)
    physical_cores=$(LC_ALL=C lscpu -p=CORE,SOCKET 2>/dev/null |
        awk -F, '!/^#/ { print $1 "," $2 }' | sort -u | wc -l | tr -d ' ')
fi

compiler=$(sed -n 's/^CC[[:space:]]*:= *//p' "$PROJECT_DIR/ga_seq/Makefile" | head -n 1)
compiler=${compiler:-gcc}
compiler_version="não identificado"
if command -v "$compiler" >/dev/null; then
    compiler_version=$("$compiler" --version | head -n 1)
fi

seq_cflags=$(sed -n 's/^CFLAGS[[:space:]]*:= *//p' "$PROJECT_DIR/ga_seq/Makefile" | head -n 1)
par_cflags=$(sed -n 's/^CFLAGS[[:space:]]*:= *//p' "$PROJECT_DIR/ga_seq_paralelizado/Makefile" | head -n 1)
par_ldflags=$(sed -n 's/^LDFLAGS[[:space:]]*:= *//p' "$PROJECT_DIR/ga_seq_paralelizado/Makefile" | head -n 1)

mkdir -p "$(dirname "$OUTPUT_FILE")"
if [[ -f "$OUTPUT_FILE" ]]; then
    printf '\n---\n\n' >> "$OUTPUT_FILE"
else
    printf '# Ambiente de execução dos experimentos\n' > "$OUTPUT_FILE"
fi

{
    printf '\n## Registro: %s\n\n' "$STAGE"
    printf -- '- Data e hora: `%s`\n' "$(date -Iseconds)"
    printf -- '- Host: `%s`\n' "$(hostname)"
    printf -- '- Sistema operacional: %s\n' "$os_name"
    printf -- '- Kernel: `%s`\n' "$(uname -srmo)"

    printf '\n### Processador\n\n'
    printf -- '- Modelo: %s\n' "${cpu_model:-não identificado}"
    printf -- '- Núcleos físicos: %s\n' "${physical_cores:-não identificado}"
    printf -- '- CPUs lógicas totais: %s\n' "${logical_total:-não identificado}"
    printf -- '- CPUs lógicas disponíveis ao processo: %s\n' "$logical_online"
    printf -- '- Soquetes: %s\n' "${sockets:-não identificado}"
    printf -- '- Núcleos por soquete: %s\n' "${cores_per_socket:-não identificado}"
    printf -- '- Threads por núcleo: %s\n' "${threads_per_core:-não identificado}"

    printf '\n### Compilação\n\n'
    printf -- '- Compilador: `%s`\n' "$compiler_version"
    printf -- '- Flags sequenciais: `%s`\n' "$seq_cflags"
    printf -- '- Flags paralelas: `%s`\n' "$par_cflags"
    printf -- '- Flags de ligação OpenMP: `%s`\n' "$par_ldflags"
    printf -- '- Afinidade usada pelo coletor: `OMP_DYNAMIC=FALSE`, `OMP_PROC_BIND=true`, `OMP_PLACES=cores`\n'

    printf '\n### Carga no momento do registro\n\n'
    printf -- '- Uptime e média de carga: `%s`\n' "$(uptime)"
    if [[ -r /proc/loadavg ]]; then
        printf -- '- `/proc/loadavg`: `%s`\n' "$(< /proc/loadavg)"
    fi
    if command -v free >/dev/null; then
        printf '\nMemória:\n\n```text\n'
        free -h
        printf '```\n'
    fi
    if command -v ps >/dev/null; then
        printf '\nProcessos com maior uso de CPU no instante do registro:\n\n```text\n'
        printf '%-8s %-16s %-22s %6s %6s\n' PID USUÁRIO PROCESSO '%CPU' '%MEM'
        ps -eo pid=,user=,comm=,%cpu=,%mem= --sort=-%cpu | head -n 10
        printf '```\n'
    fi
} >> "$OUTPUT_FILE"

echo "Ambiente registrado em: $OUTPUT_FILE"
