CC := gcc
CFLAGS := -O2 -g -std=c11 -Wall -Wextra -Wpedantic -fopenmp -Iinclude
LDFLAGS := -fopenmp
TARGET := ga_seq_paralelizado
SOURCES := main.c ga.c population.c reproduction.c rng.c
OBJECTS := $(SOURCES:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)
