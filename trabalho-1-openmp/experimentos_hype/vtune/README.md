# Coletas com Intel VTune Profiler

Esta pasta guarda os resultados de perfilamento usados para explicar os gráficos de speedup e eficiência. O VTune não deve ser usado para produzir os tempos dos gráficos: a própria coleta de perfil introduz overhead.

## Preparação na Hype

Entre na máquina de coleta, vá à raiz do projeto e execute:

```bash
source /home/intel/oneapi/vtune/2021.1.1/vtune-vars.sh
vtune -version
```

Se o arquivo de ambiente estiver em outro local, informe-o por meio da variável `VTUNE_VARS`:

```bash
VTUNE_VARS=/caminho/para/vtune-vars.sh \
  ./experimentos_hype/vtune/coletar_vtune.sh --help
```

## Coleta recomendada

Os resultados de desempenho já coletados indicam que o conjunto `grande` com oito threads é um caso interessante para análise. A configuração padrão prolonga as 100 gerações desse conjunto para 500 durante o perfilamento. Isso faz a coleta por amostragem durar mais tempo, mas não muda os dados usados nos gráficos.

```bash
./experimentos_hype/vtune/coletar_vtune.sh all grande 8 5
```

Argumentos:

| Posição | Valores | Padrão | Finalidade |
| --- | --- | --- | --- |
| 1 | `snapshot`, `hotspots`, `hpc`, `all` | `all` | Escolhe uma ou todas as análises. |
| 2 | Nome de `INPUT_SETS` | `grande` | Define população, bits, gerações, mutação e seed. |
| 3 | Inteiro positivo | `8` | Define `OMP_NUM_THREADS`. |
| 4 | Inteiro positivo | `5` | Multiplica as gerações somente na execução perfilada. |

Para uma primeira coleta menor, rode somente Hotspots:

```bash
./experimentos_hype/vtune/coletar_vtune.sh hotspots grande 8 5
```

## Resultados gerados

Cada coleta cria um diretório único em `resultados/`, contendo:

| Arquivo ou diretório | Conteúdo |
| --- | --- |
| `metadados.md` | Parâmetros exatos, versão do VTune e comandos executados. |
| `ambiente.md` | Hardware, sistema, compilador, flags e carga da máquina antes/depois. |
| `snapshot/` | Resultado do Performance Snapshot e `resumo.txt`. |
| `hotspots/` | Resultado de Hotspots, `resumo.txt` e `hotspots_por_funcao.txt`. |
| `hpc/` | Resultado de HPC Performance Characterization e `resumo.txt`. |

O diretório que contém os dados brutos do VTune pode ser aberto na interface gráfica do VTune, caso ela esteja disponível. Os arquivos `resumo.txt` e `hotspots_por_funcao.txt` permitem uma análise inicial diretamente pelo terminal.

## Como interpretar

- **Snapshot:** use o resumo para identificar se há utilização baixa de CPU, limitação por memória ou sugestão de análise adicional.
- **Hotspots:** procure se `population_evaluate()`, `population_reproduce()` ou seus laços internos concentram o tempo. Funções pequenas podem não aparecer isoladamente por causa de `-O2` e inlining.
- **HPC:** verifique a utilização efetiva dos núcleos, comportamento de memória e métricas de escalabilidade OpenMP. Uma eficiência menor com mais threads pode ser explicada por sincronização, regiões seriais, pouca granularidade ou pressão de memória/cache.

Relacionem cada achado aos gráficos. Por exemplo: se Hotspots mostra que avaliação e reprodução dominam a execução, isso sustenta a escolha dos laços paralelizados. Se a utilização efetiva de núcleos cai com oito threads, isso ajuda a explicar a eficiência abaixo de 100%.
