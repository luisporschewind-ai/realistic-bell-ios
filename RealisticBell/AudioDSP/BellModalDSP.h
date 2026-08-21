#ifndef BellModalDSP_h
#define BellModalDSP_h

#include <stdbool.h>
#include <stdint.h>

#define BELL_MODAL_MAX_MODES 30
#define BELL_MODAL_EVENT_CAPACITY 32

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float frequency_hz;
    float decay_seconds;
    float gain;
} BellModalMode;

typedef struct {
    double timestamp;
    float strength;
    float normal_speed;
    float contact_x;
    float contact_y;
    float contact_z;
    float tangential_speed;
} BellDSPImpact;

typedef struct BellModalDSP BellModalDSP;

BellModalDSP *BellModalDSPCreate(
    double sample_rate,
    unsigned int channel_count,
    const BellModalMode *modes,
    unsigned int mode_count
);
void BellModalDSPDestroy(BellModalDSP *dsp);
void BellModalDSPReset(BellModalDSP *dsp);
bool BellModalDSPEnqueueImpact(BellModalDSP *dsp, BellDSPImpact impact);
void BellModalDSPRender(
    BellModalDSP *dsp,
    float *left,
    float *right,
    unsigned int frame_count
);

#ifdef __cplusplus
}
#endif

#endif
