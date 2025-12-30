import os
import random
import subprocess
from datetime import datetime
from pathlib import Path

fpath = Path(__file__).parent
dirpath = fpath / "jajal"


def list_files_by_extensions(extensions):
    return [
        f
        for f in os.listdir(dirpath)
        if any(f.lower().endswith(ext) for ext in extensions)
    ]


def main():
    print("========== VIDEO AUDIO MERGER (BATCH MODE) ==========")

    username = (
        input("Enter your name (for output filename): ").strip().replace(" ", "_")
    )
    if not username:
        print("Username is required.")
        return

    # Kumpulkan video & audio
    video_files = list_files_by_extensions([".mp4", ".mkv", ".avi", ".mov"])
    if not video_files:
        print("No video files found.")
        return

    print(f"Found {len(video_files)} video files:")
    for i, v in enumerate(video_files, 1):
        print(f"{i}. {v}")

    audio_files = list_files_by_extensions([".mp3", ".wav", ".ogg"])
    if not audio_files:
        print("No audio files found.")
        return

    print(f"Found {len(audio_files)} audio files.")
    try:
        max_audio = int(
            input(f"How many audio files to use? (1-{len(audio_files)}, default 25): ")
            or "25"
        )
    except ValueError:
        max_audio = 25
    max_audio = max(1, min(max_audio, len(audio_files)))

    proceed = (
        input(
            "Apakah ingin melanjutkan proses penggabungan hasil akhir berulang? (y/n): "
        )
        .strip()
        .lower()
    )
    if proceed == "y":
        try:
            repeat_times = int(
                input("Berapa kali ingin mengulang video hasil akhir? (default 4): ")
                or "4"
            )
        except ValueError:
            repeat_times = 4
        repeat_times = max(1, repeat_times)
    else:
        repeat_times = 1  # hanya merge dasar

    # === Proses setiap video, dengan urutan audio yang berbeda-beda ===
    for idx, video_file in enumerate(video_files, 1):
        print(f"\n===== Processing {idx}/{len(video_files)}: {video_file} =====")

        # 1) Pilih & acak audio spesifik untuk video ini
        selected_audios = random.sample(audio_files, max_audio)
        random.shuffle(selected_audios)  # urutan unik per video

        # 2) Tulis daftar audio untuk video ini
        audio_list_path = f"audio_list_{idx}.txt"
        with open(audio_list_path, "w", encoding="utf-8") as f:
            for afile in selected_audios:
                # aman untuk nama file yang mengandung tanda kutip
                # Handle both single quotes and backslashes for Windows compatibility
                safe = afile.replace("'", "'\\''").replace("\\", "/")
                # Use absolute path for reliable file access
                abs_safe = os.path.abspath(safe)
                f.write(f"file '{abs_safe}'\n")

        # 3) Gabungkan audio khusus video ini
        combined_audio = f"combined_audio_{idx}.mp3"
        print(
            f"Combining {len(selected_audios)} audio files (unique order for this video) → {combined_audio}"
        )
        subprocess.run([
            "ffmpeg",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            audio_list_path,
            "-c",
            "copy",
            combined_audio,
            "-y",
        ])

        if not os.path.exists(combined_audio):
            print("Failed to create combined audio for this video. Skipping...")
            # bersihkan file list
            if os.path.exists(audio_list_path):
                os.remove(audio_list_path)
            continue

        # 4) Merge video + audio unik
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_output = (
            f"{username}_{os.path.splitext(video_file)[0]}_merged_{timestamp}.mp4"
        )

        print(f"Merging '{video_file}' dengan '{combined_audio}' → {base_output} ...")
        subprocess.run([
            "ffmpeg",
            "-stream_loop",
            "-1",
            "-i",
            video_file,
            "-i",
            combined_audio,
            "-map",
            "0:v",
            "-map",
            "1:a",
            "-c:v",
            "copy",
            "-c:a",
            "copy",
            "-shortest",
            base_output,
            "-y",
        ])

        # 5) Opsi pengulangan hasil akhir
        if repeat_times > 1:
            concat_list = f"concat_list_{idx}.txt"
            with open(concat_list, "w", encoding="utf-8") as f:
                for _ in range(repeat_times):
                    # Sanitize output filename too
                    safe_output = sanitize_filename(base_output)
                    f.write(f"file '{safe_output}'\n")

            final_output = f"{sanitize_filename(username)}_{os.path.splitext(sanitize_filename(video_file))[0]}_merged_{timestamp}_x{repeat_times}.mp4"
            print(
                f"Menggabungkan {base_output} sebanyak {repeat_times} kali → {final_output} ..."
            )
            subprocess.run([
                "ffmpeg",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                concat_list,
                "-c",
                "copy",
                final_output,
                "-y",
            ])

            # Bersih-bersih
            if os.path.exists(concat_list):
                os.remove(concat_list)
                print(f"🗑️ Deleted temporary file: {concat_list}")
            if os.path.exists(base_output):
                os.remove(base_output)
                print(f"🗑️ Deleted base file: {base_output}")
        else:
            final_output = base_output

        print(f"✅ Selesai! File akhir untuk {video_file}: {final_output}")

        # 6) Bersihkan file sementara per-video
        for temp in [audio_list_path, combined_audio]:
            if os.path.exists(temp):
                os.remove(temp)
                print(f"🗑️ Deleted temporary file: {temp}")

    print("\n🎉 Semua video sudah selesai diproses!")


if __name__ == "__main__":
    main()
