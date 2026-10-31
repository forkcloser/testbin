// microflac <input.flac> <output.raw>: decode a FLAC stream with microFLAC and
// write what `flac -d --force-raw-format --endian=little --sign=signed`
// writes: interleaved, signed, little-endian samples at the stream's own depth
// (8, 16, 24 or 32 bits; another depth is refused). microFLAC's byte-packed
// output is that layout already, on every host.

#include <cstdint>
#include <cstdio>
#include <vector>

#include "micro_flac/flac_decoder.h"

namespace {

int fail(const char *what, const char *why) {
    std::fprintf(stderr, "microflac: %s: %s\n", what, why);
    return 1;
}

}  // namespace

int main(int argc, char **argv) {
    if (argc != 3) {
        std::fprintf(stderr, "usage: microflac <input.flac> <output.raw>\n");
        return 1;
    }
    const char *input = argv[1];
    const char *output = argv[2];

    std::FILE *in = std::fopen(input, "rb");
    if (in == nullptr) return fail(input, "cannot open");
    std::vector<uint8_t> data;
    uint8_t chunk[65536];
    for (;;) {
        const size_t n = std::fread(chunk, 1, sizeof(chunk), in);
        data.insert(data.end(), chunk, chunk + n);
        if (n < sizeof(chunk)) break;
    }
    if (std::ferror(in) != 0) return fail(input, "read error");
    std::fclose(in);

    std::FILE *out = std::fopen(output, "wb");
    if (out == nullptr) return fail(output, "cannot create");

    micro_flac::FLACDecoder decoder;
    std::vector<uint8_t> pcm;
    const uint8_t *cursor = data.data();
    size_t left = data.size();
    uint32_t width = 0;
    uint32_t channels = 0;
    uint64_t written = 0;
    int stalls = 0;
    for (;;) {
        size_t consumed = 0;
        size_t decoded = 0;
        const micro_flac::FLACDecoderResult result = decoder.decode(
            cursor, left, pcm.empty() ? nullptr : pcm.data(), pcm.size(), consumed, decoded);
        cursor += consumed;
        left -= consumed;
        if (result < 0) {
            std::fprintf(stderr, "microflac: %s: decoder error %d\n", input, static_cast<int>(result));
            return 1;
        }
        if (result == micro_flac::FLAC_DECODER_HEADER_READY) {
            const micro_flac::FLACStreamInfo &info = decoder.get_stream_info();
            const uint32_t bits = info.bits_per_sample();
            if (bits % 8 != 0) {
                std::fprintf(stderr, "microflac: %s: %u-bit samples, not 8, 16, 24 or 32\n", input,
                             bits);
                return 1;
            }
            width = bits / 8;
            channels = info.num_channels();
            pcm.resize(static_cast<size_t>(info.max_block_size()) * channels * width);
            std::fprintf(stderr, "microflac: %u channels, %u bits, %u Hz, %llu frames\n", channels,
                         bits, info.sample_rate(),
                         static_cast<unsigned long long>(info.total_samples_per_channel()));
        }
        if (decoded > 0) {
            if (std::fwrite(pcm.data(), width, decoded, out) != decoded) {
                return fail(output, "write error");
            }
            written += decoded;
        }
        if (result == micro_flac::FLAC_DECODER_END_OF_STREAM) break;
        if (result == micro_flac::FLAC_DECODER_NEED_MORE_DATA && left == 0) break;
        // A call that neither reads nor writes can be a state change; a run of
        // them with input left is a decoder that makes no progress.
        stalls = (consumed == 0 && decoded == 0) ? stalls + 1 : 0;
        if (stalls >= 16) return fail(input, "the decoder makes no progress");
    }
    if (std::fclose(out) != 0) return fail(output, "write error");

    const uint64_t declared = decoder.get_stream_info().total_samples_per_channel();
    if (channels > 0 && declared > 0 && written != declared * channels) {
        std::fprintf(stderr, "microflac: %s: decoded %llu frames, the stream declares %llu\n", input,
                     static_cast<unsigned long long>(written / channels),
                     static_cast<unsigned long long>(declared));
        return 1;
    }
    return 0;
}
