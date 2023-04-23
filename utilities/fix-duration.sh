#!/usr/bin/env bash
# Fix duration for merged MKV files
#
# Copyright 2023 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

input_files=("${@}")

if ! command -v ffprobe >/dev/null; then
    printf 'Error: This program requires the ffprobe command to be available in your comamnd search PATHs.\n' 1>&2
    exit 1
fi

if test "${#input_files[@]}" -eq 0; then
    printf \
        'Error: No input files are specified.\n' \
        1>&2
    exit 1
fi

for input_file in "${input_files[@]}"; do
    if ffprobe \
            "${input_file}" \
            2>&1 \
            | grep \
                -qF \
                'Duration: N/A'; then
        printf \
            'Fixing "%s"...\n' \
            "${input_file}"
        input_file="$(realpath "${input_file}")"
        input_file_filename="${input_file##*/}"
        input_file_name="${input_file_filename%.*}"
        input_file_filename_extension="${input_file_filename##*.}"
        input_file_dir="${input_file%/*}"
        if test -z "${input_file_dir}"; then
            input_file_dir="${PWD}"
        fi

        fixed_file="${input_file_dir}/${input_file_name}.fixed.${input_file_filename_extension}"
        ffmpeg_opts=(
            -hide_banner

            -i "${input_file}"

            -map_metadata 0
            -map 0
            -ignore_unknown

            -c copy
            -y
        )
        if ! \
            ffmpeg \
                "${ffmpeg_opts[@]}" \
                "${fixed_file}"; then
            printf \
                'Error: Unable to fix duration for file "%s".\n' \
                "${input_file}" \
                1>&2
            exit 2
        fi

        if ! \
            mv \
                --force \
                --verbose \
                "${fixed_file}" \
                "${input_file}"; then
            printf \
                'Error: Unable to overwrite the input file.\n' \
                1>&2
            exit 3
        fi
    fi
done

printf 'Operation completed without errors.\n'
