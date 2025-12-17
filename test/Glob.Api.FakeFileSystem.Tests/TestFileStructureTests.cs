// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem.Tests;

[ExcludeFromCodeCoverage]
public sealed class TestFileStructureTests : IDisposable
{
    string _testRootPath = null!;
    string _jsonModelPath = null!;

    public TestFileStructureTests()
    {
        _testRootPath = Path.Combine(Path.GetTempPath(), $"TestFileStructure_{Guid.NewGuid():N}");
        _jsonModelPath = Path.Combine(_testRootPath, "model.json");
        Directory.CreateDirectory(_testRootPath);
    }

    public void Dispose()
    {
        if (Directory.Exists(_testRootPath))
            Directory.Delete(_testRootPath, recursive: true);
    }

    #region CreateTestFileStructure Tests

    [Fact]
    public void CreateTestFileStructure_WhenJsonModelFileNameIsNull_ShouldThrowArgumentException_Async()
    {
        // Arrange & Act
        var act = () => TestFileStructure.CreateTestFileStructure(null!, _testRootPath);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("fsJsonModelFileName")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void CreateTestFileStructure_WhenJsonModelFileNameIsEmpty_ShouldThrowArgumentException_Async()
    {
        // Arrange & Act
        var act = () => TestFileStructure.CreateTestFileStructure(string.Empty, _testRootPath);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("fsJsonModelFileName")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void CreateTestFileStructure_WhenJsonModelFileNameIsWhitespace_ShouldThrowArgumentException_Async()
    {
        // Arrange & Act
        var act = () => TestFileStructure.CreateTestFileStructure("   ", _testRootPath);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("fsJsonModelFileName")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void CreateTestFileStructure_WhenJsonModelFileDoesNotExist_ShouldThrowFileNotFoundException_Async()
    {
        // Arrange
        var nonExistentFile = Path.Combine(_testRootPath, "nonexistent.json");

        // Act
        var act = () => TestFileStructure.CreateTestFileStructure(nonExistentFile, _testRootPath);

        // Assert
        act.Should().Throw<FileNotFoundException>()
           .WithMessage("*JSON model file was not found*")
           .Which.FileName.Should().Be(nonExistentFile);
    }

    [Fact]
    public void CreateTestFileStructure_WhenTestRootPathIsNull_ShouldThrowArgumentException_Async()
    {
        // Arrange
        File.WriteAllText(_jsonModelPath, @"{""name"":""/"",""folders"":[],""files"":[]}");

        // Act
        var act = () => TestFileStructure.CreateTestFileStructure(_jsonModelPath, null!);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("testRootPath")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void CreateTestFileStructure_WhenTestRootPathIsEmpty_ShouldThrowArgumentException_Async()
    {
        // Arrange
        File.WriteAllText(_jsonModelPath, @"{""name"":""/"",""folders"":[],""files"":[]}");

        // Act
        var act = () => TestFileStructure.CreateTestFileStructure(_jsonModelPath, string.Empty);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("testRootPath")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void CreateTestFileStructure_WhenValidJsonModel_ShouldCreateFileStructure_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[{""name"":""folder1"",""folders"":[],""files"":[""file1.txt""]}],""files"":[""root.txt""]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "output");

        // Act
        TestFileStructure.CreateTestFileStructure(_jsonModelPath, targetPath);

        // Assert
        File.Exists(Path.Combine(targetPath, "root.txt")).Should().BeTrue();
        File.Exists(Path.Combine(targetPath, "folder1", "file1.txt")).Should().BeTrue();
        Directory.Exists(Path.Combine(targetPath, "folder1")).Should().BeTrue();
    }

    [Fact]
    public void CreateTestFileStructure_WhenNestedFolders_ShouldCreateAllLevels_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[{""name"":""level1"",""folders"":[{""name"":""level2"",""folders"":[],""files"":[""deep.txt""]}],""files"":[]}],""files"":[]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "nested");

        // Act
        TestFileStructure.CreateTestFileStructure(_jsonModelPath, targetPath);

        // Assert
        File.Exists(Path.Combine(targetPath, "level1", "level2", "deep.txt")).Should().BeTrue();
        Directory.Exists(Path.Combine(targetPath, "level1", "level2")).Should().BeTrue();
    }

    [Fact]
    public void CreateTestFileStructure_WhenFileAlreadyExists_ShouldNotOverwrite_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[],""files"":[""existing.txt""]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "existing");
        Directory.CreateDirectory(targetPath);
        var existingFile = Path.Combine(targetPath, "existing.txt");
        File.WriteAllText(existingFile, "original content");

        // Act
        TestFileStructure.CreateTestFileStructure(_jsonModelPath, targetPath);

        // Assert
        File.ReadAllText(existingFile).Should().Be("original content");
    }

    #endregion

    #region VerifyTestFileStructure Tests

    [Fact]
    public void VerifyTestFileStructure_WhenJsonModelFileNameIsNull_ShouldThrowArgumentException_Async()
    {
        // Arrange & Act
        var act = () => TestFileStructure.VerifyTestFileStructure(null!, _testRootPath).ToList();

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("fsJsonModelFileName")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void VerifyTestFileStructure_WhenJsonModelFileNameIsEmpty_ShouldThrowArgumentException_Async()
    {
        // Arrange & Act
        var act = () => TestFileStructure.VerifyTestFileStructure(string.Empty, _testRootPath).ToList();

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("fsJsonModelFileName")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void VerifyTestFileStructure_WhenJsonModelFileDoesNotExist_ShouldThrowFileNotFoundException_Async()
    {
        // Arrange
        var nonExistentFile = Path.Combine(_testRootPath, "nonexistent.json");

        // Act
        var act = () => TestFileStructure.VerifyTestFileStructure(nonExistentFile, _testRootPath).ToList();

        // Assert
        act.Should().Throw<FileNotFoundException>()
           .WithMessage("*JSON model file was not found*");
    }

    [Fact]
    public void VerifyTestFileStructure_WhenTestRootPathIsNull_ShouldThrowArgumentException_Async()
    {
        // Arrange
        File.WriteAllText(_jsonModelPath, @"{""name"":""/"",""folders"":[],""files"":[]}");

        // Act
        var act = () => TestFileStructure.VerifyTestFileStructure(_jsonModelPath, null!).ToList();

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("testRootPath")
           .WithMessage("*cannot be null, empty, or consist only of whitespaces*");
    }

    [Fact]
    public void VerifyTestFileStructure_WhenStructureMatches_ShouldReturnNoErrors_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[{""name"":""folder1"",""folders"":[],""files"":[""file1.txt""]}],""files"":[""root.txt""]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "verify");
        TestFileStructure.CreateTestFileStructure(_jsonModelPath, targetPath);

        // Act
        var errors = TestFileStructure.VerifyTestFileStructure(_jsonModelPath, targetPath).ToList();

        // Assert
        errors.Should().BeEmpty();
    }

    [Fact]
    public void VerifyTestFileStructure_WhenDirectoryMissing_ShouldReturnError_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[{""name"":""missing"",""folders"":[],""files"":[]}],""files"":[]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "verify_missing");
        Directory.CreateDirectory(targetPath);

        // Act
        var errors = TestFileStructure.VerifyTestFileStructure(_jsonModelPath, targetPath).ToList();

        // Assert
        errors.Should().HaveCount(1);
        errors[0].Should().Contain("does not exist");
    }

    [Fact]
    public void VerifyTestFileStructure_WhenFileMissing_ShouldReturnError_Async()
    {
        // Arrange
        var json = @"{""name"":""/"",""folders"":[],""files"":[""missing.txt""]}";
        File.WriteAllText(_jsonModelPath, json);
        var targetPath = Path.Combine(_testRootPath, "verify_file");
        Directory.CreateDirectory(targetPath);

        // Act
        var errors = TestFileStructure.VerifyTestFileStructure(_jsonModelPath, targetPath).ToList();

        // Assert
        errors.Should().HaveCount(1);
        errors[0].Should().Contain("does not exist");
    }

    #endregion

    #region ExpandEnvironmentVariables Tests

    [Fact]
    public void ExpandEnvironmentVariables_WhenPathIsNull_ShouldReturnNull_Async()
    {
        // Arrange & Act
        var result = TestFileStructure.ExpandEnvironmentVariables(null!);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public void ExpandEnvironmentVariables_WhenPathIsEmpty_ShouldReturnEmpty_Async()
    {
        // Arrange & Act
        var result = TestFileStructure.ExpandEnvironmentVariables(string.Empty);

        // Assert
        result.Should().BeEmpty();
    }

    [Fact]
    public void ExpandEnvironmentVariables_WhenPathIsWhitespace_ShouldReturnWhitespace_Async()
    {
        // Arrange & Act
        var result = TestFileStructure.ExpandEnvironmentVariables("   ");

        // Assert
        result.Should().Be("   ");
    }

    [Fact]
    public void ExpandEnvironmentVariables_WhenNoVariables_ShouldReturnOriginalPath_Async()
    {
        // Arrange
        var path = "/home/user/documents";

        // Act
        var result = TestFileStructure.ExpandEnvironmentVariables(path);

        // Assert
        result.Should().Be(path);
    }

    [Theory]
#if WINDOWS
    [InlineData("C:\\Users\\%USERNAME%\\Documents", "USERNAME")]
    [InlineData("%USERPROFILE%\\Documents", "USERPROFILE")]
    [InlineData("%TEMP%\\test.txt", "TEMP")]
#elif UNIX
    [InlineData("$HOME/documents", "HOME")]
    [InlineData("${USER}/data", "USER")]
    [InlineData("~/documents", "HOME")]
#endif
    public void ExpandEnvironmentVariables_ShouldExpandVariables_Async(string path, string varName)
    {
        // Arrange
        var expectedValue = Environment.GetEnvironmentVariable(varName);
        expectedValue.Should().NotBeNullOrEmpty();

        // Act
        var result = TestFileStructure.ExpandEnvironmentVariables(path);

        // Assert
        result.Should().Contain(expectedValue);
    }

    [Fact]
    public void ExpandEnvironmentVariables_WithMultipleVariables_ShouldExpandAll_Async()
    {
        // Arrange
        Environment.SetEnvironmentVariable("TEST_VAR1", "value1");
        Environment.SetEnvironmentVariable("TEST_VAR2", "value2");
        var path = "%TEST_VAR1%/%TEST_VAR2%/file.txt";

        try
        {
            // Act
            var result = TestFileStructure.ExpandEnvironmentVariables(path);

            // Assert
            result.Should().Contain("value1");
            result.Should().Contain("value2");
        }
        finally
        {
            Environment.SetEnvironmentVariable("TEST_VAR1", null);
            Environment.SetEnvironmentVariable("TEST_VAR2", null);
        }
    }

    [Fact]
    public void ExpandEnvironmentVariables_WithNonExistentVariable_ShouldLeaveUnchanged_Async()
    {
        // Arrange
        var path = "%NONEXISTENT_VAR_12345%/path";

        // Act
        var result = TestFileStructure.ExpandEnvironmentVariables(path);

        // Assert
        result.Should().Contain("%NONEXISTENT_VAR_12345%");
    }

    #endregion
}
