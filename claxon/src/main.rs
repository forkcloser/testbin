//! `claxon <input.flac> <output.raw>`: decode a FLAC stream with Claxon and
//! write what `flac -d --force-raw-format --endian=little --sign=signed`
//! writes: interleaved, signed, little-endian samples at the stream's own
//! depth (8, 16, 24 or 32 bits; another depth is refused).

use std::env;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::process::ExitCode;

fn run(input: &str, output: &str) -> Result<(), String> {
    let mut reader = claxon::FlacReader::open(input).map_err(|e| format!("{input}: {e}"))?;
    let info = reader.streaminfo();
    let width = match info.bits_per_sample {
        8 => 1,
        16 => 2,
        24 => 3,
        32 => 4,
        bits => return Err(format!("{input}: {bits}-bit samples, not 8, 16, 24 or 32")),
    };
    let frames = info
        .samples
        .map_or_else(|| "an unknown number of".to_owned(), |n| n.to_string());
    eprintln!(
        "claxon: {} channels, {} bits, {} Hz, {frames} frames",
        info.channels, info.bits_per_sample, info.sample_rate
    );

    let mut out = BufWriter::new(File::create(output).map_err(|e| format!("{output}: {e}"))?);
    for sample in reader.samples() {
        let sample = sample.map_err(|e| format!("{input}: {e}"))?;
        // The low bytes of the two's complement are the sample at its depth.
        out.write_all(&sample.to_le_bytes()[..width])
            .map_err(|e| format!("{output}: {e}"))?;
    }
    out.flush().map_err(|e| format!("{output}: {e}"))
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    let [_, input, output] = args.as_slice() else {
        eprintln!("usage: claxon <input.flac> <output.raw>");
        return ExitCode::FAILURE;
    };
    match run(input, output) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("claxon: {e}");
            ExitCode::FAILURE
        }
    }
}
