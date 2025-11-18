namespace vm2.DevOps.Glob.Api;

public static class GlobEnumeratorExtensions
{
    extension(IServiceCollection serviceCollection)
    {
        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection.
        /// </summary>
        /// <returns></returns>
        public IServiceCollection AddGlobEnumerator()
        {
            serviceCollection.AddTransient<GlobEnumeratorBuilder>();
            serviceCollection.AddSingleton<IFileSystem, FileSystem>();
            serviceCollection.AddTransient<GlobEnumerator>();

            return serviceCollection;
        }
    }
}
