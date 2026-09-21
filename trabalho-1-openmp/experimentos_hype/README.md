# Experimentos finais na Hype

Esta pasta contém exclusivamente o procedimento de coleta final na Hype, a infraestrutura de computação de alto desempenho indicada pela disciplina. Não misture estes resultados com os do notebook: processador, memória, quantidade de núcleos e carga do sistema são diferentes.

## Finalidade

Os resultados desta pasta devem sustentar os gráficos e a análise apresentados no trabalho. A coleta mede escalabilidade forte: para cada conjunto de entrada, somente a quantidade de threads muda.

Os gráficos usam:

```text
S(p) = Tpar(1) / Tpar(p)
E(p) = S(p) / p
```

`Tpar(1)` é a mediana da versão OpenMP com uma thread. Assim, o gráfico começa obrigatoriamente com speedup 1 e eficiência 100%.

## Arquivos

| Item | Finalidade |
| --- | --- |
| `configuracoes.sh` | Ajuste obrigatório de conjuntos, threads e repetições para a Hype. |
| `executar_testes.sh` | Executa a bateria de tempos e valida o fitness de todas as repetições. |
| `coletar_ambiente.sh` | Registra máquina, topologia, compilador, flags, carga e processos. |
| `gerar_graficos.py` | Produz `dados/resumo.csv` e gráficos SVG em `graficos/`. |
| `vtune/` | Coleta Snapshot, Hotspots e HPC Performance Characterization. |
| `dados/` e `graficos/` | Recebem somente evidências geradas na Hype. |

## Procedimento completo

1. Obtenha com a disciplina o acesso à máquina Hype e copie o projeto para ela.

2. Entre na raiz do projeto e confira compilador e topologia:

```bash
gcc --version
lscpu
```

3. Edite `configuracoes.sh`.

   - Em `THREAD_COUNTS`, use potências de dois até os núcleos físicos efetivamente liberados para o processo.
   - Mantenha `1` como primeiro valor, pois ele é a referência de escalabilidade.
   - Mantenha `REPETITIONS=10`.
   - Ajuste `INPUT_SETS` somente depois de uma execução piloto.

4. Faça uma execução piloto da versão OpenMP com uma thread e aumente população, bits ou gerações até a execução durar alguns segundos. Não use o tamanho do notebook sem validar: uma máquina mais rápida pode tornar uma medição curta e ruidosa.

```bash
make -C ga_seq_paralelizado
OMP_NUM_THREADS=1 ./ga_seq_paralelizado/ga_seq_paralelizado \
  [populacao] [bits] [geracoes] [mutacao] [seed]
```

5. Registre a configuração definitiva em `configuracoes.sh` e execute a bateria completa:

```bash
./experimentos_hype/executar_testes.sh
```

O script grava `dados/tempos.csv` e `dados/tempos_ambiente.md`. Ele interrompe se uma repetição produzir fitness diferente das demais para o mesmo conjunto.

6. Gere as métricas e os gráficos:

```bash
python3 experimentos_hype/gerar_graficos.py \
  experimentos_hype/dados/tempos.csv
```

7. Revise `dados/resumo.csv`. Para cada conjunto, verifique se `scaling_speedup` começa em 1, se `scaling_efficiency` começa em 1 e se as amostras possuem contagem igual a `REPETITIONS`.

8. Selecione uma configuração interessante, normalmente um conjunto médio/grande com eficiência menor que a esperada, e execute o VTune conforme [vtune/README.md](vtune/README.md).

## Regras de interpretação

- Use a mediana, não uma única execução.
- Não compare diretamente uma curva do notebook com uma curva da Hype.
- Eficiência abaixo de 100% é normal; explique-a por overhead, barreiras, trechos sequenciais, memória/cache, carga ou excesso de threads.
- O tempo sob VTune não substitui os tempos em `dados/tempos.csv`, pois o profiler adiciona overhead.
