# Versão sequencial do AG OneMax

Esta pasta implementa sequencialmente um Algoritmo Genético (AG) para o problema **OneMax**. Cada indivíduo é um vetor de bits e seu fitness é a quantidade de bits iguais a `1`. O objetivo é maximizar esse valor.

## Como compilar e executar

Na raiz do projeto, execute:

```bash
make -C ga_seq
./ga_seq/ga_seq [populacao] [bits] [geracoes] [mutacao] [seed]
```

Todos os argumentos são opcionais. Os padrões são população `1000`, `1000` bits por indivíduo, `200` gerações, taxa de mutação `1/bits` e seed `42`.

## Organização dos arquivos

### `main.c`

É o ponto de entrada do programa. Define os valores padrão, lê os argumentos da linha de comando, valida os parâmetros e chama `ga_run()`. Ao fim, imprime o melhor fitness encontrado e o tempo de execução.

### `ga.c`

Coordena o ciclo completo do algoritmo. Aloca as populações e o vetor de fitness, inicializa o gerador aleatório, cria a população inicial e executa, a cada geração, esta sequência:

1. cria a próxima população;
2. troca os ponteiros das populações;
3. avalia a nova população;
4. atualiza o melhor fitness global.

Também contém `now_seconds()`, que mede o tempo com `CLOCK_MONOTONIC`.

### `population.c`

Contém as operações sobre a população:

- `population_initialize()` preenche a população inicial com bits aleatórios;
- `individual_evaluate()` calcula o fitness OneMax de um indivíduo;
- `population_evaluate()` calcula o fitness de todos os indivíduos e devolve o melhor valor da geração.

Nesta versão, os laços de inicialização e avaliação são executados por uma única thread.

### `reproduction.c`

Implementa a criação dos filhos:

- `tournament_select()` seleciona um pai por torneio de tamanho dois;
- `population_reproduce()` seleciona dois pais, define o ponto de crossover, monta cada filho e aplica mutação bit a bit.

Como esta é a versão de referência, a reprodução inteira é sequencial. Cada filho, porém, recebe a mesma seed local determinística usada pela versão OpenMP. Isso preserva exatamente a trajetória aleatória do AG e torna os tempos comparáveis.

### `rng.c`

Implementa o gerador pseudoaleatório xorshift usado pelo AG. O estado global é usado apenas na inicialização sequencial; a reprodução usa estados locais derivados da seed, geração e índice do filho para coincidir com a versão OpenMP.

- `rng_seed()` define a seed;
- `rng64()` produz um valor de 64 bits;
- `rng_index()` produz um índice no intervalo solicitado;
- `rng_unit()` produz um valor em `[0, 1)` a partir do estado global;
- as variantes `*_from_state()` operam sobre o estado local de um filho;
- `rng_seed_for_individual()` produz a seed determinística compartilhada pelas duas versões.

## Pasta `include/`

A pasta reúne os arquivos de cabeçalho, isto é, as interfaces públicas entre os módulos `.c`:

| Arquivo | Conteúdo |
| --- | --- |
| `ga.h` | Define `GAConfig` e declara `ga_run()`. |
| `population.h` | Declara a inicialização e a avaliação da população. |
| `reproduction.h` | Declara a função que gera a próxima população. |
| `rng.h` | Declara as operações do gerador pseudoaleatório. |

Os arquivos-fonte incluem esses cabeçalhos pelo caminho `include/...`, o que permite que o editor também encontre as interfaces sem uma configuração especial de include path.

## `Makefile`

Define como construir o executável `ga_seq`. Ele compila separadamente `main.c`, `ga.c`, `population.c`, `reproduction.c` e `rng.c`, e depois os liga no executável final.

- `make -C ga_seq` ou `make -C ga_seq all`: compila o programa;
- `make -C ga_seq clean`: remove executável e arquivos objeto;
- `CFLAGS`: ativa C11, otimização, símbolos de depuração e avisos do compilador.
