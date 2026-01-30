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

if [[ -t 1 ]]; then
    declare -xr BOLD='\033[1m'
    declare -xr RESET='\033[0m'

    declare -xr RED='\033[0;31m'
    declare -xr GREEN='\033[0;32m'
    declare -xr YELLOW='\033[1;33m'
    declare -xr BLUE='\033[0;34m'
    declare -xr BOLDRED='\033[1;31m'
    declare -xr BOLDGREEN='\033[1;32m'
    declare -xr BOLDYELLOW='\033[1;33m'
    declare -xr BOLDBLUE='\033[1;34m'
    declare -xr NC='\033[0m' # No Color (reset)
else
    declare -xr BOLD=''
    declare -xr RESET=''
    declare -xr RED=''
    declare -xr GREEN=''
    declare -xr YELLOW=''
    declare -xr BLUE=''
    declare -xr BOLDRED=''
    declare -xr BOLDGREEN=''
    declare -xr BOLDYELLOW=''
    declare -xr BOLDBLUE=''
    declare -xr NC='' # No Color (reset)
fi
