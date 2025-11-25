global using System.Configuration;
global using System.Diagnostics;
global using System.Diagnostics.CodeAnalysis;
global using System.Text;

global using Microsoft.Extensions.Configuration;
global using Microsoft.Extensions.DependencyInjection;
global using Microsoft.Extensions.Hosting;
global using Microsoft.Extensions.Logging;

global using vm2.DevOps.Glob.Api;
global using vm2.DevOps.Glob.Api.DI;
global using vm2.Test.Utilities.FakeFileSystem;
global using vm2.Test.Utilities.XUnitLogger;

global using Xunit.Sdk;

global using static vm2.Test.Utilities.TestUtilities;

[assembly: CaptureConsole]
