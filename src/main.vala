namespace ProtonPlus {
	public static int main (string[] args) {
		if (!Thread.supported ()) {
			message ("Threads are not supported!");
			return -1;
		}

		Intl.bindtextdomain (Globals.APP_ID, Globals.LOCALE_DIR);
		Intl.bind_textdomain_codeset (Globals.APP_ID, "UTF-8");
		Intl.textdomain (Globals.APP_ID);

		var application = new Widgets.Application ();
		return application.run (args);
	}

	static string[] string_table () {
		return {
			_("Compatibility tools by Valve for running Windows software on Linux."),
			_("Steam compatibility tool for running Windows games with improvements over Valve's default Proton."),
			_("Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton."),
			_("Steam compatibility tool for running Windows games with improvements over Valve's default Proton. By Etaash Mathamsetty adding FSR4 support and wine wayland tweaks."),
			_("Custom Proton build for running Windows games, based on Wine-tkg."),
			_("Steam compatibility tool based on Proton-GE with modifications for very old GPUs, with DXVK."),
			_("Steam compatibility tool based on Proton-GE with modifications for very old GPUs, with DXVK-Async."),
			_("Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat."),
			_("Custom Proton build for running the Northstar client for Titanfall 2."),
			_("Luxtorpeda provides Linux-native game engines for certain Windows-only games."),
			_("Steam compatibility tool for running adventure games using ScummVM for Linux."),
			_("Steam compatibility tool for running DOS games using DOSBox for Linux."),
			_("Compatibility tools for running Windows software on Linux."),
			_("Wine build compiled from the official WineHQ sources."),
			_("Wine build with the Staging patchset."),
			_("Wine build with the Staging patchset and many other useful patches."),
			_("Vulkan-based implementation of Direct3D 8, 9, 10 and 11 for Linux/Wine."),
			_("DXVK Builds that work with pre-Vulkan 1.3 versions"),
			_("DXVK Async Builds that work with pre-Vulkan 1.3 versions"),
			_("Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan."),
		};
	}
}
