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

typedef struct {
    double timestamp;
    bool is_touching_wall;
    float normal_acceleration;
    float contact_x;
    float contact_y;
    float contact_z;
    float tangential_speed;
} BellDSPContact;

typedef struct {
    float load_reference;
    float speed_reference;
    float surface_samples_per_meter;
    float excitation_gain;
    float attack_seconds;
    float release_seconds;
    float timeout_seconds;
    unsigned int first_excited_mode_index;
} BellDSPContactProfile;

typedef struct BellModalDSP BellModalDSP;

BellModalDSP *BellModalDSPCreate(
    double sample_rate,
    unsigned int channel_count,
    const BellModalMode *modes,
    unsigned int mode_count,
    const BellDSPContactProfile *contact_profile
);
void BellModalDSPDestroy(BellModalDSP *dsp);
void BellModalDSPReset(BellModalDSP *dsp);
bool BellModalDSPEnqueueImpact(BellModalDSP *dsp, BellDSPImpact impact);
bool BellModalDSPEnqueueContact(BellModalDSP *dsp, BellDSPContact contact);
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
