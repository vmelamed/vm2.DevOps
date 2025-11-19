#!/bin/bash
# Script to create test directory structure for Glob.Api integration tests on Linux

set -e

BASE_DIR="${1:-./test-glob-structure}"

echo "Creating test directory structure in: $BASE_DIR"

# Clean up if exists
if [ -d "$BASE_DIR" ]; then
    echo "Removing existing test structure..."
    rm -rf "$BASE_DIR"
fi

# Create base directory
mkdir -p "$BASE_DIR"

# Case sensitivity test structure
mkdir -p "$BASE_DIR/case-test"
touch "$BASE_DIR/case-test/file.txt"
touch "$BASE_DIR/case-test/FILE.TXT"
touch "$BASE_DIR/case-test/File.Txt"
touch "$BASE_DIR/case-test/readme.md"
touch "$BASE_DIR/case-test/README.MD"
touch "$BASE_DIR/case-test/ReadMe.Md"

# Recursive wildcard test structure
mkdir -p "$BASE_DIR/recursive/level1/level2/level3"
touch "$BASE_DIR/recursive/root.txt"
touch "$BASE_DIR/recursive/level1/one.txt"
touch "$BASE_DIR/recursive/level1/level2/two.txt"
touch "$BASE_DIR/recursive/level1/level2/level3/three.txt"

mkdir -p "$BASE_DIR/recursive/branch1/subbranch1"
mkdir -p "$BASE_DIR/recursive/branch1/subbranch2"
mkdir -p "$BASE_DIR/recursive/branch2/subbranch3"
touch "$BASE_DIR/recursive/branch1/branch.log"
touch "$BASE_DIR/recursive/branch1/subbranch1/leaf1.txt"
touch "$BASE_DIR/recursive/branch1/subbranch2/leaf2.txt"
touch "$BASE_DIR/recursive/branch2/branch2.log"
touch "$BASE_DIR/recursive/branch2/subbranch3/leaf3.txt"

# Special characters test structure
mkdir -p "$BASE_DIR/special-chars/spaces in names"
touch "$BASE_DIR/special-chars/spaces in names/file with spaces.txt"
touch "$BASE_DIR/special-chars/spaces in names/another file.dat"
touch "$BASE_DIR/special-chars/spaces in names/test file 123.log"

mkdir -p "$BASE_DIR/special-chars/symbols"
touch "$BASE_DIR/special-chars/symbols/file@home.txt"
touch "$BASE_DIR/special-chars/symbols/data\$1.csv"
touch "$BASE_DIR/special-chars/symbols/config#main.ini"
touch "$BASE_DIR/special-chars/symbols/backup~old.bak"
touch "$BASE_DIR/special-chars/symbols/report_2024.pdf"
touch "$BASE_DIR/special-chars/symbols/script-v1.sh"

mkdir -p "$BASE_DIR/special-chars/parentheses"
touch "$BASE_DIR/special-chars/parentheses/file(1).txt"
touch "$BASE_DIR/special-chars/parentheses/data(copy).dat"
touch "$BASE_DIR/special-chars/parentheses/test(final)(2).log"
touch "$BASE_DIR/special-chars/parentheses/(start)file.txt"
touch "$BASE_DIR/special-chars/parentheses/file(end)"

mkdir -p "$BASE_DIR/special-chars/brackets"
touch "$BASE_DIR/special-chars/brackets/array[0].txt"
touch "$BASE_DIR/special-chars/brackets/data[index].dat"
touch "$BASE_DIR/special-chars/brackets/test[1][2].log"
touch "$BASE_DIR/special-chars/brackets/[prefix]file.txt"

mkdir -p "$BASE_DIR/special-chars/unicode"
touch "$BASE_DIR/special-chars/unicode/café.md"
touch "$BASE_DIR/special-chars/unicode/naïve.txt"
touch "$BASE_DIR/special-chars/unicode/résumé.pdf"
touch "$BASE_DIR/special-chars/unicode/файл.txt"
touch "$BASE_DIR/special-chars/unicode/文档.doc"
touch "$BASE_DIR/special-chars/unicode/Ὀδυσσεύς.txt"

# Hidden files (dot files)
mkdir -p "$BASE_DIR/hidden"
touch "$BASE_DIR/hidden/.bashrc"
touch "$BASE_DIR/hidden/.profile"
touch "$BASE_DIR/hidden/.vimrc"
touch "$BASE_DIR/hidden/.hidden"
touch "$BASE_DIR/hidden/..double"
touch "$BASE_DIR/hidden/...triple"
touch "$BASE_DIR/hidden/visible.txt"

# Bracket expression tests
mkdir -p "$BASE_DIR/brackets"
touch "$BASE_DIR/brackets/a"
touch "$BASE_DIR/brackets/b"
touch "$BASE_DIR/brackets/c"
touch "$BASE_DIR/brackets/x"
touch "$BASE_DIR/brackets/y"
touch "$BASE_DIR/brackets/z"
touch "$BASE_DIR/brackets/1"
touch "$BASE_DIR/brackets/2"
touch "$BASE_DIR/brackets/3"
touch "$BASE_DIR/brackets/9"
touch "$BASE_DIR/brackets/file-a.txt"
touch "$BASE_DIR/brackets/file-b.txt"
touch "$BASE_DIR/brackets/file-1.txt"
touch "$BASE_DIR/brackets/file-2.txt"

# Relative path tests
mkdir -p "$BASE_DIR/projects/app1/src"
mkdir -p "$BASE_DIR/projects/app1/tests"
mkdir -p "$BASE_DIR/projects/app2/src"
mkdir -p "$BASE_DIR/projects/app2/tests"
mkdir -p "$BASE_DIR/projects/shared/lib"
mkdir -p "$BASE_DIR/projects/shared/include"

touch "$BASE_DIR/projects/app1/README.md"
touch "$BASE_DIR/projects/app1/Makefile"
touch "$BASE_DIR/projects/app1/src/main.c"
touch "$BASE_DIR/projects/app1/src/util.c"
touch "$BASE_DIR/projects/app1/src/app.h"
touch "$BASE_DIR/projects/app1/tests/test_main.c"
touch "$BASE_DIR/projects/app1/tests/test_util.c"

touch "$BASE_DIR/projects/app2/README.txt"
touch "$BASE_DIR/projects/app2/requirements.txt"
touch "$BASE_DIR/projects/app2/src/app.py"
touch "$BASE_DIR/projects/app2/src/config.py"
touch "$BASE_DIR/projects/app2/tests/test_app.py"

touch "$BASE_DIR/projects/shared/LICENSE"
touch "$BASE_DIR/projects/shared/lib/common.c"
touch "$BASE_DIR/projects/shared/include/constants.h"
touch "$BASE_DIR/projects/shared/include/types.h"

# Performance test structure (wide and deep)
mkdir -p "$BASE_DIR/performance/wide"
for i in {1..100}; do
    touch "$BASE_DIR/performance/wide/file$i.txt"
done

mkdir -p "$BASE_DIR/performance/deep/l1/l2/l3/l4/l5/l6/l7/l8/l9/l10"
touch "$BASE_DIR/performance/deep/l1/l2/l3/l4/l5/l6/l7/l8/l9/l10/deep.txt"

echo "Test directory structure created successfully!"
echo "Total directories: $(find "$BASE_DIR" -type d | wc -l)"
echo "Total files: $(find "$BASE_DIR" -type f | wc -l)"