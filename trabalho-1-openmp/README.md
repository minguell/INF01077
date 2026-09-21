# Algoritmo Genético OneMax com OpenMP

Este projeto implementa um Algoritmo Genético (AG) para o problema OneMax. Cada indivíduo é um vetor binário e seu fitness é a quantidade de bits iguais a `1`; portanto, o objetivo é chegar a um indivíduo composto apenas por `1`s.

O trabalho compara uma implementação sequencial com uma implementação OpenMP, mede escalabilidade para diferentes tamanhos de entrada e produz evidências para análise posterior no Intel VTune Profiler.

## Estrutura do projeto

| Caminho | Finalidade |
| --- | --- |
| `ga_seq/` | Implementação sequencial de referência. |
| `ga_seq_paralelizado/` | Implementação OpenMP. Avaliação e reprodução são paralelizadas. |
| `experimentos/` | Procedimento e resultados da rodada local no notebook. |
| `experimentos_hype/` | Procedimento final para Hype, incluindo coleta de VTune. |
| `ga_explicado.md` | Explicação conceitual do AG e do problema OneMax. |
| `planejamento_paralelismo.md` | Justificativa das decisões de paralelização. |
| `Trabalho1_OpenMP.pdf` | Enunciado do trabalho da disciplina. |

Cada implementação é modular: `main.c` trata argumentos, `ga.c` controla o ciclo de gerações, `population.c` inicializa e avalia indivíduos, `reproduction.c` implementa seleção/crossover/mutação e `rng.c` concentra o gerador pseudoaleatório. As interfaces ficam em `include/`.

## Requisitos

- GCC ou compilador C compatível com C11;
- `make`;
- suporte a OpenMP para a versão paralela;
- Bash e Python 3 para os scripts de experimento.

Os gráficos são SVG e o gerador usa somente a biblioteca padrão do Python.

## Compilação

Na raiz do projeto:

```bash
make -C ga_seq
make -C ga_seq_paralelizado
```

A versão paralela é compilada com `-fopenmp`. Ambas usam `-O2` para medir uma versão otimizada e `-g` para permitir a associação dos dados do VTune às funções e linhas do fonte.

Para remover arquivos compilados:

```bash
make -C ga_seq clean
make -C ga_seq_paralelizado clean
```

## Execução

```bash
./ga_seq/ga_seq [populacao] [bits] [geracoes] [mutacao] [seed]

OMP_NUM_THREADS=4 OMP_DYNAMIC=FALSE OMP_PROC_BIND=true OMP_PLACES=cores \
  ./ga_seq_paralelizado/ga_seq_paralelizado \
  [populacao] [bits] [geracoes] [mutacao] [seed]
```

| Argumento | Padrão | Significado |
| --- | ---: | --- |
| `populacao` | 1000 | Número de indivíduos por geração. |
| `bits` | 1000 | Tamanho binário de cada indivíduo. |
| `geracoes` | 200 | Número de ciclos de reprodução e avaliação. |
| `mutacao` | `1/bits` | Probabilidade de inverter cada bit de um filho. |
| `seed` | 42 | Semente determinística do AG. |

Os parâmetros são validados. São exigidos pelo menos dois indivíduos, dois bits e uma geração; a taxa de mutação deve pertencer ao intervalo `[0, 1]`.

## Correção e comparabilidade

Com os mesmos argumentos e seed, as versões sequencial e paralela usam a mesma população inicial e a mesma semente local para cada filho de cada geração. Assim, produzem o mesmo melhor fitness, independentemente da quantidade de threads OpenMP.

Essa propriedade é importante: a diferença de tempo entre as versões passa a refletir a execução sequencial ou paralela, e não trajetórias aleatórias diferentes do AG. O programa não encerra antes do número solicitado de gerações, mesmo que encontre a solução ótima, o que mantém o volume de trabalho previsível.

## Paralelização adotada

A dependência entre gerações impede paralelizar o laço principal do AG. O OpenMP é usado em dois laços regulares e independentes:

| Função | Trabalho distribuído | Diretiva | Motivo |
| --- | --- | --- | --- |
| `population_evaluate()` | Um indivíduo por iteração | `parallel for schedule(static)` | Cada thread escreve em uma posição exclusiva de `fitness`. |
| `population_reproduce()` | Um filho por iteração | `parallel for schedule(static)` | Cada thread lê a população atual e escreve em uma região exclusiva da próxima população. |

`schedule(static)` é apropriado porque todos os indivíduos têm o mesmo número de bits e cada filho percorre o mesmo número de posições. A semente local por filho evita disputa por um estado aleatório global.

## Experimentos de desempenho

Consulte [experimentos/README.md](experimentos/README.md) para a rodada local e [experimentos_hype/README.md](experimentos_hype/README.md) para a coleta final. No notebook:

```bash
./experimentos/executar_testes.sh
python3 experimentos/gerar_graficos.py experimentos/dados/tempos.csv
```

O primeiro comando grava tempos brutos e uma fotografia da máquina. O segundo calcula medianas, speedup de escalabilidade e eficiência, produzindo dois gráficos SVG por conjunto de entrada.

Os gráficos principais usam a versão paralela com uma thread como referência:

```text
S(p) = Tpar(1) / Tpar(p)
E(p) = S(p) / p
```

Isso garante `S(1) = 1` e `E(1) = 1`. O resumo também informa `Tseq / Tpar(p)` como comparação adicional com a referência sequencial, sem confundi-la com a métrica de escalabilidade.

## Execução na Hype

A Hype é o ambiente de computação de alto desempenho indicado pela disciplina. Antes de fazer a coleta final:

1. obtenha as instruções de acesso e confirme a máquina liberada para o grupo;
2. copie o projeto e compile diretamente na máquina de teste;
3. execute `lscpu` e escolha valores de `THREAD_COUNTS` que não ultrapassem os núcleos físicos disponíveis ao seu processo;
4. faça uma execução piloto e aumente o tamanho do conjunto até que a referência com uma thread dure alguns segundos;
5. rode a bateria final e gere novos CSVs, gráficos e registro de ambiente na própria Hype.

Os resultados já obtidos no notebook são úteis como validação inicial, mas não devem ser comparados diretamente aos resultados da Hype: processador, memória, frequência e número de núcleos são diferentes.

## VTune

Depois da coleta final na Hype, use [experimentos_hype/vtune/README.md](experimentos_hype/vtune/README.md). A automação disponível executa Performance Snapshot, Hotspots e HPC Performance Characterization e preserva metadados, ambiente e relatórios textuais junto aos resultados brutos.

## Editor

`compile_commands.json` e `.vscode/c_cpp_properties.json` informam ao IntelliSense do VS Code os diretórios de headers e a opção OpenMP corretos.
