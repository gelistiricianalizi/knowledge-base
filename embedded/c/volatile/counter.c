/* Aynı sayaç iki yolla: volatile ve atomik. */
#include <stdatomic.h>
#include <stdint.h>

volatile uint32_t ticks;
atomic_uint atomic_ticks;

void count_volatile(void)
{
    ticks++;
}

void count_atomic(void)
{
    atomic_fetch_add(&atomic_ticks, 1);
}
