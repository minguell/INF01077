#ifndef POPULATION_H
#define POPULATION_H

#include <stddef.h>
#include <stdint.h>

void population_initialize(uint8_t *population,
                           size_t population_size,
                           size_t bits_per_individual,
                           uint64_t *state);
int population_evaluate(const uint8_t *population,
                        int *fitness,
                        size_t population_size,
                        size_t bits_per_individual);

#endif
