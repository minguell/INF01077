#ifndef RNG_H
#define RNG_H

#include <stddef.h>
#include <stdint.h>

void rng_seed(uint64_t seed);
uint64_t rng64(void);
size_t rng_index(size_t limit);
double rng_unit(void);
uint64_t rng64_from_state(uint64_t *state);
size_t rng_index_from_state(uint64_t *state, size_t limit);
double rng_unit_from_state(uint64_t *state);
uint64_t rng_seed_for_individual(uint64_t base_seed,
                                 int generation,
                                 size_t individual);

#endif
