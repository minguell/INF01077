#include "include/population.h"
#include "include/rng.h"

#include <omp.h>

static int individual_evaluate(const uint8_t *individual,
                               size_t bits_per_individual) {
    int fitness = 0;

    for (size_t bit = 0; bit < bits_per_individual; bit++) {
        fitness += individual[bit];
    }

    return fitness;
}

/* Initialization runs once; the per-generation work is parallelized below. */
void population_initialize(uint8_t *population,
                           size_t population_size,
                           size_t bits_per_individual,
                           uint64_t *state) {
    for (size_t i = 0; i < population_size * bits_per_individual; i++) {
        population[i] = rng64(state) & 1u;
    }
}

int population_evaluate(const uint8_t *population,
                        int *fitness,
                        size_t population_size,
                        size_t bits_per_individual) {
    #pragma omp parallel for schedule(static)
    for (size_t i = 0; i < population_size; i++) {
        fitness[i] = individual_evaluate(population + i * bits_per_individual,
                                         bits_per_individual);
    }

    int best = 0;
    for (size_t i = 0; i < population_size; i++) {
        if (fitness[i] > best) {
            best = fitness[i];
        }
    }

    return best;
}
