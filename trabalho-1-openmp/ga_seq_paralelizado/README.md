# Versão paralelizada do AG OneMax

Esta pasta implementa o Algoritmo Genético para OneMax com OpenMP. A estrutura e os parâmetros são equivalentes à versão em `../ga_seq/`, para que os resultados e tempos possam ser comparados.

## Como compilar e executar

Na raiz do projeto, execute:

```bash
make -C ga_seq_paralelizado
OMP_NUM_THREADS=4 ./ga_seq_paralelizado/ga_seq_paralelizado \
    [populacao] [bits] [geracoes] [mutacao] [seed]
```

`OMP_NUM_THREADS` controla a quantidade de threads. Os argumentos do programa são opcionais: população `1000`, `1000` bits por indivíduo, `200` gerações, mutação `1/bits` e seed `42` são os valores padrão.

## Organização dos arquivos

### `main.c`

É o ponto de entrada. Lê e valida os argumentos, chama `ga_run()` e exibe o melhor fitness e o tempo decorrido. Não possui diretivas OpenMP: há pouco trabalho nesse ponto e ele deve permanecer sequencial.

### `ga.c`

Controla a execução do AG: aloca memória, inicializa a população, executa as gerações, alterna os ponteiros das populações e libera memória. A função `ga_run()` permanece sequencial em seu laço de gerações, pois a geração seguinte depende da população produzida pela anterior. As funções chamadas dentro desse laço são as que exploram o paralelismo.

`now_seconds()` usa `CLOCK_MONOTONIC` para medir o intervalo completo da execução.

### `population.c`

Reúne inicialização e fitness:

- `population_initialize()` cria a população inicial sequencialmente, pois ocorre apenas uma vez;
- `individual_evaluate()` calcula o fitness de um indivíduo;
- `population_evaluate()` avalia todos os indivíduos e contém uma diretiva OpenMP, detalhada mais adiante.

### `reproduction.c`

Reúne seleção, crossover e mutação:

- `tournament_select()` escolhe um indivíduo por torneio de tamanho dois;
- `population_reproduce()` cria a população seguinte e contém uma diretiva OpenMP, detalhada mais adiante.

### `rng.c`

Implementa o xorshift e evita estado aleatório compartilhado entre threads:

- `rng64()`, `rng_index()` e `rng_unit()` usam um estado recebido por ponteiro;
- `rng_seed_for_individual()` cria um estado determinístico a partir da seed base, geração e índice do filho.

Logo, cada iteração da reprodução recebe seu próprio estado de RNG. O resultado não depende de qual thread executou determinado filho, o que evita condição de corrida e torna os testes reproduzíveis ao mudar `OMP_NUM_THREADS`. A versão sequencial usa a mesma regra de seeds, portanto também produz o mesmo resultado para os mesmos argumentos.

## Diretivas de paralelismo

Somente dois laços possuem paralelismo, ambos com:

```c
#pragma omp parallel for schedule(static)
```

### Avaliação em `population.c`

A diretiva está na função `population_evaluate()`, no laço externo que percorre os indivíduos. Cada iteração:

- lê uma região distinta, ou somente de leitura, de `population`;
- calcula o fitness de um indivíduo;
- escreve exclusivamente em `fitness[i]`.

Assim, não há disputa de escrita entre threads. Depois da barreira implícita ao fim do `parallel for`, o código procura sequencialmente o maior fitness no vetor já preenchido.

Foi escolhido `parallel for` porque o trabalho é um laço de iterações independentes. Usar somente `parallel` exigiria distribuir manualmente essas iterações entre as threads. `sections` não é adequado, porque as avaliações são muitas tarefas iguais, e não poucas tarefas heterogêneas. Paralelizar o laço interno de bits exigiria uma redução para cada indivíduo e criaria granularidade muito fina; é mais eficiente dividir indivíduos inteiros entre as threads.

Foi escolhido `schedule(static)` porque todos os indivíduos têm o mesmo número de bits e, portanto, quase o mesmo custo de avaliação. Em comparação, `dynamic` e `guided` adicionariam overhead de escalonamento sem corrigir um desequilíbrio de carga esperado.

### Reprodução em `reproduction.c`

A diretiva está na função `population_reproduce()`, no laço externo que cria os filhos. Cada iteração:

- lê `population` e `fitness`, sem modificá-los;
- cria um estado local de RNG;
- escreve exclusivamente na faixa do filho `i` de `next_population`.

Essas regiões de escrita não se sobrepõem. A barreira implícita ao final da diretiva garante que a população seguinte esteja pronta antes de `ga_run()` trocar os ponteiros das populações.

`parallel for` é apropriado porque cada filho pode ser produzido independentemente após a população atual e seu fitness estarem disponíveis. Não se paraleliza o laço das gerações em `ga.c`: existe uma dependência real entre uma geração e a seguinte. `sections` novamente seria inadequado, pois há potencialmente milhares de filhos homogêneos. Paralelizar o crossover e a mutação dentro de cada filho introduziria mais sincronização e overhead do que benefício, especialmente quando já há muitos filhos para distribuir.

Também aqui `schedule(static)` é a escolha natural: cada filho realiza dois torneios e percorre exatamente `bits_per_individual` posições. `dynamic` e `guided` seriam opções úteis se o custo de cada filho variasse muito, o que não ocorre nesta implementação.

## Pasta `include/`

Os cabeçalhos descrevem as interfaces entre os módulos:

| Arquivo | Conteúdo |
| --- | --- |
| `ga.h` | Define `GAConfig` e declara `ga_run()`. |
| `population.h` | Declara a inicialização e a avaliação da população. |
| `reproduction.h` | Declara a reprodução e recebe seed e geração para o RNG local. |
| `rng.h` | Declara o RNG baseado em estado local e a geração de seeds por filho. |

Os fontes usam `#include "include/..."`, para que os headers sejam encontrados pelo compilador e pelo editor mesmo quando esta pasta é aberta isoladamente.

## `Makefile`

O `Makefile` compila `main.c`, `ga.c`, `population.c`, `reproduction.c` e `rng.c` e os liga no executável `ga_seq_paralelizado`.

Ele acrescenta `-fopenmp` tanto em `CFLAGS` quanto na ligação final (`LDFLAGS`). Essa opção habilita o processamento das diretivas OpenMP e vincula o runtime necessário.

- `make -C ga_seq_paralelizado` ou `make -C ga_seq_paralelizado all`: compila;
- `make -C ga_seq_paralelizado clean`: remove executável e arquivos objeto.
