#include "include/rng.h"

/* A sequential execution has one pseudo-random generator state. */
static uint64_t rng_state = 42;

void rng_seed(uint64_t seed) {
    rng_state = seed;
}

uint64_t rng64(void) {
    return rng64_from_state(&rng_state);
}

size_t rng_index(size_t limit) {
    return rng_index_from_state(&rng_state, limit);
}

double rng_unit(void) {
    return rng_unit_from_state(&rng_state);
}

uint64_t rng64_from_state(uint64_t *state) {
    uint64_t x = *state;

    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;

    *state = x;
    return x;
}

size_t rng_index_from_state(uint64_t *state, size_t limit) {
    return (size_t)(rng64_from_state(state) % limit);
}

double rng_unit_from_state(uint64_t *state) {
    return (rng64_from_state(state) >> 11) * (1.0 / 9007199254740992.0);
}

uint64_t rng_seed_for_individual(uint64_t base_seed,
                                 int generation,
                                 size_t individual) {
    uint64_t state = base_seed;

    state ^= (uint64_t)(generation + 1) * UINT64_C(0x9E3779B97F4A7C15);
    state ^= (uint64_t)(individual + 1) * UINT64_C(0xBF58476D1CE4E5B9);
    return state == 0 ? 1 : state;
}
