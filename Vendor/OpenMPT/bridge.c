#include "AtelierOpenMPT.h"
#include "libopenmpt_ext.h"
#include <stdlib.h>
struct ATModule {
    openmpt_module_ext *ext;
    openmpt_module_ext_interface_interactive interactive;
};
ATModule *at_create(const void *bytes, size_t count) {
    ATModule *handle = calloc(1,sizeof(*handle));
    if(!handle) return NULL;
    handle->ext = openmpt_module_ext_create_from_memory(bytes,count,openmpt_log_func_silent,NULL,NULL,NULL,NULL,NULL,NULL);
    if(!handle->ext) { free(handle); return NULL; }
    openmpt_module_ext_get_interface(handle->ext,LIBOPENMPT_EXT_C_INTERFACE_INTERACTIVE,&handle->interactive,sizeof(handle->interactive));
    return handle;
}
openmpt_module *at_base(ATModule *handle) { return openmpt_module_ext_get_module(handle->ext); }
void at_destroy(ATModule *handle) { if(handle) {openmpt_module_ext_destroy(handle->ext); free(handle);} }
int at_mute(ATModule *handle,int channel,int mute) {
    return handle->interactive.set_channel_mute_status ? handle->interactive.set_channel_mute_status(handle->ext,channel,mute) : 0;
}
int at_play_note(ATModule *handle,int instrument,int note) {
    return handle->interactive.play_note ? handle->interactive.play_note(handle->ext,instrument,note,1.0,0.0) : -1;
}
int at_play_velocity(ATModule *handle,int instrument,int note,double volume) {
    return handle->interactive.play_note ? handle->interactive.play_note(handle->ext,instrument,note,volume,0.0) : -1;
}
void at_stop_note(ATModule *handle,int channel) {
    if(channel>=0 && handle->interactive.stop_note) handle->interactive.stop_note(handle->ext,channel);
}
