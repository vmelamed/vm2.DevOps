#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/..")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/core.sh"

# shellcheck disable=SC2034 # variable appears unused
{
    declare foo="foo"
    declare bar="bar"
    declare fish="salmon"
    declare animal="dog"
    declare -a ultimate_question=("life" "universe" "everything")
    declare -A ultimate_question_dict=(
        ["What"]="life"
        ["Context1"]="universe"
        ["Context2"]="everything"
        ["The Answer"]="42"
    )
}

declare __option

while (( $# > 0 )); do
    __option="$1"
    shift
    get_common_arg "$__option" || error "Invalid argument: $__option"
done

dump_vars \
    --header "Arguments of $script_name:" \
    --core-state

declare -a args=(
    --quiet
    --force
    --header "This Is the Top Header"
    --header "This is a sub Header"
    foo
    --blank
    bar
    --header "What is the answer to:"
    --name "The Ultimate Question" ultimate_question
    --blank
    --name "The Ultimate Question" ultimate_question_dict
    --line
    fish
    animal
    pie_in_the_sky
)

dump_vars "${args[@]}"
