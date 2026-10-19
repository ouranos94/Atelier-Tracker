#pragma once
#include <stdint.h>
typedef struct ATMix ATMix;
ATMix *atm_create(const int16_t *const *tracks,int count,int64_t frames,int64_t start,int64_t end,int clamp);
void atm_destroy(ATMix *m);
void atm_gain(ATMix *m,int channel,float left,float right);
void atm_playing(ATMix *m,int playing);
int atm_is_playing(ATMix *m);
void atm_loop(ATMix *m,int loop);
void atm_seek(ATMix *m,int64_t frame);
int64_t atm_position(ATMix *m);
void atm_render(ATMix *m,int count,float *left,float *right);
void atm_peaks(ATMix *m,float *tracks,float *left,float *right,int *clipped);
