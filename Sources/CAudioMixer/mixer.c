#include "AtelierMixer.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#define MAX_TRACKS 32
struct ATMix {
 const int16_t *tracks[MAX_TRACKS]; int count,clamp,initialized;
 int64_t start,end;
 _Atomic int64_t position;
 _Atomic int playing,loop,clipped;
 _Atomic float targetL[MAX_TRACKS],targetR[MAX_TRACKS],peaks[MAX_TRACKS],peakL,peakR;
 float gainL[MAX_TRACKS],gainR[MAX_TRACKS];
};
static void peak(_Atomic float *target,float value) {float old=atomic_load(target);while(value>old && !atomic_compare_exchange_weak(target,&old,value)) {}}
ATMix *atm_create(const int16_t *const *tracks,int count,int64_t frames,int64_t start,int64_t end,int clamp) {
 if(count<1 || count>MAX_TRACKS || start<0 || end<=start || end>frames) return NULL;
 ATMix *m=calloc(1,sizeof(*m)); if(!m) return NULL;
 m->count=count;m->start=start;m->end=end;m->clamp=clamp;
 atomic_init(&m->position,start);atomic_init(&m->playing,0);atomic_init(&m->loop,0);atomic_init(&m->clipped,0);
 atomic_init(&m->peakL,0);atomic_init(&m->peakR,0);
 for(int c=0;c<count;c++){if(!tracks[c]){free(m);return NULL;}m->tracks[c]=tracks[c];atomic_init(&m->targetL[c],1);atomic_init(&m->targetR[c],1);atomic_init(&m->peaks[c],0);m->gainL[c]=m->gainR[c]=1;}
 return m;
}
void atm_destroy(ATMix *m){free(m);}
void atm_gain(ATMix *m,int c,float l,float r){if(c<0||c>=m->count)return;atomic_store(&m->targetL[c],isfinite(l)?fmaxf(0,fminf(2,l)):0);atomic_store(&m->targetR[c],isfinite(r)?fmaxf(0,fminf(2,r)):0);}
void atm_playing(ATMix *m,int p){atomic_store(&m->playing,p!=0);}
int atm_is_playing(ATMix *m){return atomic_load(&m->playing);}
void atm_loop(ATMix *m,int p){atomic_store(&m->loop,p!=0);}
void atm_seek(ATMix *m,int64_t frame){atomic_store(&m->position,frame<m->start?m->start:frame>m->end?m->end:frame);}
int64_t atm_position(ATMix *m){return atomic_load(&m->position);}
void atm_render(ATMix *m,int count,float *left,float *right){
 if(count<=0)return;
 memset(left,0,count*sizeof(float));memset(right,0,count*sizeof(float));if(!atomic_load(&m->playing))return;
 int64_t original=atomic_load(&m->position),frame=original;
 int loop=atomic_load(&m->loop),ended=0,clip=0;
 float tl[MAX_TRACKS],tr[MAX_TRACKS],peaks[MAX_TRACKS]={0},pl=0,pr=0;
 for(int c=0;c<m->count;c++){tl[c]=atomic_load(&m->targetL[c]);tr[c]=atomic_load(&m->targetR[c]);}
 if(!m->initialized){for(int c=0;c<m->count;c++){m->gainL[c]=tl[c];m->gainR[c]=tr[c];}m->initialized=1;}
 for(int i=0;i<count;i++){
  if(frame>=m->end){if(loop)frame=m->start;else{ended=1;break;}}
  float l=0,r=0;
  float fade=1;if(loop){int64_t edge=frame-m->start,tail=m->end-1-frame;if(edge<88)fade=fminf(fade,(float)edge/88);if(tail<88)fade=fminf(fade,(float)tail/88);}
  for(int c=0;c<m->count;c++){
   /* 10 ms per unit of gain (up to 20 ms), click-resistant smoothing, independent of callback size. */
   float step=1.0f/441.0f;
   m->gainL[c]+=fmaxf(-step,fminf(step,tl[c]-m->gainL[c]));m->gainR[c]+=fmaxf(-step,fminf(step,tr[c]-m->gainR[c]));
   float vl=(float)m->tracks[c][frame*2]/32768*m->gainL[c]*fade;
   float vr=(float)m->tracks[c][frame*2+1]/32768*m->gainR[c]*fade;
   l+=vl;r+=vr;peaks[c]=fmaxf(peaks[c],fmaxf(fabsf(vl),fabsf(vr)));
  }
  pl=fmaxf(pl,fabsf(l));pr=fmaxf(pr,fabsf(r));if(fabsf(l)>1||fabsf(r)>1)clip=1;
  left[i]=m->clamp?fmaxf(-1,fminf(1,l)):l;right[i]=m->clamp?fmaxf(-1,fminf(1,r)):r;frame++;
 }
 int committed=atomic_compare_exchange_strong(&m->position,&original,frame);
 if(ended && committed && !loop)atomic_store(&m->playing,0);
 for(int c=0;c<m->count;c++)peak(&m->peaks[c],peaks[c]);peak(&m->peakL,pl);peak(&m->peakR,pr);if(clip)atomic_store(&m->clipped,1);
}
void atm_peaks(ATMix *m,float *tracks,float *left,float *right,int *clipped){for(int c=0;c<m->count;c++)tracks[c]=atomic_exchange(&m->peaks[c],0);*left=atomic_exchange(&m->peakL,0);*right=atomic_exchange(&m->peakR,0);*clipped=atomic_exchange(&m->clipped,0);}
