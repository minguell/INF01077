#ifndef REPRODUCTION_H
#define REPRODUCTION_H

#include <stddef.h>
#include <stdint.h>

void population_reproduce(const uint8_t *population,
                          uint8_t *next_population,
                          const int *fitness,
                          size_t population_size,
                          size_t bits_per_individual,
                          double mutation_rate,
                          uint64_t base_seed,
                          int generation);

#endif
