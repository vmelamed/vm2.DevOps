#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# core lib
source "$lib_dir/gh_core.sh"

# core lib exit codes
declare -xri err_argument_value
declare -xri err_tool_not_found

# core lib constants
declare -xr check_em
declare -xra output_common_dotnet_args
declare -xra dump_common_dotnet_args

# Declare variables defined in the core library.
declare -x _ignore

source "$script_dir/validate-input.usage.sh"
source "$script_dir/validate-input.args.sh"

get_arguments "$@"
# core lib arguments - dotnet
declare -xr preprocessor_symbols
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr gh_nuget_username
declare -xr gh_nuget_password
# this scripts arguments
declare -x build_projects
declare -x test_projects
declare -x benchmark_projects
declare -x package_projects
declare -x runners_os
declare -x min_coverage_pct
declare -x max_regression_pct
declare -x max_gen1_collects
declare -x max_gen2_collects
declare -x reset_benchmark_thresholds
declare -x skip_tests
declare -x skip_build
declare -x skip_benchmarks
declare -x skip_packages

info "$check_em All parameters validated successfully"

# Output all variables to GITHUB_OUTPUT for use in subsequent jobs
args_to_github_output \
    build_projects \
    test_projects \
    benchmark_projects \
    package_projects \
    runners_os \
    min_coverage_pct \
    max_regression_pct \
    max_gen1_collects \
    max_gen2_collects \
    reset_benchmark_thresholds \
    skip_build \
    skip_tests \
    skip_benchmarks \
    skip_packages \
    "${output_common_dotnet_args[@]}"
