/* drflac: decode a FLAC file with dr_flac (mackron/dr_libs) into raw PCM.
 *
 *   drflac <input.flac> <output.raw>
 *
 * The output is what `flac -d --force-raw-format --endian=little
 * --sign=signed` writes: interleaved, signed, little-endian samples at the
 * stream's own bit depth, which must be a whole number of bytes (8, 16, 24 or
 * 32). The stream's parameters go to stderr, nothing to stdout. Exit status 0
 * on success, 1 on any error. */

#define DR_FLAC_IMPLEMENTATION
#include "dr_flac.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define FRAMES_PER_READ 4096

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: drflac <input.flac> <output.raw>\n");
        return 1;
    }

    drflac *flac = drflac_open_file(argv[1], NULL);
    if (flac == NULL) {
        fprintf(stderr, "drflac: %s: not a FLAC stream dr_flac can open\n", argv[1]);
        return 1;
    }

    const unsigned channels = flac->channels;
    const unsigned bps = flac->bitsPerSample;
    if (bps == 0 || bps % 8 != 0 || bps > 32) {
        fprintf(stderr, "drflac: %s: %u bits per sample is not a whole number of bytes\n", argv[1], bps);
        drflac_close(flac);
        return 1;
    }
    const unsigned bytes = bps / 8;
    fprintf(stderr, "drflac: %u channels, %u bits, %u Hz, %llu frames\n", channels, bps,
            flac->sampleRate, (unsigned long long)flac->totalPCMFrameCount);

    FILE *out = fopen(argv[2], "wb");
    if (out == NULL) {
        fprintf(stderr, "drflac: %s: cannot open for writing\n", argv[2]);
        drflac_close(flac);
        return 1;
    }

    int32_t *samples = malloc((size_t)FRAMES_PER_READ * channels * sizeof(int32_t));
    uint8_t *raw = malloc((size_t)FRAMES_PER_READ * channels * bytes);
    if (samples == NULL || raw == NULL) {
        fprintf(stderr, "drflac: out of memory\n");
        free(samples);
        free(raw);
        fclose(out);
        drflac_close(flac);
        return 1;
    }

    int status = 0;
    drflac_uint64 total = 0;
    for (;;) {
        /* dr_flac returns every sample left-justified in 32 bits whatever the
         * stream's depth; shifting back gives the stream's own value. */
        const drflac_uint64 frames = drflac_read_pcm_frames_s32(flac, FRAMES_PER_READ, samples);
        if (frames == 0) {
            break;
        }
        const size_t count = (size_t)frames * channels;
        for (size_t i = 0; i < count; i++) {
            const uint32_t value = (uint32_t)(samples[i] >> (32 - bps));
            for (unsigned b = 0; b < bytes; b++) {
                raw[i * bytes + b] = (uint8_t)(value >> (8 * b));
            }
        }
        if (fwrite(raw, bytes, count, out) != count) {
            fprintf(stderr, "drflac: %s: write failed\n", argv[2]);
            status = 1;
            break;
        }
        total += frames;
    }

    if (status == 0 && total != flac->totalPCMFrameCount && flac->totalPCMFrameCount != 0) {
        fprintf(stderr, "drflac: decoded %llu frames, the stream declares %llu\n",
                (unsigned long long)total, (unsigned long long)flac->totalPCMFrameCount);
        status = 1;
    }
    if (fclose(out) != 0 && status == 0) {
        fprintf(stderr, "drflac: %s: write failed\n", argv[2]);
        status = 1;
    }
    free(samples);
    free(raw);
    drflac_close(flac);
    return status;
}
