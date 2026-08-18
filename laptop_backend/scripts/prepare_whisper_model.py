"""Download the selected faster-whisper model once for later offline use."""

from __future__ import annotations

import argparse

from huggingface_hub import snapshot_download


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Cache a faster-whisper model for offline assistant transcription."
    )
    parser.add_argument(
        "--model",
        choices=("tiny", "base", "small"),
        default="base",
        help="Model size to cache. Default: base.",
    )
    args = parser.parse_args()
    snapshot_download(repo_id=f"Systran/faster-whisper-{args.model}")
    print(f"Whisper model '{args.model}' is cached and ready for offline use.")


if __name__ == "__main__":
    main()
