"""Verify decoded alarm gain, rather than trusting encoder metadata."""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
report = json.loads((root / "Media/gain-report.json").read_text())
hashes = set()
for record in report["files"]:
    path = root / record["path"]
    pcm = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path),
        "-f", "f32le", "-ac", "2", "-ar", "44100", "-",
    ])
    samples = array.array("f")
    samples.frombytes(pcm)
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    multiplier = rms / record["original_rms"]
    peak = max(abs(value) for value in samples)
    assert 1.48 <= multiplier <= 1.52, (record["path"], multiplier)
    assert peak < 1.0, (record["path"], "clipping/overshoot", peak)
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name", "-of", "json", str(path),
    ], text=True))
    assert info["streams"][0]["codec_name"] == "vorbis"
    assert 0 < float(info["format"]["duration"]) < 0.6
    hashes.add(hashlib.sha256(pcm).digest())
    print(f"PASS {record['path']}: {multiplier:.4f}x decoded RMS; peak={peak:.4f}")
assert len(hashes) == 4
print("PASS four distinct, short, 150%-RMS alarms without decoded clipping")
