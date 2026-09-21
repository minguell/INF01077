#include "include/rng.h"

uint64_t rng64(uint64_t *state) {
    uint64_t x = *state;

    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;

    *state = x;
    return x;
}

size_t rng_index(uint64_t *state, size_t limit) {
    return (size_t)(rng64(state) % limit);
}

double rng_unit(uint64_t *state) {
    return (rng64(state) >> 11) * (1.0 / 9007199254740992.0);
}

uint64_t rng_seed_for_individual(uint64_t base_seed,
                                 int generation,
                                 size_t individual) {
    uint64_t state = base_seed;

    state ^= (uint64_t)(generation + 1) * UINT64_C(0x9E3779B97F4A7C15);
    state ^= (uint64_t)(individual + 1) * UINT64_C(0xBF58476D1CE4E5B9);
    return state == 0 ? 1 : state;
}
