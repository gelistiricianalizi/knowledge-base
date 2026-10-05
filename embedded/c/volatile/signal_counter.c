/* volatile atomik değildir: ana döngü ve sinyal işleyicisi aynı sayacı artırır.
 * -DATOMIC ile aynı program sayacı atomik artırır. */
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/time.h>

#define MAIN_INCREMENTS 100000000u
#define TICK_MICROSECONDS 50

#ifdef ATOMIC
static atomic_uint counter;
#define INCREMENT() atomic_fetch_add(&counter, 1)
#else
static volatile uint32_t counter;
#define INCREMENT() (counter++)
#endif

/* Yalnız işleyici yazar; ana program zamanlayıcı durduktan sonra okur. */
static volatile sig_atomic_t handler_increments;

static void on_tick(int signal_number)
{
    (void)signal_number;
    INCREMENT();
    handler_increments++;
}

int main(void)
{
    const struct itimerval every_tick = {{0, TICK_MICROSECONDS}, {0, TICK_MICROSECONDS}};
    const struct itimerval stopped = {{0, 0}, {0, 0}};

    signal(SIGALRM, on_tick);
    setitimer(ITIMER_REAL, &every_tick, NULL);
    for (uint32_t i = 0; i < MAIN_INCREMENTS; i++) {
        INCREMENT();
    }
    setitimer(ITIMER_REAL, &stopped, NULL);
    signal(SIGALRM, SIG_IGN);

    uint32_t expected = MAIN_INCREMENTS + (uint32_t)handler_increments;
    uint32_t actual = (uint32_t)counter;
    printf("sinyal %u · beklenen %u · sayaç %u · kayıp %u\n",
           (unsigned)handler_increments, (unsigned)expected, (unsigned)actual, (unsigned)(expected - actual));
    return 0;
}
