# Planejamento da paralelização do Algoritmo Genético com OpenMP

## 1. Objetivo deste documento

Este documento descreve **onde a versão sequencial em `ga_seq/` foi paralelizada** na implementação em `ga_seq_paralelizado/`, quais recursos de OpenMP são utilizados e por que eles foram escolhidos.

A implementação foi limitada aos recursos apresentados no material das **Aulas 5 e 6**:

- `#pragma omp parallel`;
- `#pragma omp parallel for`;
- `#pragma omp sections` e `#pragma omp section`;
- cláusulas `shared(...)` e `private(...)`;
- cláusula `schedule(...)`, com `static`, `dynamic` e `guided`;
- `reduction(+:...)`, apresentada no exemplo de soma;
- funções de runtime básicas, como `omp_get_thread_num()` e `omp_get_wtime()`.

> Observação: `schedule`, `shared`, `private` e `reduction` são **cláusulas** adicionadas a diretivas OpenMP. Elas aparecem aqui porque também fazem parte das decisões de paralelização.

A ideia principal será paralelizar o trabalho **entre indivíduos da população**, e não entre gerações ou entre bits de um mesmo indivíduo.

---

## 2. Resumo da estratégia escolhida

A versão paralela usará OpenMP em dois pontos principais:

1. **avaliação da população**;
2. **reprodução da população**.

Nos dois casos será utilizada:

```c
#pragma omp parallel for schedule(static)
```

A escolha é adequada porque os dois trechos são laços grandes, com iterações independentes e com quantidade de trabalho muito semelhante entre as iterações.

A estrutura geral continuará sendo:

```text
inicialização sequencial
        |
        v
avaliação paralela
        |
        v
+--------------------------------+
| para cada geração              |
|                                |
|    reprodução paralela         |
|            |                   |
|            v                   |
|    troca das populações        |
|            |                   |
|            v                   |
|    avaliação paralela          |
|            |                   |
|            v                   |
|    atualização do melhor       |
+--------------------------------+
        |
        v
resultado
```

O **laço das gerações permanece sequencial**, porque uma geração depende da população produzida pela anterior.

---

# 3. Paralelização da avaliação da população

## 3.1. Código sequencial original

Na versão sequencial, a avaliação é feita aproximadamente assim:

```c
for (size_t i = 0; i < pop_size; i++) {
    fitness[i] = evaluate(pop + i * n_bits, n_bits);
}
```

Cada iteração trabalha sobre um indivíduo diferente.

O indivíduo `i` é somente lido, e seu resultado é armazenado em:

```c
fitness[i]
```

Logo, a iteração `i` não precisa do resultado da iteração `i + 1`.

Podemos imaginar, com quatro threads:

```text
Thread 0 -> avalia alguns indivíduos
Thread 1 -> avalia outros indivíduos
Thread 2 -> avalia outros indivíduos
Thread 3 -> avalia outros indivíduos
```

Nenhuma thread precisa modificar o indivíduo que está sendo avaliado por outra.

## 3.2. Diretiva escolhida

Será usado:

```c
#pragma omp parallel for schedule(static)
for (size_t i = 0; i < pop_size; i++) {
    fitness[i] = evaluate(pop + i * n_bits, n_bits);
}
```

`parallel for` é apropriado porque o trabalho que queremos dividir é exatamente um **laço com muitas iterações independentes**.

O OpenMP cria a região paralela e distribui as iterações do `for` entre as threads.

---

## 3.3. Por que `schedule(static)`?

Na avaliação, todos os indivíduos possuem exatamente `n_bits` bits.

A função `evaluate()` executa:

```c
for (size_t j = 0; j < n_bits; j++) {
    fitness += ind[j];
}
```

Portanto, cada indivíduo exige aproximadamente a mesma quantidade de trabalho.

Isso torna a carga **regular** e previsível.

O material apresenta três políticas:

### `schedule(static)` — escolhida

```c
#pragma omp parallel for schedule(static)
```

As iterações são distribuídas previamente entre as threads.

É a melhor escolha inicial aqui porque:

- as iterações têm custo muito semelhante;
- não esperamos grande desbalanceamento;
- possui baixo overhead de escalonamento.

### `schedule(dynamic)` — não escolhida

```c
#pragma omp parallel for schedule(dynamic)
```

No `dynamic`, as threads recebem novas iterações conforme ficam livres.

Isso pode ajudar quando algumas iterações demoram muito mais que outras.

Neste caso, porém, todos os indivíduos têm o mesmo tamanho e a avaliação sempre percorre `n_bits` posições. O ganho de balanceamento seria pequeno ou inexistente, enquanto o gerenciamento dinâmico introduziria overhead adicional.

### `schedule(guided)` — não escolhida

```c
#pragma omp parallel for schedule(guided)
```

O `guided` começa distribuindo blocos maiores e diminui o tamanho dos blocos durante a execução.

Ele representa um compromisso entre `static` e `dynamic`, mas a avaliação OneMax não apresenta uma irregularidade de carga que justifique esse mecanismo.

Por isso, `static` é a opção mais simples e coerente com esse laço.

---

## 3.4. Por que não usar apenas `#pragma omp parallel`?

Uma alternativa aprendida foi:

```c
#pragma omp parallel
{
    for (size_t i = 0; i < pop_size; i++) {
        ...
    }
}
```

Esse código **não divide automaticamente o `for`**.

Se usado dessa forma, cada thread executaria o laço inteiro, duplicando o trabalho — exatamente o problema discutido nas aulas.

Seria possível criar uma divisão manual das iterações usando o identificador da thread, mas isso adicionaria lógica desnecessária.

Como `parallel for` já realiza essa divisão diretamente, ele é a escolha mais simples.

---

## 3.5. Por que não usar `sections`?

`sections` é indicada quando existem **tarefas diferentes e independentes**.

Exemplo conceitual:

```c
#pragma omp sections
{
    #pragma omp section
    tarefa_a();

    #pragma omp section
    tarefa_b();
}
```

A avaliação não possui algumas poucas tarefas diferentes. Ela possui **muitas execuções da mesma tarefa**: avaliar indivíduo 0, indivíduo 1, indivíduo 2, etc.

Por isso, transformar indivíduos em `sections` seria inadequado e pouco escalável.

O padrão natural é um `for`, logo `parallel for` representa melhor o problema.

---

# 4. Busca pelo melhor fitness após a avaliação

Na versão sequencial original, cálculo do fitness e atualização de `best` ocorriam dentro do mesmo laço:

```c
fitness[i] = evaluate(...);

if (fitness[i] > best) {
    best = fitness[i];
}
```

Se o laço fosse simplesmente paralelizado, várias threads poderiam acessar e modificar `best` ao mesmo tempo.

Isso criaria uma condição de corrida.

## Escolha adotada

A versão paralela separará as duas operações:

```c
#pragma omp parallel for schedule(static)
for (size_t i = 0; i < pop_size; i++) {
    fitness[i] = evaluate(pop + i * n_bits, n_bits);
}

int best = 0;
for (size_t i = 0; i < pop_size; i++) {
    if (fitness[i] > best) {
        best = fitness[i];
    }
}
```

Assim:

- o trabalho pesado de calcular o OneMax fica paralelo;
- a busca pelo maior valor fica sequencial;
- nenhuma thread disputa a variável `best`.

O material apresenta um exemplo de `reduction(+:sum)` para somas. Entretanto, para permanecer estritamente dentro das formas demonstradas nas aulas fornecidas, não introduziremos aqui uma forma diferente de redução para encontrar máximo.

Além disso, a busca sequencial percorre apenas `pop_size` inteiros, enquanto a avaliação percorre aproximadamente:

```text
pop_size × n_bits
```

bits. Portanto, o trecho sequencial adicional tende a ser muito menor que o trabalho paralelizado.

---

# 5. Paralelização da reprodução

## 5.1. Código sequencial original

A reprodução possui um laço externo semelhante a:

```c
for (size_t i = 0; i < pop_size; i++) {
    selecionar pais;
    realizar crossover;
    aplicar mutação;
    salvar filho i;
}
```

Cada iteração produz um filho diferente.

A população antiga e o vetor de fitness são somente lidos:

```text
pop     -> somente leitura
fitness -> somente leitura
```

Cada iteração escreve somente na região correspondente ao seu próprio filho:

```c
uint8_t *child = next + i * n_bits;
```

Logo:

```text
iteração 0 -> escreve no filho 0
iteração 1 -> escreve no filho 1
iteração 2 -> escreve no filho 2
...
```

Não existe necessidade de um filho esperar o outro ser criado.

---

## 5.2. Diretiva escolhida

Será utilizado:

```c
#pragma omp parallel for schedule(static)
for (size_t i = 0; i < pop_size; i++) {
    ...
}
```

Novamente, `parallel for` corresponde diretamente ao problema: temos um grande conjunto de iterações independentes que devem ser distribuídas entre threads.

---

## 5.3. Por que `schedule(static)` novamente?

Cada filho executa praticamente a mesma sequência de operações:

1. dois torneios de seleção;
2. um sorteio do ponto de crossover;
3. um laço de exatamente `n_bits` posições;
4. um teste de mutação para cada bit.

Embora o resultado dos testes de mutação seja aleatório, **o teste é executado para todos os bits**, independentemente de a mutação acontecer ou não.

Assim, o custo de produzir diferentes filhos é bastante semelhante.

Consequentemente:

- `static` tende a distribuir bem a carga;
- `dynamic` adicionaria gerenciamento desnecessário;
- `guided` também não traz uma vantagem clara para esse padrão regular.

---

## 5.4. Por que não usar `sections` na reprodução?

Poderíamos imaginar algo como:

```text
section 1 -> seleção
section 2 -> crossover
section 3 -> mutação
```

Isso **não funciona corretamente**, pois essas etapas possuem dependências:

```text
seleção
   |
   v
crossover
   |
   v
mutação
```

O crossover precisa dos pais selecionados, e a mutação precisa do filho produzido pelo crossover.

Elas não são tarefas independentes.

O paralelismo correto está entre **filhos diferentes**, e não entre as etapas que criam um mesmo filho.

Por isso, `parallel for` no laço dos filhos é a escolha adequada.

---

# 6. Problema especial: gerador de números aleatórios

A versão sequencial possuía um único estado global:

```c
static uint64_t rng_state = 42;
```

Isso funciona com uma thread, mas seria incorreto durante a reprodução paralela.

Se várias threads chamassem simultaneamente uma função que modifica `rng_state`, teríamos:

```text
Thread 0 ----+
             +--> rng_state
Thread 1 ----+
```

As duas poderiam ler e escrever o mesmo valor ao mesmo tempo, causando uma condição de corrida.

## Solução adotada sem uma nova diretiva OpenMP

Na versão paralela, cada filho terá um **estado local de RNG**:

```c
uint64_t local_state = seed_for_individual(base_seed, generation, i);
```

Como essa variável é declarada dentro da iteração, cada thread trabalha com a sua própria variável local enquanto processa aquele filho.

As funções aleatórias passam a receber o estado explicitamente:

```c
rng64(&local_state);
rnd(&local_state, n);
rnd01(&local_state);
```

Dessa forma, nenhuma thread altera um estado pseudoaleatório compartilhado durante a reprodução.

Além de eliminar a condição de corrida, a semente é derivada de:

- semente base;
- número da geração;
- índice do filho.

Assim, o filho `i` recebe a mesma sequência pseudoaleatória independentemente de qual thread o processe. Isso é útil nos experimentos porque mudar `OMP_NUM_THREADS` não muda, por si só, as escolhas aleatórias do algoritmo.

---

# 7. Escopo de variáveis: `shared` e `private`

O material apresenta as cláusulas:

```c
shared(...)
private(...)
```

Na implementação, não será necessário escrever essas cláusulas explicitamente nos dois `parallel for`.

## Dados compartilhados

Durante a avaliação:

```c
pop
fitness
```

são estruturas acessíveis por todas as threads.

Durante a reprodução:

```c
pop
next
fitness
```

também são acessíveis por todas as threads.

Isso é seguro porque:

- `pop` é somente lido;
- `fitness` é somente lido durante a reprodução;
- na avaliação, cada thread escreve em um `fitness[i]` diferente;
- em `next`, cada thread escreve em um filho diferente.

## Dados privados

Variáveis criadas dentro de uma iteração, como:

```c
uint64_t local_state;
size_t p1;
size_t p2;
size_t cut;
```

pertencem à execução daquela iteração e não precisam ser compartilhadas entre threads.

Também não há motivo para compartilhar o índice `i` entre as threads.

Poderíamos tornar alguns escopos explícitos com cláusulas `shared` e `private`, mas isso deixaria a diretiva mais longa sem resolver um problema existente. A própria organização do código já separa claramente dados compartilhados e temporários locais.

---

# 8. Por que não paralelizar o laço interno de `evaluate()`?

A função OneMax executa:

```c
for (size_t j = 0; j < n_bits; j++) {
    fitness += ind[j];
}
```

Como esse laço realiza uma soma, ele lembra o exemplo de aula com:

```c
reduction(+:sum)
```

Portanto, uma alternativa seria tentar paralelizar os bits de um único indivíduo usando uma redução.

Porém, não faremos isso.

O laço externo já distribui **indivíduos inteiros** entre as threads:

```text
Thread 0 -> indivíduos
Thread 1 -> indivíduos
Thread 2 -> indivíduos
...
```

Abrir mais paralelismo dentro de cada `evaluate()` adicionaria complexidade e overhead. Para o nosso AG, é mais natural usar uma granularidade maior: um indivíduo é a unidade de trabalho.

Consequentemente, `evaluate()` permanece sequencial, mas várias chamadas a `evaluate()` acontecem simultaneamente para indivíduos diferentes.

---

# 9. Por que a inicialização continuará sequencial?

A inicialização é:

```c
for (size_t i = 0; i < pop_size * n_bits; i++) {
    pop[i] = rng64(...) & 1u;
}
```

Cada posição da população poderia, em princípio, ser gerada em paralelo.

Entretanto, optamos por mantê-la sequencial por dois motivos:

1. ela ocorre **apenas uma vez** durante toda a execução;
2. avaliação e reprodução ocorrem repetidamente a cada geração e, por isso, possuem impacto muito maior no tempo total.

Além disso, manter a inicialização sequencial preserva uma parte simples do comportamento da versão original e evita adicionar lógica de RNG paralelo onde o benefício esperado é menor.

Se o VTune mostrar posteriormente que a inicialização representa uma parcela relevante do tempo para algum conjunto de entrada, ela poderá ser reavaliada.

---

# 10. Por que o laço das gerações não será paralelizado?

O laço principal possui esta dependência:

```text
geração g
    |
    v
produz nova população
    |
    v
geração g + 1 usa essa população
```

Portanto, isto não pode ser transformado diretamente em:

```c
#pragma omp parallel for
for (int g = 0; g < generations; g++) {
    ...
}
```

A geração `g + 1` ainda não possui seus dados de entrada enquanto a geração `g` não terminar.

Logo, existe uma **dependência de dados entre gerações**.

O paralelismo ocorre **dentro de cada geração**, e não entre gerações.

---

# 11. Por que a troca das populações não será paralelizada?

Após a reprodução:

```c
uint8_t *tmp = pop;
pop = next;
next = tmp;
```

Essa operação:

- é extremamente pequena;
- precisa ocorrer somente depois que todos os filhos estiverem prontos;
- altera os ponteiros usados pela etapa seguinte.

Não existe trabalho suficiente para justificar threads adicionais.

Além disso, o `parallel for` possui uma sincronização ao final do laço por padrão. Portanto, quando `reproduce()` retorna, a nova população já está completamente produzida e a thread que continua a execução pode trocar os ponteiros com segurança.

---

# 12. Por que a atualização de `global_best` não será paralelizada?

Depois da avaliação:

```c
if (best > global_best) {
    global_best = best;
}
```

Existe apenas uma comparação por geração.

O custo é insignificante em relação aos milhares ou milhões de operações feitas sobre os indivíduos.

Paralelizar esse trecho aumentaria a complexidade sem benefício prático.

---

# 13. Comparação das alternativas aprendidas

| Local do código | Escolha | Alternativas aprendidas | Motivo da escolha |
|---|---|---|---|
| Avaliação dos indivíduos | `parallel for schedule(static)` | `parallel`, `sections`, `schedule(dynamic)`, `schedule(guided)` | É um laço grande, regular e com iterações independentes |
| Busca do melhor fitness | Sequencial | O material mostra `reduction(+:...)` para soma | Evita condição de corrida sem introduzir uma forma de redução não demonstrada; o custo é pequeno |
| Reprodução dos filhos | `parallel for schedule(static)` | `parallel`, `sections`, `schedule(dynamic)`, `schedule(guided)` | Cada filho é independente e possui custo semelhante |
| Laço de bits em `evaluate()` | Sequencial | `parallel for reduction(+:...)` seria compatível com a ideia da soma | Preferimos paralelismo entre indivíduos para evitar granularidade fina e paralelismo interno |
| Inicialização | Sequencial | `parallel for` | Executa uma única vez e exigiria cuidado adicional com RNG |
| Laço das gerações | Sequencial | Nenhuma das diretivas estudadas elimina a dependência entre gerações | A geração seguinte depende da anterior |
| Seleção/crossover/mutação como tarefas separadas | Sequencial dentro de cada filho | `sections` | As três etapas dependem umas das outras; não são tarefas independentes |

---

# 14. Diretivas OpenMP que realmente aparecem no código final

Apesar de várias alternativas terem sido analisadas, a versão final utiliza deliberadamente poucas construções:

```c
#pragma omp parallel for schedule(static)
```

na avaliação da população, e:

```c
#pragma omp parallel for schedule(static)
```

na reprodução.

Isso é intencional. O objetivo não é inserir o maior número possível de diretivas, mas utilizar OpenMP **onde existe paralelismo de dados claro e justificável**.

Essa solução também facilita a análise posterior de:

- speedup;
- eficiência;
- balanceamento de carga;
- overhead de paralelização;
- hotspots no Intel VTune.

---

# 15. Como controlar o número de threads

Não vamos fixar a quantidade de threads dentro do código.

Nos experimentos, ela será controlada pela variável de ambiente mostrada nas aulas:

```bash
export OMP_NUM_THREADS=1
./ga_seq_paralelizado/ga_seq_paralelizado

export OMP_NUM_THREADS=2
./ga_seq_paralelizado/ga_seq_paralelizado

export OMP_NUM_THREADS=4
./ga_seq_paralelizado/ga_seq_paralelizado

export OMP_NUM_THREADS=8
./ga_seq_paralelizado/ga_seq_paralelizado
```

Isso facilita a coleta dos tempos para calcular:

```text
Speedup = T1 / Tp
```

sem recompilar o programa para cada quantidade de threads.

---

# 16. Compilação

Cada versão possui seu próprio `Makefile`. A versão OpenMP já inclui `-fopenmp`:

```bash
make -C ga_seq_paralelizado
```

O restante dos argumentos do AG continua igual ao da versão sequencial:

```bash
./ga_seq_paralelizado/ga_seq_paralelizado \
    [populacao] [bits] [geracoes] [mutacao] [seed]
```
