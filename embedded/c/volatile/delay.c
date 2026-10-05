/* Boş döngüyle gecikme. */
#include <stdint.h>

void delay(void)
{
    for (QUALIFIER uint32_t i = 0; i < 100000u; i++) {
    }
}
