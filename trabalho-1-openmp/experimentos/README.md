# Experimentos no notebook

Esta pasta contém a rodada local de desenvolvimento. Ela serve para validar correção, familiarizar-se com os scripts e observar tendências de escalabilidade antes de usar a Hype. Os arquivos de dados e gráficos já presentes aqui pertencem à primeira rodada executada no notebook.

## Finalidade

No notebook, os testes têm três finalidades:

1. confirmar que as versões sequencial e paralela produzem o mesmo fitness com a mesma seed;
2. verificar que a automação de coleta, resumo e gráficos funciona;
3. obter uma referência inicial, sem tratá-la como resultado final da disciplina.

O notebook possui um processador híbrido e executa interface gráfica, editor e navegador ao mesmo tempo. Por isso, perda de eficiência com muitas threads é esperada e não representa, sozinha, a escalabilidade que será obtida na Hype.

## Arquivos

| Item | Finalidade |
| --- | --- |
| `configuracoes.sh` | Conjuntos e threads adequados à rodada local. |
| `executar_testes.sh` | Coleta tempos, valida fitness e grava `dados/tempos.csv`. |
| `coletar_ambiente.sh` | Registra CPU, sistema, compilador, flags e cargas locais. |
| `gerar_graficos.py` | Produz `dados/resumo.csv` e os gráficos SVG em `graficos/`. |
| `dados/` | Tempos brutos, resumo e ambiente do notebook. |
| `graficos/` | Gráficos da rodada local. |

## Procedimento completo

1. Confira a topologia local e feche aplicações pesadas quando possível:

```bash
lscpu
```

2. Revise `configuracoes.sh`. Os padrões usam `1`, `2`, `4` e `8` threads e três tamanhos de entrada adequados para uma rodada local.

3. Compile as implementações:

```bash
make -C ga_seq
make -C ga_seq_paralelizado
```

4. Faça uma verificação curta de correção com uma seed fixa:

```bash
./ga_seq/ga_seq 1000 1000 100 0.001 42
OMP_NUM_THREADS=4 ./ga_seq_paralelizado/ga_seq_paralelizado \
  1000 1000 100 0.001 42
```

As duas linhas `Melhor fitness` devem coincidir.

5. Rode a bateria completa:

```bash
./experimentos/executar_testes.sh
```

O script cria `dados/tempos.csv` e `dados/tempos_ambiente.md`. Como os arquivos atuais representam uma rodada anterior, use `OVERWRITE=1` somente se quiser substituí-los deliberadamente.

6. Gere os gráficos:

```bash
python3 experimentos/gerar_graficos.py experimentos/dados/tempos.csv
```

7. Consulte `dados/resumo.csv` e os gráficos em `graficos/`. As métricas principais são:

```text
S(p) = Tpar(1) / Tpar(p)
E(p) = S(p) / p
```

O objetivo desta análise é entender tendências e localizar problemas antes da coleta final. Para slides e conclusões finais, use os resultados gerados em `experimentos_hype/`.

## Próximo ambiente

Quando receber acesso à Hype, siga [../experimentos_hype/README.md](../experimentos_hype/README.md). Aquele roteiro inclui calibração do tamanho da entrada, escolha de threads, coleta final e VTune.
