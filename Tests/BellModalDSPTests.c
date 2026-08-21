#include "BellModalDSP.h"

#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#define SAMPLE_RATE 48000.0
#define BLOCK_SIZE 128u

static const BellModalMode kModes[] = {
    {680.0f, 1.80f, 0.38f},
    {942.0f, 1.55f, 0.26f},
    {1247.0f, 1.30f, 0.22f},
    {1683.0f, 1.05f, 0.18f},
    {2104.0f, 0.90f, 0.14f},
    {2731.0f, 0.72f, 0.11f},
    {3408.0f, 0.58f, 0.09f},
    {4267.0f, 0.46f, 0.07f},
    {5119.0f, 0.36f, 0.055f},
    {6381.0f, 0.28f, 0.042f},
    {7744.0f, 0.22f, 0.032f},
    {9216.0f, 0.17f, 0.024f},
};

static BellDSPImpact impact_with_normal_speed(
    float strength,
    float normal_speed,
    float contact_x,
    float contact_z,
    float tangent
) {
    BellDSPImpact value = {
        .timestamp = 1.0,
        .strength = strength,
        .normal_speed = normal_speed,
        .contact_x = contact_x,
        .contact_y = -0.9f,
        .contact_z = contact_z,
        .tangential_speed = tangent,
    };
    return value;
}

static BellDSPImpact impact(float strength, float contact_x, float contact_z, float tangent) {
    return impact_with_normal_speed(strength, 1.2f, contact_x, contact_z, tangent);
}

static BellModalDSP *make_dsp(void) {
    BellModalDSP *dsp = BellModalDSPCreate(
        SAMPLE_RATE,
        2,
        kModes,
        (unsigned int)(sizeof(kModes) / sizeof(kModes[0]))
    );
    assert(dsp != NULL);
    return dsp;
}

static void test_queue_bounds_and_recovery(void) {
    BellModalDSP *dsp = make_dsp();
    BellDSPImpact event = impact(0.5f, 0.0f, 0.0f, 0.0f);

    for (unsigned int index = 0; index < BELL_MODAL_EVENT_CAPACITY - 1; index++) {
        assert(BellModalDSPEnqueueImpact(dsp, event));
    }
    assert(!BellModalDSPEnqueueImpact(dsp, event));

    float left[BLOCK_SIZE] = {0};
    float right[BLOCK_SIZE] = {0};
    BellModalDSPRender(dsp, left, right, BLOCK_SIZE);
    assert(BellModalDSPEnqueueImpact(dsp, event));
    BellModalDSPDestroy(dsp);
}

static void test_output_is_bounded_stereo_and_decays(void) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueImpact(dsp, impact(0.72f, 0.35f, 0.28f, 0.0f)));

    const unsigned int total_frames = (unsigned int)(SAMPLE_RATE * 2.0);
    double first_quarter_energy = 0.0;
    double final_quarter_energy = 0.0;
    double left_energy = 0.0;
    double right_energy = 0.0;
    float peak = 0.0f;
    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];

    for (unsigned int start = 0; start < total_frames; start += BLOCK_SIZE) {
        unsigned int count = total_frames - start;
        if (count > BLOCK_SIZE) { count = BLOCK_SIZE; }
        BellModalDSPRender(dsp, left, right, count);
        for (unsigned int frame = 0; frame < count; frame++) {
            float absolute_left = fabsf(left[frame]);
            float absolute_right = fabsf(right[frame]);
            if (absolute_left > peak) { peak = absolute_left; }
            if (absolute_right > peak) { peak = absolute_right; }
            assert(isfinite(left[frame]));
            assert(isfinite(right[frame]));
            left_energy += (double)left[frame] * left[frame];
            right_energy += (double)right[frame] * right[frame];

            unsigned int absolute_frame = start + frame;
            double mono = 0.5 * ((double)left[frame] + right[frame]);
            if (absolute_frame < total_frames / 4) {
                first_quarter_energy += mono * mono;
            }
            if (absolute_frame >= total_frames * 3 / 4) {
                final_quarter_energy += mono * mono;
            }
        }
    }

    double quarter_frames = total_frames / 4.0;
    double first_quarter_rms = sqrt(first_quarter_energy / quarter_frames);
    double final_quarter_rms = sqrt(final_quarter_energy / quarter_frames);
    assert(isfinite(peak));
    assert(peak > 0.01f && peak < 0.98f);
    assert(first_quarter_rms > final_quarter_rms * 4.0);
    assert(left_energy > 0.0 && right_energy > 0.0);
    BellModalDSPDestroy(dsp);
}

static void test_second_impact_adds_energy_without_clearing_the_tail(void) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueImpact(dsp, impact(0.45f, -0.2f, 0.1f, 0.0f)));

    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    double energy_before = 0.0;
    double energy_after = 0.0;
    unsigned int frames_before = 0;
    unsigned int frames_after = 0;
    const unsigned int second_impact_frame = BLOCK_SIZE * 188;
    const unsigned int window = 2400;

    for (unsigned int start = 0; start < 48000; start += BLOCK_SIZE) {
        if (start == second_impact_frame) {
            assert(BellModalDSPEnqueueImpact(dsp, impact(0.75f, 0.3f, -0.2f, 0.0f)));
        }
        BellModalDSPRender(dsp, left, right, BLOCK_SIZE);
        for (unsigned int frame = 0; frame < BLOCK_SIZE; frame++) {
            unsigned int absolute_frame = start + frame;
            double mono = 0.5 * ((double)left[frame] + right[frame]);
            if (absolute_frame >= second_impact_frame - window &&
                absolute_frame < second_impact_frame) {
                energy_before += mono * mono;
                frames_before++;
            }
            if (absolute_frame >= second_impact_frame &&
                absolute_frame < second_impact_frame + window) {
                energy_after += mono * mono;
                frames_after++;
            }
        }
    }

    assert(frames_before == window);
    assert(frames_after == window);
    assert(energy_before > 0.0);
    assert(energy_after / frames_after > energy_before / frames_before * 1.5);
    BellModalDSPDestroy(dsp);
}

static void test_tangential_transient_fades_within_fifty_milliseconds(void) {
    BellModalMode quiet_mode = {680.0f, 0.20f, 0.000001f};
    BellModalDSP *dsp = BellModalDSPCreate(SAMPLE_RATE, 2, &quiet_mode, 1);
    assert(dsp != NULL);
    assert(BellModalDSPEnqueueImpact(
        dsp,
        impact_with_normal_speed(0.8f, 1.8f, 0.0f, 0.0f, 1.0f)
    ));

    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    double early_energy = 0.0;
    double late_energy = 0.0;
    unsigned int early_frames = 0;
    unsigned int late_frames = 0;

    for (unsigned int start = 0; start < 2400; start += BLOCK_SIZE) {
        unsigned int count = 2400 - start;
        if (count > BLOCK_SIZE) { count = BLOCK_SIZE; }
        BellModalDSPRender(dsp, left, right, count);
        for (unsigned int frame = 0; frame < count; frame++) {
            unsigned int absolute_frame = start + frame;
            double mono = 0.5 * ((double)left[frame] + right[frame]);
            if (absolute_frame < 480) {
                early_energy += mono * mono;
                early_frames++;
            }
            if (absolute_frame >= 1920) {
                late_energy += mono * mono;
                late_frames++;
            }
        }
    }

    double early_rms = sqrt(early_energy / early_frames);
    double late_rms = sqrt(late_energy / late_frames);
    assert(early_rms > 0.001);
    assert(early_rms > late_rms * 4.0);
    BellModalDSPDestroy(dsp);
}

static void test_weak_glancing_contact_does_not_create_audible_scrape(void) {
    BellModalMode quiet_mode = {680.0f, 0.20f, 0.000001f};
    BellModalDSP *dsp = BellModalDSPCreate(SAMPLE_RATE, 2, &quiet_mode, 1);
    assert(dsp != NULL);
    assert(BellModalDSPEnqueueImpact(
        dsp,
        impact_with_normal_speed(0.001f, 0.31f, 0.0f, 0.0f, 4.0f)
    ));

    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    double energy = 0.0;
    float peak = 0.0f;
    unsigned int rendered_frames = 0;

    while (rendered_frames < 480u) {
        unsigned int count = 480u - rendered_frames;
        if (count > BLOCK_SIZE) { count = BLOCK_SIZE; }
        BellModalDSPRender(dsp, left, right, count);
        for (unsigned int frame = 0; frame < count; frame++) {
            float mono = 0.5f * (left[frame] + right[frame]);
            float magnitude = fabsf(mono);
            if (magnitude > peak) { peak = magnitude; }
            energy += (double)mono * mono;
        }
        rendered_frames += count;
    }

    double rms = sqrt(energy / rendered_frames);
    assert(peak < 0.01f);
    assert(rms < 0.003);
    BellModalDSPDestroy(dsp);
}

int main(void) {
    test_queue_bounds_and_recovery();
    test_output_is_bounded_stereo_and_decays();
    test_second_impact_adds_energy_without_clearing_the_tail();
    test_tangential_transient_fades_within_fifty_milliseconds();
    test_weak_glancing_contact_does_not_create_audible_scrape();
    puts("BellModalDSPTests passed");
    return 0;
}
