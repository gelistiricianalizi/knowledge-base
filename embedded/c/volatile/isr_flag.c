/* Kesmenin kaldırdığı bayrağı bekleyen döngü. QUALIFIER derlemede verilir: boş ya da volatile. */
#include <stdint.h>

static QUALIFIER uint8_t ready;

void EXTI0_IRQHandler(void)
{
    ready = 1;
}

int wait_for_ready(void)
{
    while (!ready) {
    }
    return 42;
}
