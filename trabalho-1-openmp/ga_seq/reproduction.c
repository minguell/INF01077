#include "include/reproduction.h"
#include "include/rng.h"

static size_t tournament_select(const int *fitness,
                                size_t population_size,
                                uint64_t *state) {
    const size_t first = rng_index_from_state(state, population_size);
    const size_t second = rng_index_from_state(state, population_size);

    return fitness[first] >= fitness[second] ? first : second;
}

void population_reproduce(const uint8_t *population,
                          uint8_t *next_population,
                          const int *fitness,
                          size_t population_size,
                          size_t bits_per_individual,
                          double mutation_rate,
                          uint64_t base_seed,
                          int generation) {
    for (size_t i = 0; i < population_size; i++) {
        uint64_t state = rng_seed_for_individual(base_seed, generation, i);
        const size_t first_parent = tournament_select(fitness, population_size, &state);
        const size_t second_parent = tournament_select(fitness, population_size, &state);
        const size_t cut = 1 + rng_index_from_state(&state, bits_per_individual - 1);
        const uint8_t *parent1 = population + first_parent * bits_per_individual;
        const uint8_t *parent2 = population + second_parent * bits_per_individual;
        uint8_t *child = next_population + i * bits_per_individual;

        for (size_t bit = 0; bit < bits_per_individual; bit++) {
            child[bit] = bit < cut ? parent1[bit] : parent2[bit];
            if (rng_unit_from_state(&state) < mutation_rate) {
                child[bit] ^= 1u;
            }
        }
    }
}
