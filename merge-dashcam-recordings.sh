#!/usr/bin/env bash
# Merge dashcam recordings that are named in a specific fashion
#
# Copyright 2023 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

SOURCE_DIR="${SOURCE_DIR:-}"
DEST_DIR="${DEST_DIR:-}"
RECORDING_SPLIT_MINUTES="${RECORDING_SPLIT_MINUTES:-5}"
DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"
KEEP_SOURCE_FILES="${KEEP_SOURCE_FILES:-false}"

set \
    -o errexit \
    -o errtrace \
    -o nounset

source_file_is_the_last_source_files(){
    local source_file_index="${1}"; shift
    local source_files_quantity="${1}"; shift

    test "${source_file_index}" -eq "$((source_files_quantity - 1))"
}

merge_source_files_to_destdir(){
    local first_sequence_recording_filename="${1}"; shift
    local first_sequence_recording_timestamp="${1}"; shift
    local last_sequence_recording_timestamp="${1}"; shift
    local dest_dir="${1}"; shift
    local -a source_files_to_merge=("${@}"); set --

    printf \
        'Info: Merging recordings...\n'
    if test "${KEEP_SOURCE_FILES}" == true; then
        FFCAT_DROP_SRC_FILES=false
    else
        FFCAT_DROP_SRC_FILES=true
    fi
    export FFCAT_DROP_SRC_FILES

    local merged_filename="${first_sequence_recording_filename/${first_sequence_recording_timestamp}/${first_sequence_recording_timestamp}-${last_sequence_recording_timestamp}}"

    if ! \
        ffmpeg-cat \
            "${source_files_to_merge[@]}" \
            >"${dest_dir}/${merged_filename}"; then
        printf \
            'Error: Unable to merge the source files using ffmpeg-cat.\n' \
            1>&2
        return 1
    fi
}

required_commands=(
    ffmpeg-cat
    grep
    realpath
    tail
)
flag_dependency_check_failed=false
for required_command in "${required_commands[@]}"; do
    if ! command -v "${required_command}" >/dev/null; then
        flag_dependency_check_failed=true
        printf \
            'Error: Unable to locate the "%s" command in the command search PATHs.\n' \
            "${required_command}" \
            1>&2
    fi
done
if test "${flag_dependency_check_failed}" == true; then
    printf \
        'Error: Dependency check failed, please check your installation.\n' \
        1>&2
fi

if test -v BASH_SOURCE; then
    # Convenience variables
    # shellcheck disable=SC2034
    {
        script="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
        )"
        script_dir="${script%/*}"
        script_filename="${script##*/}"
        script_name="${script_filename%%.*}"
    }
fi

if ! test -d "${SOURCE_DIR}"; then
    printf \
        'Error: SOURCE_DIR is not a valid directory.\n' \
        1>&2
    exit 1
fi

if ! test -d "${DEST_DIR}"; then
    printf \
        'Error: DEST_DIR is not a valid directory.\n' \
        1>&2
    exit 1
fi

regex_natural_number='^[1-9][0-9]*$'
if ! [[ "${RECORDING_SPLIT_MINUTES}" =~ ${regex_natural_number} ]] \
    || test "${RECORDING_SPLIT_MINUTES}" -ge 60; then
    printf \
        'Error: The RECORDING_SPLIT_MINUTES environment variable should only be 0~59.\n' \
        1>&2
    exit 1
fi

shopt -s globstar nocaseglob nullglob

source_files=(
    "${SOURCE_DIR}/"**/*.mp4
    "${SOURCE_DIR}/"**/*.mov
)
source_files_quantity="${#source_files[@]}"

if test "${#source_files[@]}" -eq 0; then
    printf \
        'Error: No qualified source files detected in the SOURCE_DIR.\n' \
        1>&2
    exit 2
fi

# We need proper collation
LC_COLLATE=POSIX

# HHMMSS, shouldn't have digit afterwards
regex_timestamp='(2[0-3]|[01][0-9])([0-5][0-9]){2}'

first_sequence_recording_timestamp=
last_sequence_recording_timestamp=
first_sequence_recording_filename=
regex_next_timestamp_in_sequence=
source_files_to_merge=()

source_file_index=0
for source_file in "${source_files[@]}"; do
    printf \
        'Info: Checking source file "%s"...\n' \
        "${source_file}"

    source_filename="${source_file##*/}"
    source_name="${source_filename%.*}"

    if ! [[ "${source_name}" =~ ${regex_timestamp} ]]; then
        printf \
            "Warning: The source file \"%s\" doesn't seem to be a valid source file, skipping...\n" \
            "${source_file}" \
            1>&2
        continue
    fi

    if ! source_timestamp="$(
        grep \
            --extended-regexp \
            --only-matching \
            "${regex_timestamp}" \
            <<< "${source_name}" \
            | tail \
                --lines=1
        )"; then
        printf \
            'Warning: Unable to determine the timestamp from the source file "%s", skipping...\n' \
            "${source_file}" \
            1>&2
        continue
    fi

    timestamp_hour="${source_timestamp:0:2}"
    timestamp_minute="${source_timestamp:2:2}"
    timestamp_second="${source_timestamp:4:2}"

    if test "${timestamp_hour}" -ge 24 \
        || test "${timestamp_minute}" -ge 60 \
        || test "${timestamp_second}" -ge 60; then
        printf \
            'Warning: Invalid timestamp "%s" detected from the source file "%s", skipping...\n' \
            "${source_timestamp}" \
            "${source_file}" \
            1>&2
        continue
    fi

    if test -n "${regex_next_timestamp_in_sequence}" \
            && ! [[ "${source_timestamp}" =~ ${regex_next_timestamp_in_sequence} ]]; then
        printf \
            'Info: Detected end of recording sequence.\n'

        if test "${#source_files_to_merge[@]}" -eq 1; then
            printf \
                'Info: Recording sequence has only one file, moving to DESTDIR...\n'
            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would move "%s" recording file to the DESTDIR.\n' \
                    "${source_files_to_merge[0]}"
            else
                if ! \
                    mv \
                        --verbose \
                        "${source_files_to_merge[0]}" \
                        "${DEST_DIR}"; then
                    printf \
                        'Error: Unable to move "%s" recording file to the DESTDIR.\n' \
                        "${source_files_to_merge[0]}" \
                        1>&2
                    exit 3
                fi
            fi
        else
            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would merge the following recording files and output to the DESTDIR:\n'
                for source_file_dryrun in "${source_files_to_merge[@]}"; do
                    printf '* %s\n' "${source_file_dryrun}"
                done
            else
                if ! \
                    merge_source_files_to_destdir \
                        "${first_sequence_recording_filename}" \
                        "${first_sequence_recording_timestamp}" \
                        "${last_sequence_recording_timestamp}" \
                        "${DEST_DIR}" \
                        "${source_files_to_merge[@]}"; then
                    printf \
                        'Error: Unable to merge the source files.\n' \
                        1>&2
                    exit 4
                fi
            fi
        fi
        first_sequence_recording_filename=
        first_sequence_recording_timestamp=
        source_files_to_merge=()
    fi

    if source_file_is_the_last_source_files \
        "${source_file_index}" \
        "${source_files_quantity}"; then
        if test "${#source_files_to_merge[@]}" -eq 0; then
            printf \
                'Info: Recording sequence has only one file, moving to DESTDIR...\n'
            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would move "%s" recording file to the DESTDIR.\n' \
                    "${source_file}"
            else
                if ! \
                    mv \
                        --verbose \
                        "${source_file}" \
                        "${DEST_DIR}"; then
                    printf \
                        'Error: Unable to move "%s" recording file to the DESTDIR.\n' \
                        "${source_file}" \
                        1>&2
                    exit 5
                fi
            fi
        else
            source_files_to_merge+=("${source_file}")
            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would merge the following recording files and output to the DESTDIR:\n'
                for source_file_dryrun in "${source_files_to_merge[@]}"; do
                    printf '* %s\n' "${source_file_dryrun}"
                done
            else
                if ! \
                    merge_source_files_to_destdir \
                        "${first_sequence_recording_filename}" \
                        "${first_sequence_recording_timestamp}" \
                        "${source_timestamp}" \
                        "${DEST_DIR}" \
                        "${source_files_to_merge[@]}"; then
                    printf \
                        'Error: Unable to merge the source files.\n' \
                        1>&2
                    exit 6
                fi
            fi
        fi
        break
    fi

    if test -z "${first_sequence_recording_timestamp}"; then
        first_sequence_recording_timestamp="${source_timestamp}"
        first_sequence_recording_filename="${source_filename}"
        printf \
            'Info: First sequence recording timestamp determined to be "%s".\n' \
            "${source_timestamp}"
    fi

    source_files_to_merge+=("${source_file}")

    # NOTE: Leading zeros will confuse Bash's arithmetic expansion as
    # numbers in different base
    timestamp_minute_without_leading_zeroes="${timestamp_minute#0}"
    timestamp_hour_without_leading_zeroes="${timestamp_hour#0}"

    next_timestamp_minute_in_sequence="$(((timestamp_minute_without_leading_zeroes + RECORDING_SPLIT_MINUTES) % 60))"
    next_timestamp_hour_in_sequence="$((timestamp_hour_without_leading_zeroes + (timestamp_minute_without_leading_zeroes + RECORDING_SPLIT_MINUTES) / 60))"

    # NOTE: It may be possible that the seconds will not be the same in
    # the next sequence of the recording, so we have to match them
    regex_next_timestamp_in_sequence="^${next_timestamp_hour_in_sequence}${next_timestamp_minute_in_sequence}[0-5][0-9]$"

    last_sequence_recording_timestamp="${source_timestamp}"

    source_file_index="$((source_file_index + 1))"
done
