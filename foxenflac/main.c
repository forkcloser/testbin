/* foxenflac <input.flac> <output.raw>: decode a FLAC stream with libfoxenflac
 * and write what `flac -d --force-raw-format --endian=little --sign=signed`
 * writes: interleaved, signed, little-endian samples at the stream's own depth
 * (8, 16 or 24 bits; libfoxenflac decodes no deeper, and 12 or 20 bits have no
 * whole-byte raw form). */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <foxen-flac.h>

static int fail(const char *what, const char *why) {
  fprintf(stderr, "foxenflac: %s: %s\n", what, why);
  return 1;
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr, "usage: foxenflac <input.flac> <output.raw>\n");
    return 1;
  }
  const char *input = argv[1];
  const char *output = argv[2];
  FILE *in = fopen(input, "rb");
  if (!in) return fail(input, "cannot open");
  FILE *out = fopen(output, "wb");
  if (!out) return fail(output, "cannot create");
  fx_flac_t *flac = FX_FLAC_ALLOC_DEFAULT();
  if (!flac) return fail(input, "cannot allocate the decoder");

  uint8_t buf[4096];
  uint32_t have = 0;
  int eof = 0;
  int32_t samples[4096];
  unsigned bits = 0;
  unsigned width = 0;
  long long channels = 0;
  long long declared = 0;
  unsigned long long written = 0;
  int stalls = 0;
  for (;;) {
    if (!eof && have < sizeof(buf)) {
      size_t n = fread(buf + have, 1, sizeof(buf) - have, in);
      if (n == 0) {
        if (ferror(in)) return fail(input, "read error");
        eof = 1;
      }
      have += (uint32_t)n;
    }
    uint32_t used = have;
    uint32_t count = sizeof(samples) / sizeof(samples[0]);
    fx_flac_state_t state = fx_flac_process(flac, buf, &used, samples, &count);
    if (state == FLAC_ERR) return fail(input, "not a stream libfoxenflac decodes");
    memmove(buf, buf + used, have - used);
    have -= used;

    if (state == FLAC_END_OF_METADATA && width == 0) {
      bits = (unsigned)fx_flac_get_streaminfo(flac, FLAC_KEY_SAMPLE_SIZE);
      switch (bits) {
      case 8: width = 1; break;
      case 16: width = 2; break;
      case 24: width = 3; break;
      default:
        fprintf(stderr, "foxenflac: %s: %u-bit samples, not 8, 16 or 24\n", input, bits);
        return 1;
      }
      channels = (long long)fx_flac_get_streaminfo(flac, FLAC_KEY_N_CHANNELS);
      declared = (long long)fx_flac_get_streaminfo(flac, FLAC_KEY_N_SAMPLES);
      fprintf(stderr, "foxenflac: %lld channels, %u bits, %lld Hz, %lld frames\n", channels,
              bits, (long long)fx_flac_get_streaminfo(flac, FLAC_KEY_SAMPLE_RATE), declared);
    }
    if (count > 0 && width == 0) return fail(input, "samples before the stream info");
    for (uint32_t i = 0; i < count; i++) {
      /* libfoxenflac left-justifies every depth in 32 bits. */
      int32_t s = samples[i] >> (32 - bits);
      uint8_t le[3] = {(uint8_t)s, (uint8_t)(s >> 8), (uint8_t)(s >> 16)};
      if (fwrite(le, 1, width, out) != width) return fail(output, "write error");
    }
    written += count;
    /* fx_flac_process returns at every state change, so a call that neither
     * reads nor writes is not yet a stall; a run of them is. At the end of the
     * input that run is the end of the stream; before it, with a full buffer,
     * the decoder is stuck. */
    stalls = (used == 0 && count == 0) ? stalls + 1 : 0;
    if (stalls >= 16) {
      if (eof) break;
      if (have == sizeof(buf)) return fail(input, "the decoder makes no progress");
    }
  }
  if (channels > 0 && declared > 0 && written != (unsigned long long)(declared * channels)) {
    fprintf(stderr, "foxenflac: %s: decoded %llu frames, the stream declares %lld\n", input,
            written / (unsigned long long)channels, declared);
    return 1;
  }
  if (fclose(out) != 0) return fail(output, "write error");
  fclose(in);
  free(flac);
  return 0;
}
