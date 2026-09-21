CC := gcc
CFLAGS := -O2 -g -std=c11 -Wall -Wextra -Wpedantic -Iinclude
TARGET := ga_seq
SOURCES := main.c ga.c population.c reproduction.c rng.c
OBJECTS := $(SOURCES:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)
