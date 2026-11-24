namespace ProtonPlus.Services {
    public class ProtonAutogenGameLaunchService : Object {
        public static Subprocess launch (string executable_path, bool through_flatpak_host) throws Error {
            if (!Path.is_absolute (executable_path))
                throw new IOError.INVALID_ARGUMENT (_("The Proton-Autogen profile requires an absolute executable path."));

            // Proton-Autogen uses the registered path to look up the profile.
            string[] argv = through_flatpak_host
                ? new string[] { "flatpak-spawn", "--host", "proton-autogen", "run", executable_path }
                : new string[] { "proton-autogen", "run", executable_path };
            return Utils.System.spawn_detached (argv);
        }
    }
}
