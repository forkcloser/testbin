// cscoreflac <input.flac> <output.raw>: decode a FLAC stream with CSCore's FLAC
// decoder and write what `flac -d --force-raw-format --endian=little
// --sign=signed` writes: interleaved, signed, little-endian samples at the
// stream's own depth (8, 16, 24 or 32 bits; another depth is refused), which is
// the PCM FlacFile.Read returns.

using System;
using System.IO;
using System.Linq;
using CSCore.Codecs.FLAC;
using CSCore.Codecs.FLAC.Metadata;

public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length != 2)
        {
            Console.Error.WriteLine("usage: cscoreflac <input.flac> <output.raw>");
            return 1;
        }
        string input = args[0];
        string output = args[1];
        try
        {
            using var flac = new FlacFile(File.OpenRead(input));
            var format = flac.WaveFormat;
            if (format.BitsPerSample % 8 != 0)
            {
                Console.Error.WriteLine(
                    $"cscoreflac: {input}: {format.BitsPerSample}-bit samples, not 8, 16, 24 or 32");
                return 1;
            }
            // STREAMINFO's count, not FlacFile.Length: that one is CSCore's own
            // prescan of the frames it could read, so it shrinks with them.
            long declared = flac.Metadata.OfType<FlacMetadataStreamInfo>()
                .Select(info => info.TotalSamples).FirstOrDefault();
            Console.Error.WriteLine(
                $"cscoreflac: {format.Channels} channels, {format.BitsPerSample} bits, " +
                $"{format.SampleRate} Hz, {declared} frames");

            long written = 0;
            using (var raw = File.Create(output))
            {
                var buffer = new byte[format.BlockAlign * 4096];
                int read;
                while ((read = flac.Read(buffer, 0, buffer.Length)) > 0)
                {
                    raw.Write(buffer, 0, read);
                    written += read;
                }
            }
            // FlacFile skips a frame it cannot decode and goes on, and yields
            // nothing at all for a depth it does not support: a short output is
            // the only trace either leaves.
            if (declared > 0 && written != declared * format.BlockAlign)
            {
                Console.Error.WriteLine(
                    $"cscoreflac: {input}: decoded {written / format.BlockAlign} frames, " +
                    $"the stream declares {declared}");
                return 1;
            }
            return 0;
        }
        catch (Exception e) when (e is IOException || e is FlacException ||
                                  e is UnauthorizedAccessException)
        {
            Console.Error.WriteLine($"cscoreflac: {input}: {e.Message}");
            return 1;
        }
    }
}
