# Script to create test directory structure for Glob.Api integration tests on Windows

param(
    [string]$BaseDir = ".\test-glob-structure"
)

Write-Host "Creating test directory structure in: $BaseDir" -ForegroundColor Green

# Clean up if exists
if (Test-Path $BaseDir) {
    Write-Host "Removing existing test structure..." -ForegroundColor Yellow
    Remove-Item -Path $BaseDir -Recurse -Force
}

# Create base directory
New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

# Case sensitivity test structure (Windows is case-insensitive, so create one version)
$caseTest = Join-Path $BaseDir "case-test"
New-Item -ItemType Directory -Path $caseTest -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "file.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "FILE.TXT") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "File.Txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "readme.md") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "README.MD") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $caseTest "ReadMe.Md") -Force | Out-Null

# Recursive wildcard test structure
$recursive = Join-Path $BaseDir "recursive"
$level3 = Join-Path $recursive "level1\level2\level3"
New-Item -ItemType Directory -Path $level3 -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $recursive "root.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $recursive "level1\one.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $recursive "level1\level2\two.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $level3 "three.txt") -Force | Out-Null

$branch1sub1 = Join-Path $recursive "branch1\subbranch1"
$branch1sub2 = Join-Path $recursive "branch1\subbranch2"
$branch2sub3 = Join-Path $recursive "branch2\subbranch3"
New-Item -ItemType Directory -Path $branch1sub1 -Force | Out-Null
New-Item -ItemType Directory -Path $branch1sub2 -Force | Out-Null
New-Item -ItemType Directory -Path $branch2sub3 -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $recursive "branch1\branch.log") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $branch1sub1 "leaf1.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $branch1sub2 "leaf2.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $recursive "branch2\branch2.log") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $branch2sub3 "leaf3.txt") -Force | Out-Null

# Special characters test structure
$specialChars = Join-Path $BaseDir "special-chars"
$spacesDir = Join-Path $specialChars "spaces in names"
New-Item -ItemType Directory -Path $spacesDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $spacesDir "file with spaces.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $spacesDir "another file.dat") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $spacesDir "test file 123.log") -Force | Out-Null

$symbolsDir = Join-Path $specialChars "symbols"
New-Item -ItemType Directory -Path $symbolsDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $symbolsDir "file@home.txt") -Force | Out-Null
# Note: Some characters may be restricted on Windows (like :, <, >, |, ?, *)
New-Item -ItemType File -Path (Join-Path $symbolsDir "data`$1.csv") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $symbolsDir "config#main.ini") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $symbolsDir "backup~old.bak") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $symbolsDir "report_2024.pdf") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $symbolsDir "script-v1.sh") -Force | Out-Null

$parenDir = Join-Path $specialChars "parentheses"
New-Item -ItemType Directory -Path $parenDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $parenDir "file(1).txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $parenDir "data(copy).dat") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $parenDir "test(final)(2).log") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $parenDir "(start)file.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $parenDir "file(end)") -Force | Out-Null

$bracketsDir = Join-Path $specialChars "brackets"
New-Item -ItemType Directory -Path $bracketsDir -Force | Out-Null
# Windows may have issues with brackets in filenames
try {
    New-Item -ItemType File -Path (Join-Path $bracketsDir "array[0].txt") -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType File -Path (Join-Path $bracketsDir "data[index].dat") -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType File -Path (Join-Path $bracketsDir "test[1][2].log") -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType File -Path (Join-Path $bracketsDir "[prefix]file.txt") -Force -ErrorAction SilentlyContinue | Out-Null
} catch {
    Write-Host "Warning: Some bracket filenames may not be supported on Windows" -ForegroundColor Yellow
}

$unicodeDir = Join-Path $specialChars "unicode"
New-Item -ItemType Directory -Path $unicodeDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "café.md") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "naïve.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "résumé.pdf") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "файл.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "文档.doc") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $unicodeDir "Ὀδυσσεύς.txt") -Force | Out-Null

# Hidden files (dot files) - Windows handles these differently
$hiddenDir = Join-Path $BaseDir "hidden"
New-Item -ItemType Directory -Path $hiddenDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir ".bashrc") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir ".profile") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir ".vimrc") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir ".hidden") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir "..double") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir "...triple") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $hiddenDir "visible.txt") -Force | Out-Null

# Bracket expression tests
$bracketsTestDir = Join-Path $BaseDir "brackets"
New-Item -ItemType Directory -Path $bracketsTestDir -Force | Out-Null
@('a','b','c','x','y','z','1','2','3','9') | ForEach-Object {
    New-Item -ItemType File -Path (Join-Path $bracketsTestDir $_) -Force | Out-Null
}
@('file-a.txt','file-b.txt','file-1.txt','file-2.txt') | ForEach-Object {
    New-Item -ItemType File -Path (Join-Path $bracketsTestDir $_) -Force | Out-Null
}

# Relative path tests
$projectsDir = Join-Path $BaseDir "projects"
$app1 = Join-Path $projectsDir "app1"
$app2 = Join-Path $projectsDir "app2"
$shared = Join-Path $projectsDir "shared"

New-Item -ItemType Directory -Path (Join-Path $app1 "src") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $app1 "tests") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $app2 "src") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $app2 "tests") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $shared "lib") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $shared "include") -Force | Out-Null

New-Item -ItemType File -Path (Join-Path $app1 "README.md") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "Makefile") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "src\main.c") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "src\util.c") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "src\app.h") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "tests\test_main.c") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app1 "tests\test_util.c") -Force | Out-Null

New-Item -ItemType File -Path (Join-Path $app2 "README.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app2 "requirements.txt") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app2 "src\app.py") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app2 "src\config.py") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $app2 "tests\test_app.py") -Force | Out-Null

New-Item -ItemType File -Path (Join-Path $shared "LICENSE") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $shared "lib\common.c") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $shared "include\constants.h") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $shared "include\types.h") -Force | Out-Null

# Performance test structure (wide and deep)
$perfDir = Join-Path $BaseDir "performance"
$wideDir = Join-Path $perfDir "wide"
New-Item -ItemType Directory -Path $wideDir -Force | Out-Null
1..100 | ForEach-Object {
    New-Item -ItemType File -Path (Join-Path $wideDir "file$_.txt") -Force | Out-Null
}

$deepPath = Join-Path $perfDir "deep\l1\l2\l3\l4\l5\l6\l7\l8\l9\l10"
New-Item -ItemType Directory -Path $deepPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $deepPath "deep.txt") -Force | Out-Null

$dirCount = (Get-ChildItem -Path $BaseDir -Recurse -Directory).Count
$fileCount = (Get-ChildItem -Path $BaseDir -Recurse -File).Count

Write-Host "Test directory structure created successfully!" -ForegroundColor Green
Write-Host "Total directories: $dirCount" -ForegroundColor Cyan
Write-Host "Total files: $fileCount" -ForegroundColor Cyan