// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem.Tests;

using System.Text.Json;

[ExcludeFromCodeCoverage]
public sealed class FolderTests
{
    #region Constructor Tests

    [Fact]
    public void Constructor_WithNoParameters_ShouldCreateDefaultFolder()
    {
        // Arrange & Act
        var folder = new Folder();

        // Assert
        folder.Name.Should().BeEmpty();
        folder.Folders.Should().BeEmpty();
        folder.Files.Should().BeEmpty();
        folder.Path.Should().NotBeEmpty();
        folder.Parent.Should().BeNull();
        folder.Comparer.Should().Be(StringComparer.Ordinal);
    }

    [Fact]
    public void Constructor_WithName_ShouldSetName()
    {
        // Arrange & Act
        var folder = new Folder("testFolder");

        // Assert
        folder.Name.Should().Be("testFolder");
        folder.Folders.Should().BeEmpty();
        folder.Files.Should().BeEmpty();
    }

    [Fact]
    public void Constructor_WithNameFoldersAndFiles_ShouldInitializeAllProperties()
    {
        // Arrange
        var subFolder = new Folder("sub");
        var files = new[] { "file1.txt", "file2.txt" };

        // Act
        var folder = new Folder("root", [subFolder], files);

        // Assert
        folder.Name.Should().Be("root");
        folder.Folders.Should().HaveCount(1);
        folder.Files.Should().HaveCount(2);
        folder.Files.Should().Contain(files);
    }

    [Fact]
    public void Constructor_WithNullFoldersAndFiles_ShouldCreateEmptyCollections()
    {
        // Arrange & Act
        var folder = new Folder("test", null, null);

        // Assert
        folder.Folders.Should().BeEmpty();
        folder.Files.Should().BeEmpty();
    }

    [Fact]
    public void Default_ShouldReturnEmptyFolder()
    {
        // Arrange & Act
        var folder = Folder.Default;

        // Assert
        folder.Should().NotBeNull();
        folder.Name.Should().BeEmpty();
        folder.Folders.Should().BeEmpty();
        folder.Files.Should().BeEmpty();
    }

    #endregion

    #region Property Tests

    [Fact]
    public void Name_ShouldBeReadOnly()
    {
        // Arrange
        var folder = new Folder("original");

        // Assert
        folder.Name.Should().Be("original");
        // Name has private setter, so we can't change it directly
    }

    [Fact]
    public void Folders_ShouldReturnSortedSet()
    {
        // Arrange
        var folder = new Folder("root");
        var child1 = new Folder("b");
        var child2 = new Folder("a");
        var child3 = new Folder("c");

        // Act
        folder.Add(child1);
        folder.Add(child2);
        folder.Add(child3);

        // Assert
        folder.Folders.Should().HaveCount(3);
        folder.Folders.Select(f => f.Name).Should().BeInAscendingOrder();
    }

    [Fact]
    public void Files_ShouldReturnSortedSet()
    {
        // Arrange
        var folder = new Folder("root");

        // Act
        folder.Add("file_b.txt");
        folder.Add("file_a.txt");
        folder.Add("file_c.txt");

        // Assert
        folder.Files.Should().HaveCount(3);
        folder.Files.Should().BeInAscendingOrder();
    }

    [Fact]
    public void Parent_WhenFolderAddedToParent_ShouldSetParentReference()
    {
        // Arrange
        var parent = new Folder("parent");
        var child = new Folder("child");

        // Act
        parent.Add(child); // This sets Parent internally

        // Assert
        child.Parent.Should().Be(parent);
    }

    [Fact]
    public void Parent_WhenSet_ShouldPropagateComparerFromParent()
    {
        // Arrange
        var parent = Folder.LinkChildren(new Folder("C:/"), StringComparer.OrdinalIgnoreCase);
        var child = new Folder("child");

        // Act
        parent.Add(child); // Indirectly sets Parent, which propagates Comparer

        // Assert
        child.Parent.Should().Be(parent);
        child.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
    }

    [Fact]
    public void Comparer_WhenRootLinked_ShouldPropagateToAllDescendants()
    {
        // Arrange
        var root = new Folder("C:/");
        var level1 = new Folder("level1");
        var level2 = new Folder("level2");
        root.Add(level1);
        level1.Add(level2);

        // Act
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase); // Sets Comparer internally

        // Assert
        root.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        level1.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        level2.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
    }

    [Fact]
    public void Comparer_WhenChanged_ShouldAffectFileSearchBehavior()
    {
        // Arrange
        var root = new Folder("C:/");
        var folder = new Folder("test");
        root.Add(folder);
        folder.Add("File.TXT");

        // Act
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase); // Changes Comparer internally

        // Assert - Verify behavior change
        folder.HasFile("file.txt").Should().NotBeNull();
        folder.HasFile("FILE.TXT").Should().NotBeNull();
        folder.HasFile("FiLe.TxT").Should().NotBeNull();
    }

    [Fact]
    public void Comparer_AfterLinking_ShouldRecreateFileAndFolderSets()
    {
        // Arrange
        var root = new Folder("C:/");
        var folder = new Folder("test");
        root.Add(folder);
        folder.Add("File_A.txt");
        folder.Add("file_b.txt");
        var child = new Folder("Child");
        folder.Add(child);

        // Act - change to case-insensitive via LinkChildren
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);

        // Assert
        folder.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        child.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        // Verify case-insensitive behavior works
        folder.HasFile("file_a.txt").Should().Be("File_A.txt");
    }

    [Fact]
    public void Path_ShouldBeCalculatedFromParentHierarchy()
    {
        // Arrange
        var root = new Folder("C:/");
        var level1 = new Folder("folder1");
        var level2 = new Folder("folder2");

        // Act
        root.Add(level1);
        level1.Add(level2);

        // Assert - Path is calculated when Parent is set via Add()
        level1.Path.Should().Be("C:/folder1/");
        level2.Path.Should().Be("C:/folder1/folder2/");
    }

    #endregion

    #region HasFile Tests

    [Fact]
    public void HasFile_WhenFileExists_ShouldReturnFileName()
    {
        // Arrange
        var folder = new Folder("test");
        folder.Add("file.txt");

        // Act
        var result = folder.HasFile("file.txt");

        // Assert
        result.Should().Be("file.txt");
    }

    [Fact]
    public void HasFile_WhenFileDoesNotExist_ShouldReturnNull()
    {
        // Arrange
        var folder = new Folder("test");
        folder.Add("file.txt");

        // Act
        var result = folder.HasFile("missing.txt");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public void HasFile_WithCaseInsensitiveComparer_ShouldFindFileIgnoringCase()
    {
        // Arrange
        var root = new Folder("C:/");
        var folder = new Folder("test");
        root.Add(folder);
        folder.Add("File.TXT");
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);

        // Act
        var result = folder.HasFile("file.txt");

        // Assert
        result.Should().Be("File.TXT");
    }

    [Fact]
    public void HasFile_WithCaseSensitiveComparer_ShouldNotFindFileWithDifferentCase()
    {
        // Arrange
        var root = new Folder("/");
        var folder = new Folder("test");
        root.Add(folder);
        folder.Add("File.TXT");
        Folder.LinkChildren(root, StringComparer.Ordinal);

        // Act
        var result = folder.HasFile("file.txt");

        // Assert
        result.Should().BeNull();
    }

    #endregion

    #region HasFolder Tests

    [Fact]
    public void HasFolder_WithCurrentDir_ShouldReturnSelf()
    {
        // Arrange
        var folder = new Folder("test");

        // Act
        var result = folder.HasFolder(".");

        // Assert
        result.Should().Be(folder);
    }

    [Fact]
    public void HasFolder_WithParentDir_ShouldReturnParent()
    {
        // Arrange
        var parent = new Folder("parent");
        var child = new Folder("child");
        parent.Add(child);

        // Act
        var result = child.HasFolder("..");

        // Assert
        result.Should().Be(parent);
    }

    [Fact]
    public void HasFolder_WithParentDirWhenNoParent_ShouldReturnNull()
    {
        // Arrange
        var folder = new Folder("root");

        // Act
        var result = folder.HasFolder("..");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public void HasFolder_WhenSubfolderExists_ShouldReturnSubfolder()
    {
        // Arrange
        var folder = new Folder("parent");
        var child = new Folder("child");
        folder.Add(child);

        // Act
        var result = folder.HasFolder("child");

        // Assert
        result.Should().Be(child);
    }

    [Fact]
    public void HasFolder_WhenSubfolderDoesNotExist_ShouldReturnNull()
    {
        // Arrange
        var folder = new Folder("parent");

        // Act
        var result = folder.HasFolder("missing");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public void HasFolder_WithCaseInsensitiveComparer_ShouldFindFolderIgnoringCase()
    {
        // Arrange
        var root = new Folder("C:/");
        var folder = new Folder("parent");
        var child = new Folder("Child");
        root.Add(folder);
        folder.Add(child);
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);

        // Act
        var result = folder.HasFolder("CHILD");

        // Assert
        result.Should().Be(child);
    }

    #endregion

    #region Add(Folder) Tests

    [Fact]
    public void AddFolder_ShouldAddFolderAndSetParent()
    {
        // Arrange
        var parent = new Folder("parent");
        var child = new Folder("child");

        // Act
        var result = parent.Add(child);

        // Assert
        result.Should().Be(parent); // Fluent API
        parent.Folders.Should().Contain(child);
        child.Parent.Should().Be(parent);
    }

    [Fact]
    public void AddFolder_WhenDuplicateName_ShouldThrowArgumentException()
    {
        // Arrange
        var parent = new Folder("parent");
        var child1 = new Folder("child");
        var child2 = new Folder("child");
        parent.Add(child1);

        // Act
        var act = () => parent.Add(child2);

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("node")
           .WithMessage("*already exists*");
    }

    [Fact]
    public void AddFolder_ShouldPropagateComparer()
    {
        // Arrange
        var root = new Folder("C:/");
        var parent = new Folder("parent");
        root.Add(parent);
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);
        var child = new Folder("child");

        // Act
        parent.Add(child);

        // Assert
        child.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
    }

    [Fact]
    public void AddFolder_MultipleFolders_ShouldMaintainSortedOrder()
    {
        // Arrange
        var parent = new Folder("parent");

        // Act
        parent.Add(new Folder("c"));
        parent.Add(new Folder("a"));
        parent.Add(new Folder("b"));

        // Assert
        parent.Folders.Select(f => f.Name).Should().BeInAscendingOrder();
    }

    #endregion

    #region Add(string) Tests

    [Fact]
    public void AddFile_ShouldAddFileToCollection()
    {
        // Arrange
        var folder = new Folder("test");

        // Act
        var result = folder.Add("file.txt");

        // Assert
        result.Should().Be(folder); // Fluent API
        folder.Files.Should().Contain("file.txt");
    }

    [Fact]
    public void AddFile_WhenDuplicateFile_ShouldThrowArgumentException()
    {
        // Arrange
        var folder = new Folder("test");
        folder.Add("file.txt");

        // Act
        var act = () => folder.Add("file.txt");

        // Assert
        act.Should().Throw<ArgumentException>()
           .WithParameterName("file")
           .WithMessage("*already exists*");
    }

    [Fact]
    public void AddFile_MultipleFiles_ShouldMaintainSortedOrder()
    {
        // Arrange
        var folder = new Folder("test");

        // Act
        folder.Add("file_c.txt");
        folder.Add("file_a.txt");
        folder.Add("file_b.txt");

        // Assert
        folder.Files.Should().BeInAscendingOrder();
    }

    #endregion

    #region Equals Tests

    [Fact]
    public void Equals_WhenSameReference_ShouldReturnTrue()
    {
        // Arrange
        var folder = new Folder("test");

        // Act
        var result = folder.Equals(folder);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void Equals_WhenOtherIsNull_ShouldReturnFalse()
    {
        // Arrange
        var folder = new Folder("test");

        // Act
        var result = folder.Equals(null);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void Equals_WhenDifferentNames_ShouldReturnFalse()
    {
        // Arrange
        var folder1 = new Folder("test1");
        var folder2 = new Folder("test2");

        // Act
        var result = folder1.Equals(folder2);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void EqualsObject_WhenSameFolder_ShouldReturnTrue()
    {
        // Arrange
        var folder = new Folder("test");
        object obj = folder;

        // Act
        var result = folder.Equals(obj);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void EqualsObject_WhenNotFolder_ShouldReturnFalse()
    {
        // Arrange
        var folder = new Folder("test");
        object obj = "not a folder";

        // Act
        var result = folder.Equals(obj);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void Equals_WhenSameParentAndSameName_CannotAddDuplicate()
    {
        // Arrange
        var parent = new Folder("parent");
        var child1 = new Folder("child");
        var child2 = new Folder("child");
        parent.Add(child1);

        // Act - Try to add another folder with same name
        var act = () => parent.Add(child2);

        // Assert - This proves they are considered equal (duplicate detection works)
        act.Should().Throw<ArgumentException>()
           .WithMessage("*already exists*");
    }

    #endregion

    #region GetHashCode Tests

    [Fact]
    public void GetHashCode_WhenDifferentNames_ShouldBeDifferent()
    {
        // Arrange
        var folder1 = new Folder("test1");
        var folder2 = new Folder("test2");

        // Act
        var hash1 = folder1.GetHashCode();
        var hash2 = folder2.GetHashCode();

        // Assert
        hash1.Should().NotBe(hash2);
    }

    #endregion

    #region ToString Tests

    [Fact]
    public void ToString_ShouldReturnName()
    {
        // Arrange
        var folder = new Folder("testFolder");

        // Act
        var result = folder.ToString();

        // Assert
        result.Should().Be("testFolder");
    }

    [Fact]
    public void ToString_WhenEmptyName_ShouldReturnEmptyString()
    {
        // Arrange
        var folder = new Folder();

        // Act
        var result = folder.ToString();

        // Assert
        result.Should().BeEmpty();
    }

    #endregion

    #region LinkChildren Tests

    [Fact]
    public void LinkChildren_ShouldSetParentsRecursively()
    {
        // Arrange
        var root = new Folder("C:/");
        var level1 = new Folder("folder1");
        var level2 = new Folder("folder2");
        root.Add(level1);
        level1.Add(level2);

        // Act
        var result = Folder.LinkChildren(root, StringComparer.Ordinal);

        // Assert
        result.Should().Be(root);
        level1.Parent.Should().Be(root);
        level2.Parent.Should().Be(level1);
    }

    [Fact]
    public void LinkChildren_ShouldSetComparerRecursively()
    {
        // Arrange
        var root = new Folder("C:/");
        var level1 = new Folder("folder1");
        var level2 = new Folder("folder2");
        root.Add(level1);
        level1.Add(level2);

        // Act
        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);

        // Assert
        root.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        level1.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
        level2.Comparer.Should().Be(StringComparer.OrdinalIgnoreCase);
    }

    [Fact]
    public void LinkChildren_ShouldCalculatePathsCorrectly()
    {
        // Arrange
        var root = new Folder("C:/");
        var level1 = new Folder("folder1");
        var level2 = new Folder("folder2");
        root.Add(level1);
        level1.Add(level2);

        // Act
        Folder.LinkChildren(root, StringComparer.Ordinal);

        // Assert
        root.Path.Should().Be("C:/");
        level1.Path.Should().Be("C:/folder1/");
        level2.Path.Should().Be("C:/folder1/folder2/");
    }

    [Fact]
    public void LinkChildren_WhenRootHasParent_ShouldThrowArgumentException()
    {
        // Arrange
        var grandparent = new Folder("grandparent");
        var root = new Folder("C:/");

        // Act
        var add = () => grandparent.Add(root);

        // Assert
        add.Should()
           .Throw<ArgumentException>()
           .WithParameterName("node")
           .WithMessage("Root folder cannot be added as a child. (Parameter 'node')")
           ;
    }

    [Fact]
    public void LinkChildren_WhenRootNameDoesNotEndWithSeparator_ShouldThrowInvalidDataException()
    {
        // Arrange
        var root = new Folder("C:");

        // Act
        var act = () => Folder.LinkChildren(root, StringComparer.Ordinal);

        // Assert
        act.Should().Throw<InvalidDataException>()
           .WithMessage($"*must end with '/'*")
           ;
    }

    [Fact]
    public void LinkChildren_WithUnixRoot_ShouldWork()
    {
        // Arrange
        var root = new Folder("/");
        var folder = new Folder("home");
        root.Add(folder);

        // Act
        var result = Folder.LinkChildren(root, StringComparer.Ordinal);

        // Assert
        result.Path.Should().Be("/");
        folder.Path.Should().Be("/home/");
    }

    #endregion

    #region Integration Tests

    [Fact]
    public void Integration_BuildComplexHierarchy_ShouldWorkCorrectly()
    {
        // Arrange
        var root = new Folder("C:/");
        var users = new Folder("Users");
        var john = new Folder("John");
        var documents = new Folder("Documents");

        // Act
        root.Add(users);
        users.Add(john);
        john.Add(documents);
        documents.Add("report.pdf");
        documents.Add("notes.txt");

        Folder.LinkChildren(root, StringComparer.OrdinalIgnoreCase);

        // Assert
        documents.Path.Should().Be("C:/Users/John/Documents/");
        documents.Files.Should().HaveCount(2);
        documents.HasFile("REPORT.PDF").Should().Be("report.pdf");
        john.HasFolder("documents").Should().Be(documents);
    }

    [Fact]
    public void Integration_SerializeAndDeserialize_ShouldPreserveStructure()
    {
        // Arrange
        var root = new Folder("C:/",
            [new Folder("folder1", null, ["file1.txt"])],
            ["root.txt"]);

        // Act
        var json = JsonSerializer.Serialize(root, FolderSourceGenerationContext.Default.Folder);
        var deserialized = JsonSerializer.Deserialize(json, FolderSourceGenerationContext.Default.Folder);

        // Assert
        deserialized.Should().NotBeNull();
        deserialized!.Name.Should().Be("C:/");
        deserialized.Folders.Should().HaveCount(1);
        deserialized.Files.Should().Contain("root.txt");
        deserialized.Folders.First().Files.Should().Contain("file1.txt");
    }

    #endregion
}