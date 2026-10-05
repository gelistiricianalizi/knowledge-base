/* Bellek eşlemeli yazmaç: adres sabittir, değeri donanım değiştirir. Adresler örnektir. */
#include <stdint.h>

#define UART_DATA   (*(QUALIFIER uint32_t *)0x4000C000u)
#define UART_STATUS (*(QUALIFIER uint32_t *)0x4000C018u)

void send_abc(void)
{
    UART_DATA = 'A';
    UART_DATA = 'B';
    UART_DATA = 'C';
}

/* İki okuma arasında değişen bitler. */
uint32_t changed_status_bits(void)
{
    uint32_t first = UART_STATUS;
    uint32_t second = UART_STATUS;
    return first ^ second;
}
