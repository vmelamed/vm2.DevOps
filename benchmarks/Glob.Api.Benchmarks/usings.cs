// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

global using System.Diagnostics;

global using BenchmarkDotNet.Columns;
global using BenchmarkDotNet.Reports;

global using Microsoft.Extensions.Configuration;
global using Microsoft.Extensions.DependencyInjection;

global using vm2.DevOps.Glob.Api;
global using vm2.DevOps.Glob.Api.Benchmarks.Classes.Options;
global using vm2.DevOps.Glob.Api.DI;
global using vm2.TestUtilities;
global using vm2.TestUtilities.FakeFileSystem;
