#ifndef RNG_H
#define RNG_H

#include <stddef.h>
#include <stdint.h>

uint64_t rng64(uint64_t *state);
size_t rng_index(uint64_t *state, size_t limit);
double rng_unit(uint64_t *state);
uint64_t rng_seed_for_individual(uint64_t base_seed,
                                 int generation,
                                 size_t individual);

#endif
