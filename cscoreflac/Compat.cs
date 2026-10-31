// Upstream files the decoder needs open namespaces it never uses:
// FlacMetadataFactory.cs `System.DirectoryServices` (a .NET Framework assembly
// .NET does not ship), AudioSubTypes.Utils.cs CSCore's Windows-only `DMO` and
// `MediaFoundation`. Empty namespaces satisfy the directives without editing
// upstream's files.
namespace System.DirectoryServices
{
}

namespace CSCore.DMO
{
}

namespace CSCore.MediaFoundation
{
}

// CSCore's ID3 support, which FlacFile reaches only to skip an ID3v2 tag in
// front of the stream, decodes picture frames into System.Drawing.Image, which
// .NET ships for Windows alone. The decoder never decodes a picture; this stub
// keeps those frames compiling and fails loudly if anything ever does.
namespace System.Drawing
{
    public abstract class Image
    {
        public static Image FromStream(System.IO.Stream stream) =>
            throw new NotSupportedException("cscoreflac decodes no pictures");
    }
}

// CSCore's Extensions.cs carries the helpers below among many that reach
// CSCore's Windows audio stack (SoundOut, MediaFoundation, DMO); the FLAC
// decoder calls only these two, so they are here instead, with upstream's
// behaviour (CSCore 1.2.1.2, Extensions.cs).
namespace CSCore
{
    using System;
    using System.IO;

    internal static class FlacExtensions
    {
        internal static byte[] ReadBytes(this IWaveSource waveSource, int count)
        {
            if (waveSource == null)
                throw new ArgumentNullException(nameof(waveSource));
            count -= count % waveSource.WaveFormat.BlockAlign;
            if (count <= 0)
                throw new ArgumentOutOfRangeException(nameof(count));

            byte[] buffer = new byte[count];
            int read = waveSource.Read(buffer, 0, buffer.Length);
            if (read < count)
                Array.Resize(ref buffer, read);
            return buffer;
        }

        internal static bool IsClosed(this Stream stream) => !stream.CanRead && !stream.CanWrite;
    }
}
