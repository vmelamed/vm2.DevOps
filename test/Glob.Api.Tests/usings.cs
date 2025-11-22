global using System.Configuration;
global using System.Diagnostics;
global using System.Diagnostics.CodeAnalysis;
global using System.Globalization;
global using System.Runtime.CompilerServices;
global using System.Text;
global using System.Text.Json;
global using System.Text.Json.Serialization;
global using System.Text.RegularExpressions;

global using Microsoft.Extensions.Configuration;
global using Microsoft.Extensions.DependencyInjection;
global using Microsoft.Extensions.Hosting;
global using Microsoft.Extensions.Logging;

global using vm2.DevOps.Glob.Api;
global using vm2.DevOps.Glob.Api.Tests.FakeFileSystem;

global using Xunit.Sdk;

global using static vm2.DevOps.Glob.Api.GlobConstants;
global using static vm2.DevOps.Glob.Api.Tests.Utilities.TestUtilities;

[assembly: CaptureConsole]
