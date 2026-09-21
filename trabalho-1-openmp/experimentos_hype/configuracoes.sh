#!/usr/bin/env bash
# Configuração da coleta final na Hype.

# Número de execuções independentes de cada combinação medida.
REPETITIONS=10

# Ajuste conforme os núcleos físicos concedidos ao processo na Hype.
THREAD_COUNTS=(1 2 4 8)

# nome população bits gerações taxa_de_mutação seed
# Estes são pontos de partida. Recalibre-os em uma execução piloto na Hype
# até que a referência paralela com uma thread dure alguns segundos.
INPUT_SETS=(
    "pequeno 1000 1000 100 0.001 42"
    "medio   2000 2000 100 0.0005 42"
    "grande  4000 2000 100 0.0005 42"
)
