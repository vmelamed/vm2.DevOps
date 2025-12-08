# Integration Tests Guide

Real file system tests (not FakeFS mocks).

## Setup

### Linux/macOS

    chmod +x ../../scripts/create-test-structure.sh
    ../../scripts/create-test-structure.sh

### Windows PowerShell

    ..\..\scripts\create-test-structure.ps1

## Running Tests

### All integration tests

    dotnet test --filter "FullyQualifiedName~IntegrationTests"

### Specific test

    dotnet test --filter "Integration_Recursive_Enumeration"

## Cleanup

### Linux/macOS

    ../../scripts/cleanup-test-structure.sh

### Windows

    ..\..\scripts\cleanup-test-structure.ps1

## Platform-Specific Tests

**Unix tests:** Require case-sensitive file system
**Windows tests:** Require case-insensitive file system

Tests auto-skip on incompatible platforms.

## Test Categories

- Recursive enumeration (** wildcard)
- Special characters (spaces, Unicode, symbols)
- Case sensitivity (platform-specific)
- Hidden files (dot files on Unix)
- Relative paths (. and ..)
- Traversal order (depth-first vs breadth-first)