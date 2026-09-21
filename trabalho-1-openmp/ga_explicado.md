# Algoritmo Genético com OneMax

## 1. Ideia geral

Um **Algoritmo Genético (AG)** é um método de busca e otimização inspirado, de forma simplificada, em ideias de evolução natural.

Em vez de trabalhar com uma única solução, o algoritmo mantém uma **população de soluções candidatas**, chamadas de **indivíduos**.

A cada geração, o AG:

1. avalia a qualidade de cada indivíduo;
2. seleciona indivíduos com melhor desempenho;
3. combina indivíduos para gerar novos candidatos;
4. aplica pequenas mutações;
5. substitui a população antiga pela nova.

Esse processo é repetido por várias gerações.

---

## 2. Problema OneMax

Neste trabalho, o AG resolve o problema **OneMax**.

Cada indivíduo é representado por uma sequência de bits, por exemplo:

```text
10110100
```

A função objetivo é extremamente simples: **maximizar a quantidade de bits iguais a 1**.

Assim, o fitness de:

```text
10110100
```

é:

```text
4
```

porque existem quatro bits iguais a `1`.

Para um indivíduo com 8 bits, a melhor solução possível é:

```text
11111111
```

com fitness igual a:

```text
8
```

O OneMax é útil neste trabalho porque a função objetivo é simples. Dessa forma, o foco pode permanecer na **paralelização e na análise de desempenho**, e não na complexidade do problema de otimização.

---

## 3. Representação da população

Cada indivíduo é um vetor de bits:

```text
Indivíduo 0: 1 0 1 1 0
Indivíduo 1: 0 1 1 0 1
Indivíduo 2: 1 1 1 0 0
```

No código em C, toda a população é armazenada em um único vetor.

Para uma população com `P` indivíduos e indivíduos com `N` bits, são armazenados:

```text
P × N
```

bits representados como valores `uint8_t`.

O indivíduo `i` começa na posição:

```c
i * n_bits
```

do vetor da população.

---

## 4. Inicialização

No início da execução, todos os indivíduos são gerados aleatoriamente.

Cada posição recebe:

```text
0 ou 1
```

com igual possibilidade.

Por exemplo:

```text
População inicial

10100101
00111100
11100010
01010111
```

Essa população funciona como o ponto de partida da busca.

---

## 5. Avaliação — Fitness

Depois de criar a população, o algoritmo calcula o **fitness** de cada indivíduo.

No OneMax:

```text
fitness = número de bits iguais a 1
```

Exemplo:

```text
Indivíduo: 1 0 1 1 0 1
Fitness:   4
```

Quanto maior o fitness, melhor é o indivíduo.

Essa etapa é particularmente interessante para paralelização, pois o fitness de cada indivíduo pode ser calculado independentemente dos demais.

---

## 6. Seleção por torneio

Para gerar um novo indivíduo, precisamos escolher seus pais.

A implementação utiliza **seleção por torneio de tamanho 2**.

O funcionamento é:

1. sorteiam-se dois indivíduos;
2. compara-se o fitness dos dois;
3. o indivíduo com maior fitness vence o torneio;
4. o vencedor é escolhido como pai.

Exemplo:

```text
Indivíduo A -> fitness 57
Indivíduo B -> fitness 63

Vencedor: indivíduo B
```

Esse mecanismo favorece indivíduos melhores, mas ainda permite que diferentes regiões da população participem da reprodução.

---

## 7. Crossover

Depois de selecionar dois pais, o algoritmo gera um filho através de **crossover de um ponto**.

Um ponto de corte é escolhido aleatoriamente.

Exemplo:

```text
Pai 1:  1 1 0 | 0 1 0
Pai 2:  0 0 1 | 1 1 1
             ^
          corte
```

O filho recebe a primeira parte do primeiro pai e a segunda parte do segundo:

```text
Filho:  1 1 0 | 1 1 1
```

Assim, características dos dois pais podem aparecer no novo indivíduo.

---

## 8. Mutação

Depois do crossover, cada bit do filho pode sofrer uma mutação.

Uma mutação simplesmente inverte o valor do bit:

```text
0 -> 1
1 -> 0
```

Exemplo:

```text
Antes:  1 1 0 1 1 1
              ^
            mutação

Depois: 1 1 1 1 1 1
```

A taxa padrão utilizada no código é:

```text
1 / número_de_bits
```

Por exemplo, para indivíduos de 1000 bits:

```text
taxa de mutação = 1 / 1000 = 0,001
```

Isso significa que, em média, aproximadamente um bit por indivíduo tende a sofrer mutação.

A mutação ajuda a introduzir novas características na população e evita que a busca dependa apenas da combinação dos indivíduos existentes.

---

## 9. Formação da próxima geração

Para cada posição da nova população:

1. selecionamos o primeiro pai;
2. selecionamos o segundo pai;
3. realizamos o crossover;
4. aplicamos mutação;
5. armazenamos o novo filho.

Depois de produzir todos os filhos, a nova população substitui a população anterior.

Em vez de copiar todos os dados de um vetor para outro, o código simplesmente troca os ponteiros:

```c
uint8_t *tmp = pop;
pop = next;
next = tmp;
```

Isso evita uma cópia desnecessária da população inteira.

---

## 10. Fluxo completo

De forma resumida, o algoritmo executado é:

```text
Criar população aleatória
        |
        v
Calcular fitness
        |
        v
+---------------------------+
| Para cada geração         |
|                           |
|  Selecionar pais          |
|        |                  |
|        v                  |
|  Fazer crossover          |
|        |                  |
|        v                  |
|  Aplicar mutação          |
|        |                  |
|        v                  |
|  Criar nova população     |
|        |                  |
|        v                  |
|  Calcular novos fitness   |
+---------------------------+
        |
        v
Mostrar melhor fitness
```

---

## 11. Pseudocódigo

```text
inicializar população aleatoriamente
avaliar população

para cada geração:
    para cada novo indivíduo:
        pai1 = seleção por torneio
        pai2 = seleção por torneio

        filho = crossover(pai1, pai2)

        aplicar mutação no filho

        armazenar filho na nova população

    substituir população antiga pela nova
    avaliar nova população

mostrar melhor fitness encontrado
```

---

## 12. Por que este AG é simples?

Existem muitas variações possíveis de Algoritmos Genéticos. Poderíamos utilizar, por exemplo:

- elitismo;
- diferentes tipos de crossover;
- diferentes métodos de seleção;
- populações estruturadas;
- múltiplos critérios de parada;
- operadores adaptativos.

Esses recursos não são necessários para o objetivo deste trabalho.

A implementação foi deliberadamente mantida simples porque o objetivo principal da disciplina é estudar:

- paralelização com OpenMP;
- tempo de execução;
- speedup;
- eficiência;
- escalabilidade;
- comportamento das threads;
- análise com Intel VTune Profiler.

O AG funciona, portanto, como uma carga computacional sobre a qual esses conceitos podem ser analisados.

---

## 13. Onde existe potencial de paralelismo?

Ao analisar o algoritmo, a principal pergunta é:

> **Uma iteração precisa do resultado da outra para poder executar?**

Se a resposta for **não**, então existe potencial de paralelismo, pois diferentes iterações podem ser executadas simultaneamente por diferentes threads.

No nosso AG, algumas etapas possuem esse tipo de independência de forma bastante clara.

### 13.1. Avaliação da população

A avaliação da população percorre todos os indivíduos:

```c
for (size_t i = 0; i < pop_size; i++) {
    fitness[i] = evaluate(pop + i * n_bits, n_bits);
}
```

Cada indivíduo possui sua própria sequência de bits e seu fitness pode ser calculado sem utilizar o resultado de outro indivíduo.

Por exemplo:

```text
Thread 0 -> calcula fitness do indivíduo 0
Thread 1 -> calcula fitness do indivíduo 1
Thread 2 -> calcula fitness do indivíduo 2
Thread 3 -> calcula fitness do indivíduo 3
```

Esses cálculos podem acontecer ao mesmo tempo porque:

- o indivíduo `0` não depende do fitness do indivíduo `1`;
- o indivíduo `1` não depende do fitness do indivíduo `2`;
- e assim por diante;
- cada thread apenas lê a população;
- cada thread escreve em uma posição diferente do vetor `fitness`.

Logo, o laço externo da avaliação possui **iterações independentes**.

Por isso, ele é um candidato natural para paralelização com OpenMP.

---

### 13.2. Cálculo do fitness de um indivíduo

Dentro da função `evaluate`, existe outro laço:

```c
for (size_t j = 0; j < n_bits; j++) {
    fitness += ind[j];
}
```

Em teoria, essa soma também poderia ser paralelizada utilizando uma operação de redução.

Cada bit pode ser lido independentemente, e os resultados parciais poderiam ser somados no final.

Por exemplo:

```text
Thread 0 -> soma bits 0 até 249
Thread 1 -> soma bits 250 até 499
Thread 2 -> soma bits 500 até 749
Thread 3 -> soma bits 750 até 999
```

Depois, as somas parciais seriam combinadas.

Entretanto, **não é necessariamente interessante paralelizar esse laço interno**.

Isso ocorre porque já existe paralelismo no nível da população. Em geral, é mais simples e eficiente distribuir indivíduos inteiros entre as threads do que criar paralelismo dentro da avaliação de cada indivíduo.

Além disso, paralelizar um laço muito pequeno pode introduzir mais overhead de criação e sincronização de threads do que ganho de desempenho.

Portanto, apesar de existir potencial teórico de paralelismo nessa soma, a nossa primeira estratégia será paralelizar a avaliação entre indivíduos.

---

### 13.3. Reprodução da população

A reprodução também percorre todos os indivíduos da nova geração:

```c
for (size_t i = 0; i < pop_size; i++) {
    // selecionar pais
    // crossover
    // mutação
    // criar filho i
}
```

Cada iteração cria um filho diferente.

Por exemplo:

```text
Thread 0 -> gera o filho 0
Thread 1 -> gera o filho 1
Thread 2 -> gera o filho 2
Thread 3 -> gera o filho 3
```

A geração do filho `0` não precisa esperar a geração do filho `1`.

Isso ocorre porque todos os filhos:

- leem a mesma população antiga;
- leem o mesmo vetor de fitness;
- escrevem em posições diferentes da nova população.

Em outras palavras, durante a reprodução, a população antiga funciona apenas como entrada e não é modificada.

Cada thread escreve apenas no espaço reservado para seu próprio filho:

```c
uint8_t *child = next + i * n_bits;
```

Assim, duas threads que estejam gerando filhos diferentes não precisam escrever na mesma região de memória.

Isso torna o laço externo da função `reproduce` um dos principais candidatos à paralelização.

---

### 13.4. Crossover e mutação de um filho

Dentro da reprodução, também existe um laço sobre os bits do filho:

```c
for (size_t j = 0; j < n_bits; j++) {
    child[j] = (j < cut) ? parent1[j] : parent2[j];

    if (rnd01() < mutation_rate) {
        child[j] ^= 1u;
    }
}
```

Os bits do filho são armazenados em posições diferentes, então existe independência entre muitas dessas operações.

Porém, assim como na função de fitness, normalmente é mais interessante paralelizar o laço externo, distribuindo filhos inteiros entre threads.

Se paralelizássemos também o laço interno, teríamos paralelismo aninhado e maior overhead.

Além disso, a mutação depende da geração de números aleatórios, o que exige cuidados adicionais na versão paralela.

Portanto, o potencial de paralelismo mais útil está no nível dos indivíduos, e não no nível dos bits.

---

### 13.5. Geração de números aleatórios

A geração de números aleatórios é um ponto especial.

Na versão sequencial, existe um único estado global:

```c
static uint64_t rng_state = 42;
```

A função:

```c
rng64()
```

lê esse estado, altera seu valor e grava o novo estado.

Isso significa que chamadas consecutivas possuem dependência:

```text
estado 0
   |
   v
gera número 1
   |
   v
estado 1
   |
   v
gera número 2
   |
   v
estado 2
```

Portanto, **não podemos simplesmente permitir que várias threads modifiquem `rng_state` ao mesmo tempo**.

Caso isso aconteça, existiria uma condição de corrida (*race condition*): duas ou mais threads poderiam ler e escrever o mesmo estado simultaneamente, produzindo resultados incorretos ou imprevisíveis.

Uma possível solução na versão OpenMP é dar a cada thread seu próprio estado de geração aleatória.

Conceitualmente:

```text
Thread 0 -> rng_state_0
Thread 1 -> rng_state_1
Thread 2 -> rng_state_2
Thread 3 -> rng_state_3
```

Assim, cada thread pode gerar números aleatórios independentemente.

Portanto, a geração aleatória não impede a paralelização da reprodução, mas exige uma alteração na implementação.

---

### 13.6. Busca pelo melhor fitness

Na avaliação da população também existe:

```c
if (fitness[i] > best) {
    best = fitness[i];
}
```

Essa operação não é completamente independente.

Todas as iterações tentam atualizar a mesma variável:

```c
best
```

Se várias threads executassem esse trecho simultaneamente, poderia ocorrer uma condição de corrida.

Por exemplo:

```text
Thread 0 encontra fitness 800
Thread 1 encontra fitness 850
```

As duas poderiam tentar atualizar `best` ao mesmo tempo.

Para paralelizar corretamente essa operação, é necessário combinar os resultados das threads.

Em OpenMP, uma forma natural é utilizar uma **redução de máximo**.

Conceitualmente:

```text
Thread 0 -> melhor local = 800
Thread 1 -> melhor local = 850
Thread 2 -> melhor local = 830
Thread 3 -> melhor local = 810

Resultado final -> max = 850
```

Portanto, essa parte possui potencial de paralelismo, mas requer sincronização ou redução.

---

### 13.7. Troca das populações

Depois de gerar a nova população, o programa executa:

```c
uint8_t *tmp = pop;
pop = next;
next = tmp;
```

Essa operação apenas troca três ponteiros.

Ela depende de a reprodução inteira já ter terminado, pois a nova população precisa estar completamente pronta antes de se tornar a população atual.

Portanto, essa etapa **não possui paralelismo útil**.

Além disso, sua quantidade de trabalho é extremamente pequena, então paralelizá-la não traria benefício de desempenho.

---

### 13.8. Laço das gerações

O laço principal é:

```c
for (int g = 0; g < generations; g++) {
    reproduce(...);

    // troca das populações

    evaluate_population(...);
}
```

As gerações **não podem ser executadas independentemente**.

A geração seguinte depende diretamente da população produzida pela geração anterior.

A dependência é:

```text
Geração 0
    |
    v
produz população 1
    |
    v
Geração 1
    |
    v
produz população 2
    |
    v
Geração 2
```

Não seria possível executar a geração 10 antes da geração 9, pois a população de entrada da geração 10 ainda não existe.

Portanto, o laço externo das gerações é essencialmente sequencial.

O paralelismo ocorre **dentro de cada geração**, principalmente na avaliação e na reprodução da população.

---

### 13.9. Atualização do melhor resultado global

Depois de avaliar uma geração, o código executa:

```c
if (best > global_best) {
    global_best = best;
}
```

Esse trecho depende do resultado da avaliação daquela geração.

Além disso, existe apenas uma atualização por geração.

Por isso, não existe ganho prático em tentar paralelizar essa operação.

Ela deve permanecer sequencial.

---

### 13.10. Inicialização da população

A inicialização executa:

```c
for (size_t i = 0; i < pop_size * n_bits; i++) {
    pop[i] = rng64() & 1u;
}
```

Cada posição da população poderia, em princípio, ser criada independentemente.

Portanto, existe potencial de paralelismo.

Porém, na versão atual, todas as iterações utilizam o mesmo `rng_state`, criando a mesma dificuldade existente na reprodução.

Para paralelizar essa etapa, novamente seria necessário fornecer um estado de RNG separado para cada thread.

Além disso, a inicialização acontece apenas uma vez, enquanto avaliação e reprodução acontecem a cada geração.

Por isso, mesmo sendo paralelizável, a inicialização tende a ter menor impacto no tempo total do programa.

---

### 13.11. Partes que não valem a pena paralelizar

Algumas partes do programa são sequenciais ou simplesmente pequenas demais para justificar paralelização.

Entre elas estão:

```c
malloc(...)
free(...)
```

alocação e liberação de memória;

```c
printf(...)
```

impressão dos resultados;

```c
uint8_t *tmp = pop;
pop = next;
next = tmp;
```

troca dos ponteiros;

```c
double elapsed = now_seconds() - start;
```

medição final do tempo;

e:

```c
if (best > global_best) {
    global_best = best;
}
```

atualização do melhor fitness global.

Essas operações representam uma fração muito pequena do trabalho total.

Mesmo que fosse possível paralelizar algumas delas, o custo de sincronização e gerenciamento das threads provavelmente seria maior que qualquer ganho obtido.

---

### 13.12. Resumo das oportunidades de paralelismo

Podemos classificar as principais partes do programa da seguinte forma:

| Etapa | Potencial de paralelismo | Motivo |
|---|---|---|
| Inicialização da população | Sim | Cada posição pode ser gerada independentemente, mas o RNG precisa ser separado por thread |
| Avaliação dos indivíduos | **Alto** | Cada indivíduo pode ser avaliado independentemente |
| Soma dos bits de um indivíduo | Sim, mas pouco interessante | Pode usar redução, porém é preferível paralelizar entre indivíduos |
| Seleção dos pais | Sim | Cada filho pode selecionar seus próprios pais independentemente |
| Crossover | **Alto** | Cada filho pode ser construído independentemente |
| Mutação | **Alto** | Cada filho pode ser mutado independentemente, desde que o RNG seja thread-safe |
| Busca pelo melhor fitness | Sim, com redução | Todas as threads precisam combinar seus melhores valores |
| Troca de `pop` e `next` | Não | Deve ocorrer depois que toda a nova população estiver pronta |
| Laço das gerações | **Não** | Cada geração depende da população produzida pela geração anterior |
| Atualização de `global_best` | Não vale a pena | É uma operação pequena e executada uma vez por geração |
| Impressão e gerenciamento de memória | Não vale a pena | Custo computacional muito pequeno |

Assim, a estratégia principal para a futura versão OpenMP será explorar **paralelismo entre indivíduos**.

A ideia é que diferentes threads processem diferentes indivíduos da população ao mesmo tempo, enquanto o fluxo entre as gerações permanece sequencial.

## 14. Resumo em uma frase

O algoritmo começa com várias sequências binárias aleatórias e, geração após geração, **favorece, combina e modifica as sequências que possuem mais bits iguais a 1**, tentando aproximar a população da solução ótima composta somente por `1`s.
