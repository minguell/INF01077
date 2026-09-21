#include "include/ga.h"

#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static int parse_size(const char *text, size_t *value) {
    char *end;

    if (*text == '-') return 0;
    errno = 0;
    const unsigned long long parsed = strtoull(text, &end, 10);
    if (errno == ERANGE || *text == '\0' || *end != '\0' || parsed > SIZE_MAX) {
        return 0;
    }

    *value = (size_t)parsed;
    return 1;
}

static int parse_seed(const char *text, uint64_t *value) {
    char *end;

    if (*text == '-') return 0;
    errno = 0;
    const unsigned long long parsed = strtoull(text, &end, 10);
    if (errno == ERANGE || *text == '\0' || *end != '\0' || parsed > UINT64_MAX) {
        return 0;
    }

    *value = (uint64_t)parsed;
    return 1;
}

static int parse_generations(const char *text, int *value) {
    char *end;

    errno = 0;
    const long parsed = strtol(text, &end, 10);
    if (errno == ERANGE || *text == '\0' || *end != '\0' ||
        parsed < 1 || parsed > INT_MAX) {
        return 0;
    }

    *value = (int)parsed;
    return 1;
}

static int parse_rate(const char *text, double *value) {
    char *end;

    errno = 0;
    const double parsed = strtod(text, &end);
    if (errno == ERANGE || *text == '\0' || *end != '\0' || !isfinite(parsed)) {
        return 0;
    }

    *value = parsed;
    return 1;
}

static int config_is_valid(const GAConfig *config) {
    return config->population_size >= 2 &&
           config->bits_per_individual >= 2 &&
           config->bits_per_individual <= INT_MAX &&
           config->generations >= 1 &&
           config->mutation_rate >= 0.0 &&
           config->mutation_rate <= 1.0 &&
           config->seed != 0;
}

int main(int argc, char **argv) {
    GAConfig config = {
        .population_size = 1000,
        .bits_per_individual = 1000,
        .generations = 200,
        .mutation_rate = 0.001,
        .seed = 42,
    };

    if (argc > 1 && !parse_size(argv[1], &config.population_size)) goto usage;
    if (argc > 2 && !parse_size(argv[2], &config.bits_per_individual)) goto usage;
    config.mutation_rate = 1.0 / config.bits_per_individual;
    if (argc > 3 && !parse_generations(argv[3], &config.generations)) goto usage;
    if (argc > 4 && !parse_rate(argv[4], &config.mutation_rate)) goto usage;
    if (argc > 5 && !parse_seed(argv[5], &config.seed)) goto usage;

    if (!config_is_valid(&config)) {
usage:
        fprintf(stderr, "Uso: %s [populacao] [bits] [geracoes] [mutacao] [seed]\n", argv[0]);
        return 1;
    }

    int global_best;
    double elapsed_seconds;
    if (ga_run(&config, &global_best, &elapsed_seconds) != 0) return 1;

    printf("Melhor fitness: %d/%zu\n", global_best, config.bits_per_individual);
    printf("Tempo: %.6f s\n", elapsed_seconds);
    return 0;
}
