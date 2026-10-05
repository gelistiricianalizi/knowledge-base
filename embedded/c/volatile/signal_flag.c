/* Kesme yerine sinyal: SIGALRM işleyicisi bir saniye sonra bayrağı kaldırır, ana döngü onu bekler. */
#include <signal.h>
#include <unistd.h>

static QUALIFIER sig_atomic_t ready;

static void on_alarm(int signal_number)
{
    (void)signal_number;
    ready = 1;
}

int main(void)
{
    signal(SIGALRM, on_alarm);
    alarm(1);
    while (!ready) {
    }
    return 0;
}
