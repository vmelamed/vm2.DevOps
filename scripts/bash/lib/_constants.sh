# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================
# Terminal Color and Formatting Constants
#
# This script defines ANSI escape codes for terminal text formatting and colors.
# When stdout is connected to a terminal (tty), color codes are enabled.
# When stdout is redirected to a file or pipe, codes are set to empty strings.
#
# Available constants:
#   - Text formatting: BOLD, RESET
#   - Basic colors: RED, GREEN, YELLOW, BLUE
#   - Bold colors: BOLDRED, BOLDGREEN, BOLDYELLOW, BOLDBLUE
#   - NC (No Color) - alias for RESET
#===============================================================================

# Circular include guard
(( ${__VM2_LIB_CONSTANTS_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_CONSTANTS_SH_LOADED=1

declare -rx varNameRegex="^[A-Za-z_][A-Za-z0-9_]*$"
declare -rx nugetServersRegex="^(nuget|github|https?://[-a-zA-Z0-9._/]+)$";

if [[ -t 1 ]]; then
    declare -xr bold='\033[1m'
    declare -xr reset='\033[0m'

    declare -xr red='\033[0;31m'
    declare -xr green='\033[0;32m'
    declare -xr yellow='\033[1;33m'
    declare -xr blue='\033[0;34m'
    declare -xr bold_red='\033[1;31m'
    declare -xr bold_green='\033[1;32m'
    declare -xr bold_yellow='\033[1;33m'
    declare -xr bold_blue='\033[1;34m'
    declare -xr nc='\033[0m' # no color (reset)
else
    declare -xr bold=''
    declare -xr reset=''
    declare -xr red=''
    declare -xr green=''
    declare -xr yellow=''
    declare -xr blue=''
    declare -xr bold_red=''
    declare -xr bold_green=''
    declare -xr bold_yellow=''
    declare -xr bold_blue=''
    declare -xr nc='' # no color (reset)
fi

# characters
declare -xr secret_str='••••••'
declare -xr mask_ch='•'
declare -xr check_ch='✓'
declare -xr cross_ch='✗'
declare -xr question_ch='?'
declare -xr fail_ch='✗'
declare -xr error_ch='✗'
declare -xr warning_ch='⚠'
declare -xr info_ch='ℹ'
declare -xr done_ch='✔'
declare -xr equals_ch='='
declare -xr not_eq_ch='≠'
declare -xr left_arrow_ch='←'
declare -xr right_arrow_ch='→'
declare -xr up_arrow_ch='↑'
declare -xr down_arrow_ch='↓'
# emojis
declare -xr mask_em='🔒'
declare -xr key_em='🔑'
declare -xr check_em='✅'
declare -xr done_em='✔️'
declare -xr fail_em='❌'
declare -xr error_em='❌'
declare -xr warn_em='⚠️'
declare -xr info_em='ℹ️'
declare -xr question_em='❓'
declare -xr equals_em='🟰'
declare -xr not_eq_em='❔'
declare -xr ok_em='🆗'
declare -xr left_arrow_em='⬅️'
declare -xr right_arrow_em='➡️'
declare -xr up_arrow_em='⬆️'
declare -xr down_arrow_em='⬇️'
