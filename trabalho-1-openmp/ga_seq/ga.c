#define _POSIX_C_SOURCE 200809L

#include "include/ga.h"
#include "include/population.h"
#include "include/reproduction.h"
#include "include/rng.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_seconds(void) {
    struct timespec time;

    clock_gettime(CLOCK_MONOTONIC, &time);
    return (double)time.tv_sec + (double)time.tv_nsec * 1e-9;
}

int ga_run(const GAConfig *config, int *global_best, double *elapsed_seconds) {
    const size_t population_size = config->population_size;
    const size_t bits_per_individual = config->bits_per_individual;

    if (population_size > SIZE_MAX / bits_per_individual ||
        population_size > SIZE_MAX / sizeof(int)) {
        fprintf(stderr, "Parâmetros excedem o limite de alocação.\n");
        return 1;
    }

    uint8_t *population = malloc(population_size * bits_per_individual * sizeof(*population));
    uint8_t *next_population = malloc(population_size * bits_per_individual * sizeof(*next_population));
    int *fitness = malloc(population_size * sizeof(*fitness));

    if (!population || !next_population || !fitness) {
        fprintf(stderr, "Erro de memoria.\n");
        free(population);
        free(next_population);
        free(fitness);
        return 1;
    }

    const double start = now_seconds();
    rng_seed(config->seed);
    population_initialize(population, population_size, bits_per_individual);
    *global_best = population_evaluate(population, fitness, population_size,
                                       bits_per_individual);

    for (int generation = 0; generation < config->generations; generation++) {
        population_reproduce(population, next_population, fitness, population_size,
                             bits_per_individual, config->mutation_rate,
                             config->seed, generation);

        uint8_t *temporary = population;
        population = next_population;
        next_population = temporary;

        const int current_best = population_evaluate(population, fitness,
                                                     population_size,
                                                     bits_per_individual);
        if (current_best > *global_best) {
            *global_best = current_best;
        }
    }

    *elapsed_seconds = now_seconds() - start;
    free(population);
    free(next_population);
    free(fitness);
    return 0;
}
