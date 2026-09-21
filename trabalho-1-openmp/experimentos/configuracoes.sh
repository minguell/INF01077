#!/usr/bin/env bash
# Configuração dos experimentos locais no notebook.

# Número de execuções independentes de cada combinação medida.
REPETITIONS=10

# O notebook possui um processador híbrido. Use estes valores como rodada local
# e não interprete os resultados como equivalentes aos da Hype.
THREAD_COUNTS=(1 2 4 8)

# nome população bits gerações taxa_de_mutação seed
# Estes tamanhos privilegiam duração razoável no notebook e validação do fluxo.
INPUT_SETS=(
    "pequeno 1000 1000 100 0.001 42"
    "medio   2000 2000 100 0.0005 42"
    "grande  4000 2000 100 0.0005 42"
)
