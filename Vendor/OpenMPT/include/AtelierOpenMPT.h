#pragma once
#include "libopenmpt.h"
typedef struct ATModule ATModule;
ATModule *at_create(const void *bytes, size_t count);
openmpt_module *at_base(ATModule *handle);
void at_destroy(ATModule *handle);
int at_mute(ATModule *handle,int channel,int mute);
int at_play_note(ATModule *handle,int instrument,int note);
int at_play_velocity(ATModule *handle,int instrument,int note,double volume);
void at_stop_note(ATModule *handle,int channel);
