/* volatile niteliği bir fonksiyon çağrısında düşebilir: parametre sıradan işaretçiyse içerideki erişim korunmaz. */
#include <stdint.h>

void clear(uint32_t *reg);

void reset_uart(void)
{
    clear((volatile uint32_t *)0x4000C000u);
}
