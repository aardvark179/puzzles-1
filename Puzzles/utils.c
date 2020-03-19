#include <time.h>

#include "puzzles.h"
#include "frontend.h"

void frontend_default_colour(frontend *fe, float *output)
{
    fe->default_colour(fe, output);
}

void fatal(const char *fmt, ...)
{
}

bool frontend_default_colour_for(frontend *fe, int colour, float* output) {
    return false;
}

void get_random_seed(void **randseed, int *randseedsize)
{
    time_t *tp = snew(time_t);
    time(tp);
    *randseed = (void *)tp;
    *randseedsize = sizeof(time_t);
}

void activate_timer(frontend *fe)
{
    fe->activate_timer(fe);
}

void deactivate_timer(frontend *fe)
{
    fe->deactivate_timer(fe);
}
