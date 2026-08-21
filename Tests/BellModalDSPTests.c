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

static const BellDSPContactProfile kContactProfile = {
    .load_reference = 9.80665f,
    .speed_reference = 0.55f,
    .surface_samples_per_meter = 1400.0f,
    .excitation_gain = 0.00009f,
    .attack_seconds = 0.008f,
    .release_seconds = 0.040f,
    .timeout_seconds = 0.080f,
    .first_excited_mode_index = 4u,
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

static BellDSPContact contact(
    bool is_touching,
    float load,
    float speed,
    float contact_x,
    float contact_z
) {
    BellDSPContact value = {
        .timestamp = 1.0,
        .is_touching_wall = is_touching,
        .normal_acceleration = load,
        .contact_x = contact_x,
        .contact_y = -0.9f,
        .contact_z = contact_z,
        .tangential_speed = speed,
    };
    return value;
}

static BellModalDSP *make_dsp(void) {
    BellModalDSP *dsp = BellModalDSPCreate(
        SAMPLE_RATE,
        2,
        kModes,
        (unsigned int)(sizeof(kModes) / sizeof(kModes[0])),
        &kContactProfile
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

static double render_energy(BellModalDSP *dsp, unsigned int total_frames, float *peak) {
    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    double energy = 0.0;
    *peak = 0.0f;
    for (unsigned int start = 0; start < total_frames; start += BLOCK_SIZE) {
        unsigned int count = total_frames - start;
        if (count > BLOCK_SIZE) { count = BLOCK_SIZE; }
        BellModalDSPRender(dsp, left, right, count);
        for (unsigned int frame = 0; frame < count; frame++) {
            float mono = 0.5f * (left[frame] + right[frame]);
            float magnitude = fabsf(mono);
            if (magnitude > *peak) { *peak = magnitude; }
            energy += (double)mono * mono;
        }
    }
    return energy;
}

static void test_detached_zero_load_and_zero_speed_create_no_contact_energy(void) {
    BellDSPContact silent_contacts[] = {
        contact(false, 9.80665f, 0.45f, 0.0f, 0.0f),
        contact(true, 0.0f, 0.45f, 0.0f, 0.0f),
        contact(true, 9.80665f, 0.0f, 0.0f, 0.0f),
    };
    for (unsigned int index = 0; index < 3u; index++) {
        BellModalDSP *dsp = make_dsp();
        assert(BellModalDSPEnqueueContact(dsp, silent_contacts[index]));
        float peak = 0.0f;
        double energy = render_energy(dsp, 4800u, &peak);
        assert(energy == 0.0);
        assert(peak == 0.0f);
        BellModalDSPDestroy(dsp);
    }
}

static void test_zero_gain_modes_produce_no_dry_contact_noise(void) {
    BellModalMode silent_modes[] = {
        {1700.0f, 0.08f, 0.0f},
        {3100.0f, 0.06f, 0.0f},
    };
    BellDSPContactProfile profile = kContactProfile;
    profile.first_excited_mode_index = 0u;
    BellModalDSP *dsp = BellModalDSPCreate(SAMPLE_RATE, 2, silent_modes, 2u, &profile);
    assert(dsp != NULL);
    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(true, 9.80665f, 0.80f, 0.3f, -0.2f)
    ));

    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    for (unsigned int start = 0; start < 4800u; start += BLOCK_SIZE) {
        unsigned int count = 4800u - start;
        if (count > BLOCK_SIZE) { count = BLOCK_SIZE; }
        BellModalDSPRender(dsp, left, right, count);
        for (unsigned int frame = 0; frame < count; frame++) {
            assert(left[frame] == 0.0f);
            assert(right[frame] == 0.0f);
        }
    }
    BellModalDSPDestroy(dsp);
}

static double contact_difference_energy(float speed, float *peak) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(true, 9.80665f, speed, 0.15f, -0.1f)
    ));
    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    float previous = 0.0f;
    double difference_energy = 0.0;
    *peak = 0.0f;
    for (unsigned int start = 0; start < 48000u; start += BLOCK_SIZE) {
        BellModalDSPRender(dsp, left, right, BLOCK_SIZE);
        for (unsigned int frame = 0; frame < BLOCK_SIZE; frame++) {
            float mono = 0.5f * (left[frame] + right[frame]);
            float difference = mono - previous;
            difference_energy += (double)difference * difference;
            previous = mono;
            float magnitude = fabsf(mono);
            if (magnitude > *peak) { *peak = magnitude; }
        }
    }
    BellModalDSPDestroy(dsp);
    return difference_energy;
}

static void test_fast_slide_is_brighter_and_denser_than_slow_slide(void) {
    float slow_peak = 0.0f;
    float fast_peak = 0.0f;
    double slow_difference_energy = contact_difference_energy(0.08f, &slow_peak);
    double fast_difference_energy = contact_difference_energy(0.80f, &fast_peak);
    assert(slow_difference_energy > 0.0);
    assert(fast_difference_energy > slow_difference_energy * 1.20);
    assert(slow_peak < 0.98f);
    assert(fast_peak < 0.98f);
}

static void test_contact_packet_updates_do_not_click(void) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(true, 4.0f, 0.10f, -0.5f, 0.1f)
    ));
    float left[BLOCK_SIZE];
    float right[BLOCK_SIZE];
    BellModalDSPRender(dsp, left, right, BLOCK_SIZE);
    float previous = 0.5f * (left[BLOCK_SIZE - 1] + right[BLOCK_SIZE - 1]);

    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(true, 15.0f, 1.10f, 0.5f, -0.1f)
    ));
    BellModalDSPRender(dsp, left, right, BLOCK_SIZE);
    float first = 0.5f * (left[0] + right[0]);
    assert(fabsf(first - previous) < 0.12f);
    BellModalDSPDestroy(dsp);
}

static void test_stale_contact_releases_after_eighty_milliseconds(void) {
    BellModalMode short_modes[] = {
        {2104.0f, 0.020f, 0.14f},
        {3408.0f, 0.018f, 0.09f},
        {5119.0f, 0.016f, 0.055f},
    };
    BellDSPContactProfile profile = kContactProfile;
    profile.first_excited_mode_index = 0u;
    BellModalDSP *dsp = BellModalDSPCreate(SAMPLE_RATE, 2, short_modes, 3u, &profile);
    assert(dsp != NULL);
    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(true, 9.80665f, 0.50f, 0.0f, 0.0f)
    ));

    float early_peak = 0.0f;
    double early_energy = render_energy(dsp, 3840u, &early_peak);
    float late_peak = 0.0f;
    double late_energy = render_energy(dsp, 5760u, &late_peak);
    assert(early_energy > 0.0);
    assert(late_energy < early_energy * 0.25);
    assert(late_peak < early_peak);
    BellModalDSPDestroy(dsp);
}

static void test_contact_updates_do_not_clear_impact_tail(void) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueImpact(dsp, impact(0.72f, 0.1f, 0.2f, 0.0f)));
    float first_peak = 0.0f;
    double first_energy = render_energy(dsp, 512u, &first_peak);
    assert(BellModalDSPEnqueueContact(
        dsp,
        contact(false, 0.0f, 0.0f, 0.0f, 0.0f)
    ));
    float tail_peak = 0.0f;
    double tail_energy = render_energy(dsp, 512u, &tail_peak);
    assert(first_energy > 0.0);
    assert(tail_energy > 0.0);
    assert(tail_peak > 0.0f);
    BellModalDSPDestroy(dsp);
}

static void test_tangential_impact_excites_modes_without_dry_noise(void) {
    BellModalDSP *dsp = make_dsp();
    assert(BellModalDSPEnqueueImpact(
        dsp,
        impact_with_normal_speed(0.8f, 1.8f, 0.0f, 0.0f, 1.0f)
    ));
    float peak = 0.0f;
    double energy = render_energy(dsp, 2400u, &peak);
    assert(energy > 0.0);
    assert(peak > 0.001f && peak < 0.98f);
    BellModalDSPDestroy(dsp);
}

int main(void) {
    test_queue_bounds_and_recovery();
    test_output_is_bounded_stereo_and_decays();
    test_second_impact_adds_energy_without_clearing_the_tail();
    test_detached_zero_load_and_zero_speed_create_no_contact_energy();
    test_zero_gain_modes_produce_no_dry_contact_noise();
    test_fast_slide_is_brighter_and_denser_than_slow_slide();
    test_contact_packet_updates_do_not_click();
    test_stale_contact_releases_after_eighty_milliseconds();
    test_contact_updates_do_not_clear_impact_tail();
    test_tangential_impact_excites_modes_without_dry_noise();
    puts("BellModalDSPTests passed");
    return 0;
}
