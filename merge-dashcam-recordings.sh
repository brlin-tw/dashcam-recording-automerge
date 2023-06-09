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

source_file_is_the_last_source_file(){
    local source_file_index="${1}"; shift
    local source_files_quantity="${1}"; shift

    test "${source_file_index}" -eq "$((source_files_quantity - 1))"
}

determine_merged_file_filename(){
    local first_sequence_recording_filename="${1}"; shift
    local first_sequence_recording_timestamp="${1}"; shift
    local last_sequence_recording_timestamp="${1}"; shift

    local \
        merged_filename_raw \
        merged_filename
    # Inject last sequence recording timestamp
    merged_filename_raw="${first_sequence_recording_filename/${first_sequence_recording_timestamp}/${first_sequence_recording_timestamp}-${last_sequence_recording_timestamp}}"

    # Fix output file extension
    merged_filename="${merged_filename_raw%.*}.mkv"

    printf '%s' "${merged_filename}"
}

merge_source_files_to_destdir(){
    local merged_file="${1}"; shift
    local -a source_files_to_merge=("${@}"); set --

    printf \
        'Info: Merging recordings...\n'
    if test "${KEEP_SOURCE_FILES}" == true; then
        FFCAT_DROP_SRC_FILES=false
    else
        FFCAT_DROP_SRC_FILES=true
    fi
    export FFCAT_DROP_SRC_FILES

    if ! \
        ffmpeg-cat \
            "${source_files_to_merge[@]}" \
            >"${merged_file}"; then
        printf \
            'Error: Unable to merge the source files using ffmpeg-cat.\n' \
            1>&2
        return 1
    fi
}

determine_next_sequence_video_timestamp_matching_regex(){
    local timestamp_minute="${1}"; shift
    local timestamp_hour="${1}"; shift

    local \
        regex_minute='^[0-5][0-9]$' \
        regex_hour='^(2[0-3]|[01][0-9])$'
    if ! [[ "${timestamp_minute}" =~ ${regex_minute} ]]; then
        printf \
            '%s: Error: Invalid timestamp_minute "%s" specified, should be between 00~59.\n' \
            "${FUNCNAME[0]}" \
            "${timestamp_minute}" \
            1>&2
            return 1
    fi

    if ! [[ "${timestamp_hour}" =~ ${regex_hour} ]]; then
        printf \
            '%s: Error: Invalid timestamp_hour "%s" specified, should be between 00~23.\n' \
            "${FUNCNAME[0]}" \
            "${timestamp_hour}" \
            1>&2
            return 1
    fi

    # NOTE: Leading zeros will confuse Bash's arithmetic expansion as
    # numbers in different base
    local \
        timestamp_minute_without_leading_zeroes \
        timestamp_hour_without_leading_zeroes
    timestamp_minute_without_leading_zeroes="${timestamp_minute#0}"
    timestamp_hour_without_leading_zeroes="${timestamp_hour#0}"

    local \
        next_timestamp_minute_in_sequence_raw \
        next_timestamp_hour_in_sequence_raw
    next_timestamp_minute_in_sequence_raw="$(((timestamp_minute_without_leading_zeroes + RECORDING_SPLIT_MINUTES) % 60))"
    next_timestamp_hour_in_sequence_raw="$(((timestamp_hour_without_leading_zeroes + (timestamp_minute_without_leading_zeroes + RECORDING_SPLIT_MINUTES) / 60) % 24))"

    # Add padding leadging zeros for two digits when necessary
    if test "${#next_timestamp_minute_in_sequence_raw}" -eq 1; then
        next_timestamp_minute_in_sequence="0${next_timestamp_minute_in_sequence_raw}"
    else
        next_timestamp_minute_in_sequence="${next_timestamp_minute_in_sequence_raw}"
    fi

    if test "${#next_timestamp_hour_in_sequence_raw}" -eq 1; then
        next_timestamp_hour_in_sequence="0${next_timestamp_hour_in_sequence_raw}"
    else
        next_timestamp_hour_in_sequence="${next_timestamp_hour_in_sequence_raw}"
    fi

    # NOTE: It may be possible that the seconds will not be the same in
    # the next sequence of the recording, so we have to match them
    printf '^%s%s[0-5][0-9]$' \
        "${next_timestamp_hour_in_sequence}" \
        "${next_timestamp_minute_in_sequence}"
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

    if test "${DEBUG}" == true; then
        printf \
            'DEBUG: Source timestamp determined to be "%s".\n' \
            "${source_timestamp}" \
            1>&2
    fi

    # If the current processed file does not have the timestamp of the
    # next sequence file, all previous sequence's files has been found
    if test -n "${regex_next_timestamp_in_sequence}" \
            && ! [[ "${source_timestamp}" =~ ${regex_next_timestamp_in_sequence} ]]; then
        printf \
            'Info: Detected end of recording sequence(%s~%s).\n' \
            "${first_sequence_recording_timestamp}" \
            "${last_sequence_recording_timestamp}"

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
            if ! \
                merged_file_filename="$(
                    determine_merged_file_filename \
                        "${first_sequence_recording_filename}" \
                        "${first_sequence_recording_timestamp}" \
                        "${last_sequence_recording_timestamp}"
                )"; then
                printf \
                    "%s: Error: Unable to determine merged file's filename.\\n" \
                    "${FUNCNAME[0]}" \
                    1>&2
                exit 4
            fi

            merged_file="${DEST_DIR}/${merged_file_filename}"

            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would merge the following recording files to "%s":\n' \
                    "${merged_file}"
                for source_file_dryrun in "${source_files_to_merge[@]}"; do
                    printf '* %s\n' "${source_file_dryrun}"
                done
            else
                if ! \
                    merge_source_files_to_destdir \
                        "${merged_file}" \
                        "${source_files_to_merge[@]}"; then
                    printf \
                        'Error: Unable to merge the source files.\n' \
                        1>&2
                    exit 4
                fi
            fi
        fi

        # Current processed file is the first file of the current
        # sequence, resetting sequence settings so that it will be
        # processed by the following logic
        first_sequence_recording_filename=
        first_sequence_recording_timestamp=
        source_files_to_merge=()
    fi

    # If the current processed file is the last file in the source
    # files then it must be processed in the current iteration of the
    # loop
    if source_file_is_the_last_source_file \
        "${source_file_index}" \
        "${source_files_quantity}"; then
        printf \
            'Info: Detected last source file "%s".\n' \
            "${source_file}"

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
            if ! \
                merged_file_filename="$(
                    determine_merged_file_filename \
                        "${first_sequence_recording_filename}" \
                        "${first_sequence_recording_timestamp}" \
                        "${source_timestamp}"
                )"; then
                printf \
                    "%s: Error: Unable to determine merged file's filename.\\n" \
                    "${FUNCNAME[0]}" \
                    1>&2
                exit 6
            fi

            merged_file="${DEST_DIR}/${merged_file_filename}"

            if test "${DRY_RUN}" == true; then
                printf \
                    'Info: Would merge the following recording files to "%s":\n' \
                    "${merged_file}"
                for source_file_dryrun in "${source_files_to_merge[@]}"; do
                    printf '* %s\n' "${source_file_dryrun}"
                done
            else
                if ! \
                    merge_source_files_to_destdir \
                        "${merged_file}" \
                        "${source_files_to_merge[@]}"; then
                    printf \
                        'Error: Unable to merge the source files.\n' \
                        1>&2
                    exit 6
                fi
            fi
        fi

        # All files has been processed, breaking the loop
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

    if ! \
        regex_next_timestamp_in_sequence="$(
            determine_next_sequence_video_timestamp_matching_regex \
                "${timestamp_minute}" \
                "${timestamp_hour}"
        )"; then
        printf \
            'Error: Unable to determine the regular expression to match the next sequence video timestamp.\n' \
            1>&2
        exit 7
    fi

    if test "${DEBUG}" == true; then
        printf \
            'DEBUG: Next timestamp in sequence matching regular expression determined to be "%s".\n' \
            "${regex_next_timestamp_in_sequence}" \
            1>&2
    fi

    last_sequence_recording_timestamp="${source_timestamp}"

    source_file_index="$((source_file_index + 1))"
done

printf 'Info: Operation completed without errors.\n'
