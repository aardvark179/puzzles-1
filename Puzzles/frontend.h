//
//  frontend.h
//  Puzzles
//
//  Created by Duncan MacGregor on 05/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

#ifndef frontend_h
#define frontend_h
#include <stdbool.h>

struct frontend {
    void *gv;
    float *colours;
    int ncolours;
    bool clipping;
    void (*activate_timer)(frontend *);
    void (*deactivate_timer)(frontend *);
    void (*default_colour)(frontend *, float *);
};

// Game instances we will want to refer to
extern const game filling;
extern const game keen;
extern const game map;
extern const game net;
extern const game pattern;
extern const game solo;
extern const game towers;
extern const game undead;
extern const game unequal;
extern const game untangle;

static const game *filling_ptr = &filling;
static const game *keen_ptr = &keen;
static const game *map_ptr = &map;
static const game *net_ptr = &net;
static const game *pattern_ptr = &pattern;
static const game *solo_ptr = &solo;
static const game *towers_ptr = &towers;
static const game *undead_ptr = &undead;
static const game *unequal_ptr = &unequal;
static const game *untangle_ptr = &untangle;
static const game **swift_gamelist = gamelist;
#endif /* frontend_h */
