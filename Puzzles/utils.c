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

bool frontend_default_colour_for(frontend *fe, float* output, int logical_colour) {
    return fe->default_colour_for(fe, output, logical_colour);
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
