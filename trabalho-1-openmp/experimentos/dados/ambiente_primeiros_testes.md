# Ambiente de execução dos experimentos

## Registro: após os primeiros testes

- Data e hora: `2026-09-09T15:54:45-03:00`
- Host: `leonardo-Inspiron-15-3530`
- Sistema operacional: Ubuntu 24.04.4 LTS
- Kernel: `Linux 7.0.0-30-generic x86_64 GNU/Linux`

### Processador

- Modelo: não identificado
- Núcleos físicos: 10
- CPUs lógicas totais: 12
- CPUs lógicas disponíveis ao processo: 12
- Soquetes: não identificado
- Núcleos por soquete: não identificado
- Threads por núcleo: não identificado

### Compilação

- Compilador: `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`
- Flags sequenciais: `-O2 -g -std=c11 -Wall -Wextra -Wpedantic -Iinclude`
- Flags paralelas: `-O2 -g -std=c11 -Wall -Wextra -Wpedantic -fopenmp -Iinclude`
- Flags de ligação OpenMP: `-fopenmp`
- Afinidade usada pelo coletor: `OMP_DYNAMIC=FALSE`, `OMP_PROC_BIND=true`, `OMP_PLACES=cores`

### Carga no momento do registro

- Uptime e média de carga: ` 15:54:45 up  7:02,  1 user,  load average: 0,25, 0,31, 0,53`
- `/proc/loadavg`: `0.25 0.31 0.53 2/1687 119623`

Memória:

```text
               total       usada       livre    compart.  buff/cache  disponível
Mem.:           15Gi       5,6Gi       4,6Gi       941Mi       6,3Gi       9,7Gi
Swap:          4,0Gi          0B       4,0Gi
```

Processos com maior uso de CPU no instante do registro:

```text
PID      USUÁRIO         PROCESSO                 %CPU   %MEM
   3508 leonardo gnome-shell      7.7  2.1
 112725 leonardo zen              4.9  3.2
 110013 leonardo code             4.4  2.4
 118573 leonardo code             4.0  1.1
 109967 leonardo code             2.5  1.3
 110045 leonardo code             2.0  2.8
 110067 leonardo code             1.6  2.1
 109921 leonardo code             1.4  1.8
    862 root     irq/168-rtw89_p  0.8  0.0
  16359 leonardo ChatGPT          0.7  1.2
```
