//! `symphonia <input.flac> <output.raw>`: decode a FLAC stream with
//! Symphonia and write what `flac -d --force-raw-format --endian=little
//! --sign=signed` writes: interleaved, signed, little-endian samples at the
//! stream's own depth (8, 16, 24 or 32 bits; another depth is refused).

use std::env;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::process::ExitCode;

use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;

fn run(input: &str, output: &str) -> Result<(), String> {
    let file = File::open(input).map_err(|e| format!("{input}: {e}"))?;
    let source = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    hint.with_extension("flac");
    let mut format = symphonia::default::get_probe()
        .probe(
            &hint,
            source,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|e| format!("{input}: {e}"))?;

    let track = format
        .default_track(TrackType::Audio)
        .ok_or_else(|| format!("{input}: no audio track"))?;
    let track_id = track.id;
    let frames = track
        .num_frames
        .map_or_else(|| "an unknown number of".to_owned(), |n| n.to_string());
    let params = track
        .codec_params
        .as_ref()
        .and_then(|p| p.audio())
        .ok_or_else(|| format!("{input}: no audio parameters"))?
        .clone();
    let bits = params
        .bits_per_sample
        .ok_or_else(|| format!("{input}: no bit depth"))?;
    let width = match bits {
        8 => 1,
        16 => 2,
        24 => 3,
        32 => 4,
        _ => return Err(format!("{input}: {bits}-bit samples, not 8, 16, 24 or 32")),
    };
    eprintln!(
        "symphonia: {} channels, {bits} bits, {} Hz, {frames} frames",
        params.channels.as_ref().map_or(0, |c| c.count()),
        params.sample_rate.unwrap_or(0)
    );

    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(&params, &AudioDecoderOptions::default())
        .map_err(|e| format!("{input}: {e}"))?;
    let mut out = BufWriter::new(File::create(output).map_err(|e| format!("{output}: {e}"))?);
    let mut samples: Vec<i32> = Vec::new();
    while let Some(packet) = format.next_packet().map_err(|e| format!("{input}: {e}"))? {
        if packet.track_id != track_id {
            continue;
        }
        let decoded = decoder
            .decode(&packet)
            .map_err(|e| format!("{input}: {e}"))?;
        samples.resize(decoded.samples_interleaved(), 0);
        decoded.copy_to_slice_interleaved(&mut samples);
        for sample in &samples {
            // The FLAC decoder left-justifies every depth in 32 bits.
            let sample = sample >> (32 - bits);
            out.write_all(&sample.to_le_bytes()[..width])
                .map_err(|e| format!("{output}: {e}"))?;
        }
    }
    out.flush().map_err(|e| format!("{output}: {e}"))
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    let [_, input, output] = args.as_slice() else {
        eprintln!("usage: symphonia <input.flac> <output.raw>");
        return ExitCode::FAILURE;
    };
    match run(input, output) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("symphonia: {e}");
            ExitCode::FAILURE
        }
    }
}
