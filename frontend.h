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

static game *filling_ptr = &filling;
static game *keen_ptr = &keen;
static game *map_ptr = &map;
static game *net_ptr = &net;
static game *pattern_ptr = &pattern;
static game *solo_ptr = &solo;
static game *towers_ptr = &towers;
static game *undead_ptr = &undead;
static game *unequal_ptr = &unequal;
static game *untangle_ptr = &untangle;
static game **swift_gamelist = gamelist;
#endif /* frontend_h */
