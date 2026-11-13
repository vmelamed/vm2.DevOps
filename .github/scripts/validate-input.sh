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

# vm2 core lib
source "$lib_dir/gh_core.sh"

# vm2 core lib exit codes
declare -xri err_argument_value
declare -xri err_tool_not_found

# vm2 core lib constants
declare -xr check_em
declare -xra output_common_dotnet_args
declare -xra dump_common_dotnet_args

# Declare variables defined in the core library.
declare -x _ignore

source "$script_dir/validate-input.usage.sh"
source "$script_dir/validate-input.args.sh"

get_arguments "$@"
# vm2 core lib arguments - dotnet
declare -xr preprocessor_symbols
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr gh_nuget_username
declare -xr gh_nuget_password
# this scripts arguments
declare -xr build_projects
declare -xr test_projects
declare -xr benchmark_projects
declare -xr package_projects
declare -xr runners_os
declare -xr min_coverage_pct
declare -xr max_regression_pct
declare -xr max_gen1_collects
declare -xr max_gen2_collects
declare -xr reset_benchmark_thresholds
declare -xr skip_tests
declare -xr skip_build
declare -xr skip_benchmarks
declare -xr skip_packages

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
