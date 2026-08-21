#include "BellModalDSP.h"

#include <math.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define BELL_PI 3.14159265358979323846f

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
    BellDSPImpact events[BELL_MODAL_EVENT_CAPACITY];
    _Atomic unsigned int read_index;
    _Atomic unsigned int write_index;
    uint32_t noise_state;
    float noise_left;
    float noise_right;
    float noise_decay;
};

static float bell_clamp(float value, float minimum, float maximum) {
    return fminf(fmaxf(value, minimum), maximum);
}

static float bell_soft_limit(float value) {
    return value / (1.0f + fabsf(value));
}

static float bell_random_signed(BellModalDSP *dsp) {
    uint32_t value = dsp->noise_state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    dsp->noise_state = value;
    return ((float)(value & 0x00ffffffu) / 8388607.5f) - 1.0f;
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
        float excitation = dsp->modes[index].gain * base_energy *
            brightness * position * dsp->impulse_scale[index];
        dsp->left_y1[index] += excitation * left_gain;
        dsp->right_y1[index] += excitation * right_gain;
    }

    float tangential_speed = bell_clamp(impact.tangential_speed, 0.0f, 1.5f);
    float normal_factor = bell_clamp(normal_speed / 2.0f, 0.0f, 1.0f);
    float transient = tangential_speed * strength * normal_factor * 0.030f;
    dsp->noise_left += transient * left_gain;
    dsp->noise_right += transient * right_gain;
}

static void bell_consume_impacts(BellModalDSP *dsp) {
    unsigned int read = atomic_load_explicit(&dsp->read_index, memory_order_relaxed);
    unsigned int write = atomic_load_explicit(&dsp->write_index, memory_order_acquire);
    while (read != write) {
        bell_apply_impact(dsp, dsp->events[read]);
        read = (read + 1u) % BELL_MODAL_EVENT_CAPACITY;
    }
    atomic_store_explicit(&dsp->read_index, read, memory_order_release);
}

BellModalDSP *BellModalDSPCreate(
    double sample_rate,
    unsigned int channel_count,
    const BellModalMode *modes,
    unsigned int mode_count
) {
    if (!isfinite(sample_rate) || sample_rate <= 0.0 ||
        (channel_count != 1u && channel_count != 2u) ||
        modes == NULL || mode_count == 0u || mode_count > BELL_MODAL_MAX_MODES) {
        return NULL;
    }

    BellModalDSP *dsp = calloc(1, sizeof(BellModalDSP));
    if (dsp == NULL) { return NULL; }
    dsp->sample_rate = sample_rate;
    dsp->channel_count = channel_count;
    dsp->mode_count = mode_count;
    dsp->noise_state = 0x8f31a2c5u;
    dsp->noise_decay = expf(-1.0f / (0.010f * (float)sample_rate));

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
    dsp->noise_left = 0.0f;
    dsp->noise_right = 0.0f;
    dsp->noise_state = 0x8f31a2c5u;
    atomic_store_explicit(&dsp->read_index, 0u, memory_order_relaxed);
    atomic_store_explicit(&dsp->write_index, 0u, memory_order_relaxed);
}

bool BellModalDSPEnqueueImpact(BellModalDSP *dsp, BellDSPImpact impact) {
    if (dsp == NULL) { return false; }
    unsigned int write = atomic_load_explicit(&dsp->write_index, memory_order_relaxed);
    unsigned int next = (write + 1u) % BELL_MODAL_EVENT_CAPACITY;
    unsigned int read = atomic_load_explicit(&dsp->read_index, memory_order_acquire);
    if (next == read) { return false; }
    dsp->events[write] = impact;
    atomic_store_explicit(&dsp->write_index, next, memory_order_release);
    return true;
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

    bell_consume_impacts(dsp);
    for (unsigned int frame = 0; frame < frame_count; frame++) {
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

        left_sample += bell_random_signed(dsp) * dsp->noise_left;
        right_sample += bell_random_signed(dsp) * dsp->noise_right;
        dsp->noise_left *= dsp->noise_decay;
        dsp->noise_right *= dsp->noise_decay;

        left[frame] = bell_soft_limit(left_sample);
        if (right != NULL) {
            right[frame] = bell_soft_limit(
                dsp->channel_count == 1u ? left_sample : right_sample
            );
        }
    }
}
