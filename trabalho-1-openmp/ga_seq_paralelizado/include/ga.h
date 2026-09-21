#ifndef GA_H
#define GA_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    size_t population_size;
    size_t bits_per_individual;
    int generations;
    double mutation_rate;
    uint64_t seed;
} GAConfig;

int ga_run(const GAConfig *config, int *global_best, double *elapsed_seconds);

#endif
