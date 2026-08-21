#include "BellModalDSP.h"

#include <math.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define BELL_PI 3.14159265358979323846f
#define BELL_ROUGHNESS_TABLE_SIZE 1024u

typedef enum {
    BELL_DSP_EVENT_IMPACT,
    BELL_DSP_EVENT_CONTACT,
} BellDSPEventKind;

typedef struct {
    BellDSPEventKind kind;
    union {
        BellDSPImpact impact;
        BellDSPContact contact;
    } payload;
} BellDSPEvent;

struct BellModalDSP {
    double sample_rate;
    unsigned int channel_count;
    unsigned int mode_count;
    BellModalMode modes[BELL_MODAL_MAX_MODES];
    float coefficient[BELL_MODAL_MAX_MODES];
    float radius_squared[BELL_MODAL_MAX_MODES];
    float impulse_scale[BELL_MODAL_MAX_MODES];
    float left_y1[BELL_MODAL_MAX_MODES];
    float left_y2[BELL_MODAL_MAX_MODES];
    float right_y1[BELL_MODAL_MAX_MODES];
    float right_y2[BELL_MODAL_MAX_MODES];
    BellDSPEvent events[BELL_MODAL_EVENT_CAPACITY];
    _Atomic unsigned int read_index;
    _Atomic unsigned int write_index;
    BellDSPContactProfile contact_profile;
    float roughness[BELL_ROUGHNESS_TABLE_SIZE];
    float roughness_phase;
    float previous_roughness;
    float contact_envelope;
    float target_load;
    float current_load;
    float target_speed;
    float current_speed;
    float target_contact_x;
    float current_contact_x;
    float target_contact_z;
    float current_contact_z;
    float attack_coefficient;
    float release_coefficient;
    unsigned int frames_since_contact;
    unsigned int timeout_frames;
    bool contact_target;
};

static float bell_clamp(float value, float minimum, float maximum) {
    return fminf(fmaxf(value, minimum), maximum);
}

static float bell_soft_limit(float value) {
    return value / (1.0f + fabsf(value));
}

static float bell_random_signed(uint32_t *state) {
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return ((float)(value & 0x00ffffffu) / 8388607.5f) - 1.0f;
}

static void bell_initialize_roughness(BellModalDSP *dsp) {
    float raw[BELL_ROUGHNESS_TABLE_SIZE];
    uint32_t state = 0x8f31a2c5u;
    for (unsigned int index = 0; index < BELL_ROUGHNESS_TABLE_SIZE; index++) {
        raw[index] = bell_random_signed(&state);
    }

    float mean = 0.0f;
    float maximum = 0.0f;
    for (unsigned int index = 0; index < BELL_ROUGHNESS_TABLE_SIZE; index++) {
        float fine = 0.0f;
        float coarse = 0.0f;
        for (int offset = -2; offset <= 2; offset++) {
            unsigned int sample = (index + BELL_ROUGHNESS_TABLE_SIZE +
                (unsigned int)offset) % BELL_ROUGHNESS_TABLE_SIZE;
            fine += raw[sample];
        }
        for (int offset = -10; offset <= 10; offset++) {
            unsigned int sample = (index + BELL_ROUGHNESS_TABLE_SIZE +
                (unsigned int)offset) % BELL_ROUGHNESS_TABLE_SIZE;
            coarse += raw[sample];
        }
        float value = fine * 0.14f + coarse * (0.30f / 21.0f);
        dsp->roughness[index] = value;
        mean += value;
    }
    mean /= (float)BELL_ROUGHNESS_TABLE_SIZE;
    for (unsigned int index = 0; index < BELL_ROUGHNESS_TABLE_SIZE; index++) {
        dsp->roughness[index] -= mean;
        maximum = fmaxf(maximum, fabsf(dsp->roughness[index]));
    }
    if (maximum > 0.0f) {
        for (unsigned int index = 0; index < BELL_ROUGHNESS_TABLE_SIZE; index++) {
            dsp->roughness[index] /= maximum;
        }
    }
    dsp->previous_roughness = dsp->roughness[0];
}

static void bell_apply_impact(BellModalDSP *dsp, BellDSPImpact impact) {
    float strength = bell_clamp(impact.strength, 0.0f, 1.0f);
    float normal_speed = bell_clamp(impact.normal_speed, 0.0f, 4.0f);
    float contact_x = bell_clamp(impact.contact_x, -1.0f, 1.0f);
    float contact_z = bell_clamp(impact.contact_z, -1.0f, 1.0f);
    float pan_angle = (contact_x + 1.0f) * (BELL_PI * 0.25f);
    float left_gain = cosf(pan_angle);
    float right_gain = sinf(pan_angle);
    float base_energy = 0.035f + strength * 0.24f + normal_speed * 0.018f;

    for (unsigned int index = 0; index < dsp->mode_count; index++) {
        float normalized_index = dsp->mode_count > 1
            ? (float)index / (float)(dsp->mode_count - 1)
            : 0.0f;
        float brightness = 0.52f + strength * normalized_index * 0.48f;
        float position = 0.82f + 0.18f * cosf(
            ((float)index + 1.0f) * (0.62f + contact_z * 0.31f)
        );
        float tangential_brightness = 1.0f;
        if (index >= dsp->contact_profile.first_excited_mode_index) {
            float tangent = bell_clamp(impact.tangential_speed, 0.0f, 2.0f);
            float normal_factor = bell_clamp(normal_speed / 2.0f, 0.0f, 1.0f);
            tangential_brightness += tangent * strength * normal_factor * 0.45f;
        }
        float excitation = dsp->modes[index].gain * base_energy *
            brightness * position * dsp->impulse_scale[index];
        excitation *= tangential_brightness;
        dsp->left_y1[index] += excitation * left_gain;
        dsp->right_y1[index] += excitation * right_gain;
    }
}

static void bell_apply_contact(BellModalDSP *dsp, BellDSPContact contact) {
    bool finite = isfinite(contact.timestamp) &&
        isfinite(contact.normal_acceleration) &&
        isfinite(contact.contact_x) && isfinite(contact.contact_y) &&
        isfinite(contact.contact_z) && isfinite(contact.tangential_speed);
    dsp->frames_since_contact = 0u;
    if (!finite || !contact.is_touching_wall ||
        contact.normal_acceleration <= 0.0f || contact.tangential_speed <= 0.0f) {
        dsp->contact_target = false;
        dsp->target_load = 0.0f;
        dsp->target_speed = 0.0f;
        return;
    }
    dsp->contact_target = true;
    dsp->target_load = bell_clamp(
        contact.normal_acceleration / dsp->contact_profile.load_reference,
        0.0f,
        3.0f
    );
    dsp->target_speed = bell_clamp(contact.tangential_speed, 0.0f, 3.0f);
    dsp->target_contact_x = bell_clamp(contact.contact_x, -1.0f, 1.0f);
    dsp->target_contact_z = bell_clamp(contact.contact_z, -1.0f, 1.0f);
}

static void bell_consume_events(BellModalDSP *dsp) {
    unsigned int read = atomic_load_explicit(&dsp->read_index, memory_order_relaxed);
    unsigned int write = atomic_load_explicit(&dsp->write_index, memory_order_acquire);
    while (read != write) {
        BellDSPEvent event = dsp->events[read];
        if (event.kind == BELL_DSP_EVENT_IMPACT) {
            bell_apply_impact(dsp, event.payload.impact);
        } else if (event.kind == BELL_DSP_EVENT_CONTACT) {
            bell_apply_contact(dsp, event.payload.contact);
        }
        read = (read + 1u) % BELL_MODAL_EVENT_CAPACITY;
    }
    atomic_store_explicit(&dsp->read_index, read, memory_order_release);
}

BellModalDSP *BellModalDSPCreate(
    double sample_rate,
    unsigned int channel_count,
    const BellModalMode *modes,
    unsigned int mode_count,
    const BellDSPContactProfile *contact_profile
) {
    if (!isfinite(sample_rate) || sample_rate <= 0.0 ||
        (channel_count != 1u && channel_count != 2u) ||
        modes == NULL || mode_count == 0u || mode_count > BELL_MODAL_MAX_MODES ||
        contact_profile == NULL ||
        !isfinite(contact_profile->load_reference) ||
        !isfinite(contact_profile->speed_reference) ||
        !isfinite(contact_profile->surface_samples_per_meter) ||
        !isfinite(contact_profile->excitation_gain) ||
        !isfinite(contact_profile->attack_seconds) ||
        !isfinite(contact_profile->release_seconds) ||
        !isfinite(contact_profile->timeout_seconds) ||
        contact_profile->load_reference <= 0.0f ||
        contact_profile->speed_reference <= 0.0f ||
        contact_profile->surface_samples_per_meter <= 0.0f ||
        contact_profile->excitation_gain < 0.0f ||
        contact_profile->attack_seconds <= 0.0f ||
        contact_profile->release_seconds <= 0.0f ||
        contact_profile->timeout_seconds <= 0.0f ||
        contact_profile->first_excited_mode_index >= mode_count) {
        return NULL;
    }

    BellModalDSP *dsp = calloc(1, sizeof(BellModalDSP));
    if (dsp == NULL) { return NULL; }
    dsp->sample_rate = sample_rate;
    dsp->channel_count = channel_count;
    dsp->mode_count = mode_count;
    dsp->contact_profile = *contact_profile;
    dsp->attack_coefficient = expf(
        -1.0f / (contact_profile->attack_seconds * (float)sample_rate)
    );
    dsp->release_coefficient = expf(
        -1.0f / (contact_profile->release_seconds * (float)sample_rate)
    );
    dsp->timeout_frames = (unsigned int)ceil(
        contact_profile->timeout_seconds * (float)sample_rate
    );
    dsp->frames_since_contact = dsp->timeout_frames + 1u;

    for (unsigned int index = 0; index < mode_count; index++) {
        BellModalMode mode = modes[index];
        if (!isfinite(mode.frequency_hz) || !isfinite(mode.decay_seconds) ||
            !isfinite(mode.gain) || mode.frequency_hz <= 0.0f ||
            mode.frequency_hz >= (float)(sample_rate * 0.5) ||
            mode.decay_seconds <= 0.0f || mode.gain < 0.0f) {
            free(dsp);
            return NULL;
        }
        dsp->modes[index] = mode;
        float omega = 2.0f * BELL_PI * mode.frequency_hz / (float)sample_rate;
        float radius = expf(
            logf(0.001f) / (mode.decay_seconds * (float)sample_rate)
        );
        dsp->coefficient[index] = 2.0f * radius * cosf(omega);
        dsp->radius_squared[index] = radius * radius;
        dsp->impulse_scale[index] = sinf(omega);
    }

    bell_initialize_roughness(dsp);
    atomic_init(&dsp->read_index, 0u);
    atomic_init(&dsp->write_index, 0u);
    return dsp;
}

void BellModalDSPDestroy(BellModalDSP *dsp) {
    free(dsp);
}

void BellModalDSPReset(BellModalDSP *dsp) {
    if (dsp == NULL) { return; }
    memset(dsp->left_y1, 0, sizeof(dsp->left_y1));
    memset(dsp->left_y2, 0, sizeof(dsp->left_y2));
    memset(dsp->right_y1, 0, sizeof(dsp->right_y1));
    memset(dsp->right_y2, 0, sizeof(dsp->right_y2));
    dsp->roughness_phase = 0.0f;
    dsp->previous_roughness = dsp->roughness[0];
    dsp->contact_envelope = 0.0f;
    dsp->target_load = 0.0f;
    dsp->current_load = 0.0f;
    dsp->target_speed = 0.0f;
    dsp->current_speed = 0.0f;
    dsp->target_contact_x = 0.0f;
    dsp->current_contact_x = 0.0f;
    dsp->target_contact_z = 0.0f;
    dsp->current_contact_z = 0.0f;
    dsp->frames_since_contact = dsp->timeout_frames + 1u;
    dsp->contact_target = false;
    atomic_store_explicit(&dsp->read_index, 0u, memory_order_relaxed);
    atomic_store_explicit(&dsp->write_index, 0u, memory_order_relaxed);
}

static bool bell_enqueue_event(BellModalDSP *dsp, BellDSPEvent event) {
    if (dsp == NULL) { return false; }
    unsigned int write = atomic_load_explicit(&dsp->write_index, memory_order_relaxed);
    unsigned int next = (write + 1u) % BELL_MODAL_EVENT_CAPACITY;
    unsigned int read = atomic_load_explicit(&dsp->read_index, memory_order_acquire);
    if (next == read) { return false; }
    dsp->events[write] = event;
    atomic_store_explicit(&dsp->write_index, next, memory_order_release);
    return true;
}

bool BellModalDSPEnqueueImpact(BellModalDSP *dsp, BellDSPImpact impact) {
    BellDSPEvent event = {
        .kind = BELL_DSP_EVENT_IMPACT,
        .payload.impact = impact,
    };
    return bell_enqueue_event(dsp, event);
}

bool BellModalDSPEnqueueContact(BellModalDSP *dsp, BellDSPContact contact) {
    BellDSPEvent event = {
        .kind = BELL_DSP_EVENT_CONTACT,
        .payload.contact = contact,
    };
    return bell_enqueue_event(dsp, event);
}

static float bell_smoothed_value(float current, float target, float coefficient) {
    return target + coefficient * (current - target);
}

static void bell_render_contact_excitation(BellModalDSP *dsp) {
    if (dsp->frames_since_contact < UINT32_MAX) {
        dsp->frames_since_contact++;
    }
    if (dsp->frames_since_contact > dsp->timeout_frames) {
        dsp->contact_target = false;
        dsp->target_load = 0.0f;
        dsp->target_speed = 0.0f;
    }

    float envelope_target = dsp->contact_target ? 1.0f : 0.0f;
    float smoothing = envelope_target > dsp->contact_envelope
        ? dsp->attack_coefficient
        : dsp->release_coefficient;
    dsp->contact_envelope = bell_smoothed_value(
        dsp->contact_envelope,
        envelope_target,
        smoothing
    );
    dsp->current_load = bell_smoothed_value(
        dsp->current_load,
        dsp->target_load,
        smoothing
    );
    dsp->current_speed = bell_smoothed_value(
        dsp->current_speed,
        dsp->target_speed,
        smoothing
    );
    dsp->current_contact_x = bell_smoothed_value(
        dsp->current_contact_x,
        dsp->target_contact_x,
        dsp->attack_coefficient
    );
    dsp->current_contact_z = bell_smoothed_value(
        dsp->current_contact_z,
        dsp->target_contact_z,
        dsp->attack_coefficient
    );

    if (dsp->contact_envelope <= 0.000001f ||
        dsp->current_load <= 0.000001f || dsp->current_speed <= 0.000001f) {
        return;
    }

    float phase_increment = dsp->current_speed *
        dsp->contact_profile.surface_samples_per_meter / (float)dsp->sample_rate;
    dsp->roughness_phase += phase_increment;
    while (dsp->roughness_phase >= (float)BELL_ROUGHNESS_TABLE_SIZE) {
        dsp->roughness_phase -= (float)BELL_ROUGHNESS_TABLE_SIZE;
    }
    unsigned int first = (unsigned int)dsp->roughness_phase;
    unsigned int second = (first + 1u) % BELL_ROUGHNESS_TABLE_SIZE;
    float fraction = dsp->roughness_phase - (float)first;
    float roughness = dsp->roughness[first] +
        (dsp->roughness[second] - dsp->roughness[first]) * fraction;
    float high_pass_change = roughness - dsp->previous_roughness;
    dsp->previous_roughness = roughness;
    float micro_collision = fmaxf(high_pass_change, 0.0f);
    if (micro_collision <= 0.0f) { return; }

    float speed_ratio = bell_clamp(
        dsp->current_speed / dsp->contact_profile.speed_reference,
        0.0f,
        3.0f
    );
    float force = micro_collision * dsp->contact_envelope *
        dsp->current_load * speed_ratio * dsp->contact_profile.excitation_gain;
    float pan_angle = (dsp->current_contact_x + 1.0f) * (BELL_PI * 0.25f);
    float left_gain = cosf(pan_angle);
    float right_gain = sinf(pan_angle);
    unsigned int first_mode = dsp->contact_profile.first_excited_mode_index;
    unsigned int excited_count = dsp->mode_count - first_mode;

    for (unsigned int index = first_mode; index < dsp->mode_count; index++) {
        float normalized_index = excited_count > 1u
            ? (float)(index - first_mode) / (float)(excited_count - 1u)
            : 0.0f;
        float spectral_tilt = 0.45f + normalized_index *
            (0.25f + 0.30f * bell_clamp(speed_ratio, 0.0f, 1.5f));
        float position = 0.84f + 0.16f * cosf(
            ((float)index + 1.0f) * (0.62f + dsp->current_contact_z * 0.31f)
        );
        float excitation = force * dsp->modes[index].gain *
            dsp->impulse_scale[index] * spectral_tilt * position;
        dsp->left_y1[index] += excitation * left_gain;
        dsp->right_y1[index] += excitation * right_gain;
    }
}

void BellModalDSPRender(
    BellModalDSP *dsp,
    float *left,
    float *right,
    unsigned int frame_count
) {
    if (left == NULL || frame_count == 0u) { return; }
    if (dsp == NULL) {
        memset(left, 0, sizeof(float) * frame_count);
        if (right != NULL) { memset(right, 0, sizeof(float) * frame_count); }
        return;
    }

    bell_consume_events(dsp);
    for (unsigned int frame = 0; frame < frame_count; frame++) {
        bell_render_contact_excitation(dsp);
        float left_sample = 0.0f;
        float right_sample = 0.0f;
        for (unsigned int index = 0; index < dsp->mode_count; index++) {
            float next_left = dsp->coefficient[index] * dsp->left_y1[index] -
                dsp->radius_squared[index] * dsp->left_y2[index];
            float next_right = dsp->coefficient[index] * dsp->right_y1[index] -
                dsp->radius_squared[index] * dsp->right_y2[index];
            dsp->left_y2[index] = dsp->left_y1[index];
            dsp->left_y1[index] = next_left;
            dsp->right_y2[index] = dsp->right_y1[index];
            dsp->right_y1[index] = next_right;
            left_sample += next_left;
            right_sample += next_right;
        }

        left[frame] = bell_soft_limit(left_sample);
        if (right != NULL) {
            right[frame] = bell_soft_limit(
                dsp->channel_count == 1u ? left_sample : right_sample
            );
        }
    }
}
