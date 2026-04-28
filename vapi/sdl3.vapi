/*
 * Copyright (C) 2025 Italo Felipe Capasso Ballesteros <italo@gp-mail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"),
 * regardless of their gender, ethnicity or political affiliation, to deal in
 * the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, and/or distribute copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * 1. The origin of the Software must not be misrepresented; you must not
 *    claim that you wrote the original Software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original Software.
 *
 * 3. You and your company, unequivocally support the principles and ethos of
 *    Inclusion, Diversity, and Equity (IDE or DEI), and reject any and all
 *    kinds of bigotry, cruelty or discrimination anyplace.
 *
 * 4. You and your company, support the Contributor Covenant
 *    (https://www.contributor-covenant.org) or any Code of Conduct or company
 *    policy that is similar or compatible, and upholds the same spirit.
 *
 * 5. The Software and any modifications made to it may not be used for the
 *    purpose of training or improving machine learning algorithms, including
 *    but not limited to artificial intelligence, natural language processing,
 *    or data mining. This condition applies to any derivatives, modifications,
 *    or updates based on the Software code. Any usage of the Software in an
 *    AI-training dataset is considered a breach of this License.
 *
 * 6. The Software may not be included in any dataset used for training or
 *    improving machine learning algorithms, including but not limited to
 *    artificial intelligence, natural language processing, or data mining.
 *
 * 7. You and your company, in adition to these conditions, also agree to use
 *    the Software by abiding the terms of the "Polyform Small Business
 *    License" (https://polyformproject.org/licenses/small-business/1.0.0/).
 *
 * 8. The above copyright notice and this permission notice shall be included
 *    in its entirety in all copies or substantial portions of the Software,
 *    credits screen or "about" page included.
 *
 * 9. Any person or organization found to be in violation of these restrictions
 *    will be subject to legal action and may be held liable for any damages
 *    resulting from such use.
 *
 * 10. This notice may not be removed or altered from any source distribution.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Author: Italo Felipe Capasso Ballesteros <italo@gp-mail.com>
 */

// The API order goes by the category classification expressed in the docs
// https://wiki.libsdl.org/SDL3/APIByCategory/

/**
 * ''The SDL3 Library Vala bindings.''
 *
 * Simple DirectMedia Layer is a cross-platform development library
 * designed to provide low level access to audio, keyboard, mouse,
 * joystick, and graphics hardware.
 *
 *  * ''C-Documentation reference: '' [[https://wiki.libsdl.org/SDL3/]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL.h")]
namespace SDL {}

///
/// BASICS
///

/**
 * Application entry points
 *
 * Redefines ``main ()`` if necessary so that it is called by SDL. In Vala, this
 * is done with creating custom entry points to handle manual main
 * initialization or addding custom callbacks.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryMain]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_main.h")]
namespace SDL.Main {
#if SDL_MAIN_USE_GLIB_PTR_ARRAY
    /**
     * An entry point for SDL's use in
     * [[https://wiki.libsdl.org/SDL3/SDL_MAIN_USE_CALLBACKS|SDL_MAIN_USE_CALLBACKS.]]
     *
     * This is the GLib version, which uses a Glib delegate variants that use a
     * {@link GLib.PtrArray} to carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EnterAppMainCallbacks]]
     *
     * @param args standard Unix main args.
     * @param app_init the application's {@link Init.AppInitFuncGLib} function.
     * @param app_iter the application's {@link Init.AppIterateFuncGLib} function.
     * @param app_event the application's {@link Init.AppEventFuncGLib} function.
     * @param app_quit the application's {@link Init.AppQuitFuncGLib} function.
     *
     * @return standard Unix main return value.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EnterAppMainCallbacks")]
    public static int enter_app_main_callbacks ([CCode (array_length_pos = 0.9)] string[] args,
            [CCode (delegate_target = false)] Init.AppInitFuncGLib app_init,
            [CCode (delegate_target = false)] Init.AppIterateFuncGLib app_iter,
            [CCode (delegate_target = false)] Init.AppEventFuncGLib app_event,
            [CCode (delegate_target = false)] Init.AppQuitFuncGLib app_quit);

#else
    /**
     * An entry point for SDL's use in
     * [[https://wiki.libsdl.org/SDL3/SDL_MAIN_USE_CALLBACKS|SDL_MAIN_USE_CALLBACKS.]]
     *
     * This is the Posix version, which uses Posix delegate variants, that use
     * a void pointer to carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EnterAppMainCallbacks]]
     *
     * @param args standard Unix main args.
     * @param app_init the application's {@link Init.AppInitFunc} function.
     * @param app_iter the application's {@link Init.AppIterateFunc} function.
     * @param app_event the application's {@link Init.AppEventFunc} function.
     * @param app_quit the application's {@link Init.AppQuitFunc} function.
     *
     * @return standard Unix main return value.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EnterAppMainCallbacks")]
    public static int enter_app_main_callbacks ([CCode (array_length_pos = 0.9)] string[] args,
            [CCode (delegate_target = false)] Init.AppInitFunc app_init,
            [CCode (delegate_target = false)] Init.AppIterateFunc app_iter,
            [CCode (delegate_target = false)] Init.AppEventFunc app_event,
            [CCode (delegate_target = false)] Init.AppQuitFunc app_quit);

#endif

    /**
     * Callback from the application to let the suspend continue.
     * This function is only needed for Xbox GDK support; all other platforms
     * will do nothing and set an "unsupported" error message.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GDKSuspendComplete]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GDKSuspendComplete")]
    public static void gdk_suspend_complete ();

    /**
     * Register a win32 window class for SDL's use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RegisterApp]]
     *
     * @param name the window class name, in UTF-8 encoding. If null, SDL
     * currently uses "SDL_app" but this isn't guaranteed.
     * @param style the value to use in ``WNDCLASSEX::style``.
     * @param h_inst the ``HINSTANCE`` to use in ``WNDCLASSEX::hInstance ``.
     * If zero, SDL will use ``GetModuleHandle (null)`` instead.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RegisterApp")]
    public static bool register_app (string? name, uint32 style, void* h_inst);

    /**
     * Initializes and launches an SDL application, by doing platform-specific
     * initialization before calling your mainFunction and cleanups after it
     * returns, if that is needed for a specific platform, otherwise it just
     * calls mainFunction.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RunApp]]
     *
     * @param args the args parameter from the application's main function,
     * or null, if the platform's main-equivalent has no args.
     * @param main_function your SDL app's ``main ()``. NOT the function you're
     * calling this from! Its name doesn't matter; it doesn't literally have to
     * be main.
     * @param reserved should be null (reserved for future use, will probably be
     * platform-specific then).
     *
     * @return the return value from {@link main_function}: 0 on success,
     * otherwise failure; {@link SDL.Error.get_error} might have more
     * information ont he failure.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RunApp")]
    public static int run_app ([CCode (array_length_pos = 0.9)] string[] args,
            MainFunc main_function,
            void* reserved);

    /**
     * Circumvent failure of {@link SDL.Init.init} when not using
     * [[https://wiki.libsdl.org/SDL3/SDL_main|SDL_Main ()]] as an entry point.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetMainReady]]
     *
     * @since 3.2.0
     *
     * @see SDL.Init.init
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetMainReady")]
    public static void set_main_ready ();

    /**
     * Deregister the win32 window class from an {@link Main.register_app} call.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RegisterApp]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_UnregisterApp")]
    public static void unregister_app ();

    /**
     * The prototype for the application's ``main ()`` function
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_main_func]]
     *
     * @param args an ANSI-C style main function's args.
     *
     * @return an ANSI-C main return code; generally 0 is considered successful
     * program completion, and small non-zero values are considered errors.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_main_func", has_target = false)]
    public delegate int MainFunc ([CCode (array_length_pos = 0.9)] string[] args);
} // SDL.Main

/**
 * Initialization and Shutdown
 *
 * All SDL programs need to initialize the library before starting to work with
 * it. Almost everything can simply call SDL_Init () near startup, with a handful
 * of flags to specify subsystems to touch. These are here to make sure SDL does
 * not even attempt to touch low-level pieces of the operating system that you
 * don't intend to use.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryInit]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_init.h")]
namespace SDL.Init {
    /**
     * Get metadata about your app.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAppMetadataProperty]]
     *
     * @param name the name of the metadata property to get.
     *
     * @return the current value of the metadata property, or the default if it
     * is not set, null for properties with no default.
     *
     * @since 3.2.0
     *
     * @see set_app_metadata
     * @see set_app_metadata_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAppMetadataProperty")]
    public static unowned string ? get_app_metadata_property (string name);

    /**
     * Initialize the SDL library.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Init]]
     *
     * @param flags subsystem initialization flags.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_app_metadata
     * @see set_app_metadata_property
     * @see init_subsystem
     * @see quit_subsystem
     * @see quit
     * @see Main.set_main_ready
     * @see was_init
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_Init", cheader_filename = "SDL3/SDL_main.h")]
    public static bool init (InitFlags flags);

    // HACK: Note that init does not belong in SDL3/SDL_main.h,
    // but doing this cheader_filename = "SDL3/SDL_main.h" hack will
    // force it to be included. And since you must always use init or
    // init_subsystem somewhere...

    /**
     * Compatibility function to initialize the SDL library.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_InitSubSystem]]
     *
     * @param flags any of the flags used by {@link Init.init}
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see init
     * @see quit
     * @see quit_subsystem
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_InitSubSystem", cheader_filename = "SDL3/SDL_main.h")]
    public static bool init_subsystem (InitFlags flags);

    // HACK: Note that init_subsystem does not belong in SDL_main,
    // but doing this hack will force it to be included.

    /**
     * Return whether this is the main thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IsMainThread]]
     *
     * @return true if this thread is the main thread, or false otherwise.
     *
     * @since 3.2.0
     *
     * @see run_on_main_thread
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_IsMainThread")]
    public static bool is_main_thread ();

    /**
     * Clean up all initialized subsystems.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Quit]]
     *
     * @since 3.2.0
     *
     * @see init
     * @see quit_subsystem
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_Quit")]
    public static void quit ();

    /**
     * Shut down specific SDL subsystems.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_QuitSubSystem]]
     *
     * @param flags any of the flags used by {@link Init.init}
     *
     * @since 3.2.0
     *
     * @see init_subsystem
     * @see quit
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_QuitSubSystem")]
    public static void quit_subsystem (InitFlags flags);

    /**
     * Call a function on the main thread during event processing.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RunOnMainThread]]
     *
     * @param callback the callback to call on the main thread.
     * @param wait_complete true to wait for the callback to complete, false
     * to return immediately.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see is_main_thread
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RunOnMainThread", has_target = true, instance_pos = 1)]
    public static bool run_on_main_thread (MainThreadCallback callback, bool wait_complete);

    /**
     * Specify basic metadata about your app.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadata]]
     *
     * @param app_name The name of the application ("My Game 2: Bad Guy's
     * Revenge!").
     * @param app_version The version of the application ("1.0.0beta5" or a git
     * hash, or whatever makes sense).
     * @param app_identifier A unique string in reverse-domain format that
     * identifies this app ("com.example.mygame2").
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_app_metadata_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetAppMetadata")]
    public static bool set_app_metadata (string? app_name, string? app_version,
            string? app_identifier);

    /**
     * Specify metadata about your app through a set of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
     *
     * @param name the name of the metadata property to set.
     * @param value the value of the property, or null to remove that property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_app_metadata_property
     * @see set_app_metadata
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetAppMetadataProperty")]
    public static bool set_app_metadata_property (string name, string? value);

    /**
     * Get a mask of the specified subsystems which are currently initialized.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WasInit]]
     *
     * @param flags any of the flags used by {@link Init.init}
     *
     * @return a mask of all initialized subsystems if flags is 0, otherwise it
     * returns the initialization status of the specified subsystems.
     *
     * @since 3.2.0
     *
     * @see init
     * @see init_subsystem
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WasInit")]
    public static InitFlags was_init (InitFlags flags);

#if SDL_MAIN_USE_GLIB_PTR_ARRAY
    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppEvent|SDL_AppEvent]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the GLib version, which uses a {@link GLib.PtrArray} to
     * carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppEvent_func]]
     *
     * @param app_state an optional pointer, provided by the app in
     * {@link AppInitFuncGLib}.
     * @param current_event the new event for the app to examine.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppInitFuncGLib
     * @see AppIterateFuncGLib
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppEvent_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppEventFuncGLib (GLib.PtrArray app_state,
            Events.Event current_event);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppInit|SDL_AppInit]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the GLib version, which uses a {@link GLib.PtrArray} to
     * carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppInit_func]]
     *
     * @param app_state a place where the app can optionally store a pointer
     * for future use.
     * @param args the standard ANSI C main's args.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppIterateFuncGLib
     * @see AppEventFuncGLib
     * @see AppQuitFuncGLib
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppInit_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppInitFuncGLib (out GLib.PtrArray app_state,
            [CCode (array_length_pos = 1.9)] string[] args);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppEvent|SDL_AppIterate]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the GLib version, which uses a {@link GLib.PtrArray} to
     * carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppIterate_func]]
     *
     * @param an optional pointer, provided by the app in
     * {@link AppInitFuncGLib}.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppInitFuncGLib
     * @see AppEventFuncGLib
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppIterate_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppIterateFuncGLib (GLib.PtrArray app_state);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppQuit|SDL_AppQuit]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the GLib version, which uses a {@link GLib.PtrArray} to
     * carry the app state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppQuit_func]]
     *
     * @param app_state an optional pointer, provided by the app in
     * {@link AppInitFuncGLib}.
     * @param result the result code that terminated the app (success or failure).
     *
     * @since 3.2.0
     *
     * @see AppInitFuncGLib
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppQuit_func", has_target = true, instance_pos = 0)]
    public delegate void AppQuitFuncGLib (GLib.PtrArray app_state, AppResult result);

#else
    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppEvent|SDL_AppEvent]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the Posix version, which uses a void* pointer to carry the app
     * state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppEvent_func]]
     *
     * @param app_state an optional pointer, provided by the app in
     * {@link AppInitFunc}.
     * @param current_event the new event for the app to examine.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppInitFunc
     * @see AppIterateFunc
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppEvent_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppEventFunc (void* app_state, Events.Event current_event);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppInit|SDL_AppInit]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the Posix version, which uses a void* pointer to carry the app
     * state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppInit_func]]
     *
     * @param app_state a place where the app can optionally store a pointer
     * for future use.
     * @param args the standard ANSI C main's args.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppIterateFunc
     * @see AppEventFunc
     * @see AppQuitFunc
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppInit_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppInitFunc (out void* app_state,
            [CCode (array_length_pos = 1.9)] string[] args);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppIterate|SDL_AppIterate]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the Posix version, which uses a void* pointer to carry the app
     * state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppIterate_func]]
     *
     * @param app_state an optional pointer, provided by the app in
     * {@link AppInitFunc}.
     *
     * @return Returns {@link AppResult.FAILURE} to terminate with an
     * error, {@link AppResult.SUCCESS} to terminate with success,
     * {@link AppResult.CONTINUE} to continue.
     *
     * @since 3.2.0
     *
     * @see AppInitFunc
     * @see AppEventFunc
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppIterate_func", has_target = false, has_type_id = false)]
    public delegate AppResult AppIterateFunc (void* app_state);

    /**
     * Function delegate for
     * [[https://wiki.libsdl.org/SDL3/SDL_AppQuit|SDL_AppQuit]]. Used in
     * {@link Main.enter_app_main_callbacks}.
     *
     * This is the Posix version, which uses a void* pointer to carry the app
     * state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppQuit_func]]
     *
     * @param app_state an optional pointer, provided by the app in
     * {@link AppInitFunc}.
     * @param result the result code that terminated the app (success or failure).
     *
     * @since 3.2.0
     *
     * @see AppInitFunc
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppQuit_func", has_target = false, instance_pos = 0)]
    public delegate void AppQuitFunc (void* app_state, Init.AppResult result);
#endif

    /**
     * Initialization flags for {@link init} and/or
     * {@link init_subsystem}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_InitFlags]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Flags, CCode (cname = "int", cprefix = "SDL_INIT_")]
    public enum InitFlags {
    /**
     * Audio subsystem. {@link InitFlags.AUDIO} implies
     * {@link InitFlags.EVENTS}.
     */
        AUDIO,

        /**
         * Video subsystem. {@link InitFlags.VIDEO} implies
         * {@link InitFlags.EVENTS}, should be initialized on the main thread.
         */
        VIDEO,

        /**
         * Audio JOYSTICK. {@link InitFlags.JOYSTICK} implies
         * {@link InitFlags.EVENTS}.
         */
        JOYSTICK,

        /**
         * Haptic systems.
         */
        HAPTIC,

        /**
         * Gamepad subsystem. {@link InitFlags.GAMEPAD} implies
         * {@link InitFlags.EVENTS}.
         */
        GAMEPAD,

        /**
         * Events subsystem.
         */
        EVENTS,

        /**
         * Sensors subsystem. {@link InitFlags.SENSOR} implies
         * {@link InitFlags.EVENTS}.
         */
        SENSOR,

        /**
         * Camera subsystem. {@link InitFlags.CAMERA} implies
         * {@link InitFlags.EVENTS}.
         */
        CAMERA
    } // InitFlags

    /**
     * Callback delegate run on the main thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MainThreadCallback]]
     *
     * @since 3.2.0
     *
     * @see run_on_main_thread
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MainThreadCallback", has_target = true)]
    public delegate AppResult MainThreadCallback ();

    /**
     * Return values for optional main callbacks.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AppResult]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AppResult", cprefix = "SDL_APP_", has_type_id = false)]
    public enum AppResult {
    /**
     * Value that requests that the app continue from the main callbacks.
     */
        CONTINUE,

        /**
         * Value that requests termination with success from the main callbacks.
         */
        SUCCESS,

        /**
         * Value that requests termination with error from the main callbacks.
         */
        FAILURE
    } // AppResult

    /**
     * App metadata properties for {@link set_app_metadata_property}
     *
     */
    namespace PropAppMetadata {
        /**
         * The human-readable name of the application, like "My Game 2: Bad Guy's
         * Revenge!". This will show up anywhere the OS shows the name of the
         * application separately from window titles, such as volume control
         * applets, etc. This defaults to "SDL Application".
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_NAME_STRING:")]
        public const string NAME_STRING;

        /**
         * The version of the app that is running; there are no rules on format,
         * so "1.0.3beta2" and "April 22nd, 2024" and a git hash are all valid
         * options. This has no default.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_VERSION_STRING")]
        public const string VERSION_STRING;

        /**
         * A unique string that identifies this app. This must be in
         * reverse-domain format, like "com.example.mygame2". This string is
         * used by desktop compositors to identify and group windows together,
         * as well as match applications with associated desktop settings and
         * icons. If you plan to package your application in a container such
         * as Flatpak, the app ID should match the name of your Flatpak
         * container as well. This has no default.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_IDENTIFIER_STRING")]
        public const string IDENTIFIER_STRING;

        /**
         * The human-readable name of the creator/developer/maker of this app,
         * like "MojoWorkshop, LLC"
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_CREATOR_STRING")]
        public const string CREATOR_STRING;

        /**
         * The human-readable copyright notice, like "Copyright (c) 2024
         * MojoWorkshop, LLC" or whatnot. Keep this to one line, don't paste a
         * copy of a whole software license in here. This has no default.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_COPYRIGHT_STRING")]
        public const string COPYRIGHT_STRING;

        /**
         * URL to the app on the web. Maybe a product page, or a storefront, or
         * even a GitHub repository, for user's further information This has no
         * default.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_URL_STRING")]
        public const string URL_STRING;

        /**
         * The type of application this is. Currently this string can be "game"
         * for a video game, "mediaplayer" for a media player, or generically
         * "application" if nothing else applies. Future versions of SDL might
         * add new types. This defaults to "application".
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_SetAppMetadataProperty]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_APP_METADATA_TYPE_STRING")]
        public const string TYPE_STRING;
    } // PropAppMetadata
} // SDL.Init

/**
 * Configuration Variables (SDL_hints.h)
 *
 * This module contains functions to set and get configuration hints, as well as
 * listing each of them alphabetically.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryHints]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_hints.h")]
namespace SDL.Hints {
    /**
     * Add a function to watch a particular hint.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AddHintCallback]]
     *
     * @param name the hint to watch.
     * @param callback An {@link HintCallback} function that will be called
     * when the hint value changes.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see remove_hint_callback
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AddHintCallback")]
    public static bool add_hint_callback (string name, HintCallback callback);

    /**
     * Get the value of a hint.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetHint]]
     *
     * @param name the hint to query.
     *
     * @return the string value of a hint or null if the hint isn't set.
     *
     * @since 3.2.0
     *
     * @see set_hint
     * @see set_hint_with_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetHint")]
    public static unowned string ? get_hint (string name);

    /**
     * Get the boolean value of a hint variable.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetHintBoolean]]
     *
     * @param name the name of the hint to get the boolean value from.
     * @param default_value the value to return if the hint does not exist.
     *
     * @return the boolean value of a hint or the provided default value if the
     * hint does not exist.
     *
     * @since 3.2.0
     *
     * @see get_hint
     * @see set_hint
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetHintBoolean")]
    public static bool get_hint_boolean (string name, bool default_value);

    /**
     * Remove a function watching a particular hint.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RemoveHintCallback]]
     *
     * @param name the hint being watched.
     * @param callback an {@link HintCallback} function that will be called
     * when the hint value changes.
     *
     * @since 3.2.0
     *
     * @see add_hint_callback
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RemoveHintCallback")]
    public static void remove_hint_callback (string name, HintCallback callback);

    /**
     * Reset a hint to the default value.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ResetHint]]
     *
     * @param name the hint to set.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_hint
     * @see reset_hints
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ResetHint")]
    public static bool reset_hint (string name);

    /**
     * Reset all hints to the default values.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ResetHints]]
     *
     * @since 3.2.0
     *
     * @see reset_hint
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ResetHints")]
    public static void reset_hints ();

    /**
     * Set a hint with normal priority.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetHint]]
     *
     * @param name the hint to set.
     * @param val the value of the hint variable.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_hint
     * @see set_hint
     * @see set_hint_with_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetHint")]
    public static bool set_hint (string name, string? val);

    /**
     * Set a hint with a specific priority.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetHintWithPriority]]
     *
     * @param name the hint to set.
     * @param val the value of the hint variable.
     * @param priority the {@link HintPriority} levle for the hint.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_hint
     * @see set_hint
     * @see set_hint_with_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetHintWithPriority")]
    public static bool set_hint_with_priority (string name, string? val, HintPriority priority);

    /**
     * A callback used to send notifications of hint value changes.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HintCallback]]
     *
     * @param name what was passed as name to {@link add_hint_callback}.
     * @param old_value the previous hint value.
     * @param new_value the new value hint is to be set to.
     *
     * @since 3.2.0
     *
     * @see add_hint_callback
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HintCallback", has_target = true, instance_pos = 0)]
    public delegate void HintCallback (string name, string? old_value, string? new_value);

    /**
     * An enumeration of hint priorities.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HintPriority]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HintPriority", cprefix = "SDL_HINT_", has_type_id = false)]
    public enum HintPriority {
    /**
     * Default priority
     *
     */
        DEFAULT,

        /**
         * Normal priority
         */
        NORMAL,

        /**
         * Override priority. Environment variables are considered to have
         * override priority.
         *
         */
        OVERRIDE
    } // HintPriority

    /**
     * Specify the behavior of Alt+Tab while the keyboard is grabbed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ALLOW_ALT_TAB_WHILE_GRABBED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ALLOW_ALT_TAB_WHILE_GRABBED")]
    public const string ALLOW_ALT_TAB_WHILE_GRABBED;

    /**
     * A variable to control whether the SDL activity is allowed to be
     * re-created.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY")]
    public const string ANDROID_ALLOW_RECREATE_ACTIVITY;

    /**
     * A variable to control whether the event loop will block itself when the
     * app is paused.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ANDROID_BLOCK_ON_PAUSE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ANDROID_BLOCK_ON_PAUSE")]
    public const string ANDROID_BLOCK_ON_PAUSE;

    /**
     * A variable to control whether low latency audio should be enabled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ANDROID_LOW_LATENCY_AUDIO]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ANDROID_LOW_LATENCY_AUDIO")]
    public const string ANDROID_LOW_LATENCY_AUDIO;

    /**
     * A variable to control whether we trap the Android back button to handle
     * it manually.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ANDROID_TRAP_BACK_BUTTON]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ANDROID_TRAP_BACK_BUTTON")]
    public const string ANDROID_TRAP_BACK_BUTTON;

    /**
     * A variable setting the app ID string.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_APP_ID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_APP_ID")]
    public const string APP_ID;

    /**
     * A variable setting the application name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_APP_NAME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_APP_NAME")]
    public const string APP_NAME;

    /**
     * A variable controlling whether controllers used with the Apple TV
     * generate UI events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS")]
    public const string APPLE_TV_CONTROLLER_UI_EVENTS;

    /**
     * A variable controlling whether the Apple TV remote's joystick axes will
     * automatically match the rotation of the remote.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_APPLE_TV_REMOTE_ALLOW_ROTATION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_APPLE_TV_REMOTE_ALLOW_ROTATION")]
    public const string APPLE_TV_REMOTE_ALLOW_ROTATION;

    /**
     * A variable controlling response to {@link SDL.Assert.assert} failures.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ASSERT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ASSERT")]
    public const string ASSERT;

    /**
     * Specify the default ALSA audio device name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE")]
    public const string AUDIO_ALSA_DEFAULT_DEVICE;

    /**
     * Specify the default ALSA audio playback device name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE")]
    public const string AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE;

    /**
     * Specify the default ALSA audio recording device name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE")]
    public const string AUDIO_ALSA_DEFAULT_RECORDING_DEVICE;

    /**
     * A variable controlling the audio category on iOS and macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_CATEGORY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_CATEGORY")]
    public const string AUDIO_CATEGORY;

    /**
     * A variable controlling the default audio channel count.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_CHANNELS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_CHANNELS")]
    public const string AUDIO_CHANNELS;

    /**
     * Specify an application icon name for an audio device.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DEVICE_APP_ICON_NAME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DEVICE_APP_ICON_NAME")]
    public const string AUDIO_DEVICE_APP_ICON_NAME;

    /**
     * Specify whether this audio device should do audio processing.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DEVICE_RAW_STREAM]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DEVICE_RAW_STREAM")]
    public const string AUDIO_DEVICE_RAW_STREAM;

    /**
     * A variable controlling device buffer size.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES")]
    public const string AUDIO_DEVICE_SAMPLE_FRAMES;

    /**
     * Specify an audio stream name for an audio device.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DEVICE_STREAM_NAME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DEVICE_STREAM_NAME")]
    public const string AUDIO_DEVICE_STREAM_NAME;

    /**
     * Specify an application role for an audio device.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DEVICE_STREAM_ROLE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DEVICE_STREAM_ROLE")]
    public const string AUDIO_DEVICE_STREAM_ROLE;

    /**
     * Specify the input file when recording audio using the disk audio driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DISK_INPUT_FILE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DISK_INPUT_FILE")]
    public const string AUDIO_DISK_INPUT_FILE;

    /**
     * Specify the output file when playing audio using the disk audio driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DISK_OUTPUT_FILE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DISK_OUTPUT_FILE")]
    public const string AUDIO_DISK_OUTPUT_FILE;

    /**
     * A variable controlling the audio rate when using the disk audio driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DISK_TIMESCALE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DISK_TIMESCALE")]
    public const string AUDIO_DISK_TIMESCALE;

    /**
     * A variable that specifies an audio backend to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DRIVER")]
    public const string AUDIO_DRIVER;

    /**
     * A variable controlling the audio rate when using the dummy audio driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_DUMMY_TIMESCALE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_DUMMY_TIMESCALE")]
    public const string AUDIO_DUMMY_TIMESCALE;

    /**
     * A variable controlling the default audio format.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_FORMAT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_FORMAT")]
    public const string AUDIO_FORMAT;

    /**
     * A variable controlling the default audio frequency.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_FREQUENCY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_FREQUENCY")]
    public const string AUDIO_FREQUENCY;

    /**
     * A variable that causes SDL to not ignore audio "monitors".
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUDIO_INCLUDE_MONITORS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUDIO_INCLUDE_MONITORS")]
    public const string AUDIO_INCLUDE_MONITORS;

    /**
     * A variable controlling whether SDL updates joystick state when getting
     * input events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUTO_UPDATE_JOYSTICKS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUTO_UPDATE_JOYSTICKS")]
    public const string AUTO_UPDATE_JOYSTICKS;

    /**
     * A variable controlling whether SDL updates sensor state when getting
     * input events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_AUTO_UPDATE_SENSORS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_AUTO_UPDATE_SENSORS")]
    public const string AUTO_UPDATE_SENSORS;

    /**
     * Prevent SDL from using version 4 of the bitmap header when saving BMPs.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_BMP_SAVE_LEGACY_FORMAT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_BMP_SAVE_LEGACY_FORMAT")]
    public const string BMP_SAVE_LEGACY_FORMAT;

    /**
     * A variable that decides what camera backend to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_CAMERA_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_CAMERA_DRIVER")]
    public const string CAMERA_DRIVER;

    /**
     * A variable that limits what CPU features are available.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_CPU_FEATURE_MASK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_CPU_FEATURE_MASK")]
    public const string CPU_FEATURE_MASK;

    /**
     * A variable controlling whether SDL logs some debug information.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_DEBUG_LOGGING]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_DEBUG_LOGGING")]
    public const string DEBUG_LOGGING;

    /**
     * Override for {@link SDL.Video.get_display_usable_bounds}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_DISPLAY_USABLE_BOUNDS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_DISPLAY_USABLE_BOUNDS")]
    public const string DISPLAY_USABLE_BOUNDS;

    /**
     * Specify the EGL library to load.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EGL_LIBRARY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_EGL_LIBRARY")]
    public const string EGL_LIBRARY;

    /**
     * Disable giving back control to the browser automatically when running
     * with asyncify.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EMSCRIPTEN_ASYNCIFY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_EMSCRIPTEN_ASYNCIFY")]
    public const string EMSCRIPTEN_ASYNCIFY;

    /**
     * Specify the CSS selector used for the "default" window/canvas.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EMSCRIPTEN_CANVAS_SELECTOR]]
     *
     */
    [CCode (cname = "SDL_HINT_EMSCRIPTEN_CANVAS_SELECTOR")]
    public const string EMSCRIPTEN_CANVAS_SELECTOR;

    /**
     * Dictate that windows on Emscripten will fill the whole browser window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EMSCRIPTEN_FILL_DOCUMENT]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_EMSCRIPTEN_FILL_DOCUMENT")]
    public const string EMSCRIPTEN_FILL_DOCUMENT;

    /**
     * Override the binding element for keyboard inputs for Emscripten builds.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT")]
    public const string EMSCRIPTEN_KEYBOARD_ELEMENT;

    /**
     * A variable that controls whether the on-screen keyboard should be shown
     * when text input is active.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ENABLE_SCREEN_KEYBOARD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ENABLE_SCREEN_KEYBOARD")]
    public const string ENABLE_SCREEN_KEYBOARD;

    /**
     * A variable containing a list of evdev devices to use if udev is not
     * available.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EVDEV_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_EVDEV_DEVICES")]
    public const string EVDEV_DEVICES;

    /**
     * A variable controlling verbosity of the logging of SDL events pushed onto
     * the internal queue.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_EVENT_LOGGING]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_EVENT_LOGGING")]
    public const string EVENT_LOGGING;

    /**
     * A variable that specifies a dialog backend to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_FILE_DIALOG_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_FILE_DIALOG_DRIVER")]
    public const string FILE_DIALOG_DRIVER;

    /**
     * A variable controlling whether raising the window should be done more
     * forcefully.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_FORCE_RAISEWINDOW]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_FORCE_RAISEWINDOW")]
    public const string FORCE_RAISEWINDOW;

    /**
     * A variable controlling how 3D acceleration is used to accelerate the SDL
     * screen surface.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_FRAMEBUFFER_ACCELERATION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_FRAMEBUFFER_ACCELERATION")]
    public const string FRAMEBUFFER_ACCELERATION;

    /**
     * A variable containing a list of devices to skip when scanning for game
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES")]
    public const string GAMECONTROLLER_IGNORE_DEVICES;

    /**
     * If set, all devices will be skipped when scanning for game controllers
     * except for the ones listed in this variable.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT")]
    public const string GAMECONTROLLER_IGNORE_DEVICES_EXCEPT;

    /**
     * A variable that controls whether the device's built-in accelerometer and
     * gyro should be used as sensors for gamepads.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLER_SENSOR_FUSION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLER_SENSOR_FUSION")]
    public const string GAMECONTROLLER_SENSOR_FUSION;

    /**
     * A variable that lets you manually hint extra gamecontroller db entries.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLERCONFIG]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLERCONFIG")]
    public const string GAMECONTROLLERCONFIG;

    /**
     * A variable that lets you provide a file with extra gamecontroller db
     * entries.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLERCONFIG_FILE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLERCONFIG_FILE")]
    public const string GAMECONTROLLERCONFIG_FILE;

    /**
     * A variable that overrides the automatic controller type detection.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLERTYPE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GAMECONTROLLERTYPE")]
    public const string GAMECONTROLLERTYPE;

    /**
     * This variable sets the default text of the TextInput window on GDK
     * platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT")]
    public const string GDK_TEXTINPUT_DEFAULT_TEXT;

    /**
     * This variable sets the description of the TextInput window on GDK
     * platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GDK_TEXTINPUT_DESCRIPTION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GDK_TEXTINPUT_DESCRIPTION")]
    public const string GDK_TEXTINPUT_DESCRIPTION;

    /**
     * This variable sets the maximum input length of the TextInput window on
     * GDK platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GDK_TEXTINPUT_MAX_LENGTH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GDK_TEXTINPUT_MAX_LENGTH")]
    public const string GDK_TEXTINPUT_MAX_LENGTH;

    /**
     * This variable sets the input scope of the TextInput window on GDK
     * platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GDK_TEXTINPUT_SCOPE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GDK_TEXTINPUT_SCOPE")]
    public const string GDK_TEXTINPUT_SCOPE;

    /**
     * This variable sets the title of the TextInput window on GDK platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GDK_TEXTINPUT_TITLE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GDK_TEXTINPUT_TITLE")]
    public const string GDK_TEXTINPUT_TITLE;

    /**
     * A variable that specifies a GPU backend to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_GPU_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_GPU_DRIVER")]
    public const string GPU_DRIVER;

    /**
     * A variable to control whether {@link SDL.HidApi.hid_enumerate} enumerates
     * all HID devices or only controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS")]
    public const string HIDAPI_ENUMERATE_ONLY_CONTROLLERS;

    /**
     * A variable containing a list of devices to ignore in
     * {@link SDL.HidApi.hid_enumerate}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_IGNORE_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_IGNORE_DEVICES")]
    public const string HIDAPI_IGNORE_DEVICES;

    /**
     * A variable to control whether HIDAPI uses libusb for device access.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_LIBUSB]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_LIBUSB")]
    public const string HIDAPI_LIBUSB;

    /**
     * A variable to control whether HIDAPI uses libusb for GameCube adapters.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_LIBUSB_GAMECUBE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_LIBUSB_GAMECUBE")]
    public const string HIDAPI_LIBUSB_GAMECUBE;

    /**
     * A variable to control whether HIDAPI uses libusb only for whitelisted
     * devices.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_LIBUSB_WHITELIST]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_LIBUSB_WHITELIST")]
    public const string HIDAPI_LIBUSB_WHITELIST;

    /**
     * A variable to control whether HIDAPI uses udev for device detection.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_HIDAPI_UDEV]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_HIDAPI_UDEV")]
    public const string HIDAPI_UDEV;

    /**
     * A variable describing what IME UI elements the application can display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_IME_IMPLEMENTED_UI]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_IME_IMPLEMENTED_UI")]
    public const string IME_IMPLEMENTED_UI;

    /**
     * Set the level of checking for invalid parameters passed to SDL functions.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_INVALID_PARAM_CHECKS]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_INVALID_PARAM_CHECKS")]
    public const string INVALID_PARAM_CHECKS;

    /**
     * A variable controlling whether the home indicator bar on iPhone X and
     * later should be hidden.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_IOS_HIDE_HOME_INDICATOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_IOS_HIDE_HOME_INDICATOR")]
    public const string IOS_HIDE_HOME_INDICATOR;

    /**
     * A variable that lets you enable joystick (and gamecontroller) events even
     * when your app is in the background.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS")]
    public const string JOYSTICK_ALLOW_BACKGROUND_EVENTS;

    /**
     * A variable containing a list of arcade stick style controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES")]
    public const string JOYSTICK_ARCADESTICK_DEVICES;

    /**
     * A variable containing a list of devices that are not arcade stick style
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED")]
    public const string JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED;

    /**
     * A variable containing a list of devices that should not be considered
     * joysticks.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_BLACKLIST_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_BLACKLIST_DEVICES")]
    public const string JOYSTICK_BLACKLIST_DEVICES;

    /**
     * A variable containing a list of devices that should be considered
     * joysticks.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED")]
    public const string JOYSTICK_BLACKLIST_DEVICES_EXCLUDED;

    /**
     * A variable containing a comma separated list of devices to open as
     * joysticks.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_DEVICE")]
    public const string JOYSTICK_DEVICE;

    /**
     * A variable controlling whether DirectInput should be used for
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_DIRECTINPUT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_DIRECTINPUT")]
    public const string JOYSTICK_DIRECTINPUT;

    /**
     * A variable controlling whether enhanced reports should be used for
     * controllers when using the HIDAPI driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ENHANCED_REPORTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ENHANCED_REPORTS")]
    public const string JOYSTICK_ENHANCED_REPORTS;

    /**
     * A variable containing a list of flightstick style controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES")]
    public const string JOYSTICK_FLIGHTSTICK_DEVICES;

    /**
     * A variable containing a list of devices that are not flightstick style
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED")]
    public const string JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED;

    /**
     * A variable containing a list of devices known to have a GameCube form
     * factor.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_GAMECUBE_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_GAMECUBE_DEVICES")]
    public const string JOYSTICK_GAMECUBE_DEVICES;

    /**
     * A variable containing a list of devices known not to have a GameCube
     * form factor.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_GAMECUBE_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_GAMECUBE_DEVICES_EXCLUDED")]
    public const string JOYSTICK_GAMECUBE_DEVICES_EXCLUDED;

    /**
     * A variable controlling whether GameInput should be used for controller
     * handling on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_GAMEINPUT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_GAMEINPUT")]
    public const string JOYSTICK_GAMEINPUT;

    /**
     * A variable controlling whether GameInput should be used for handling GIP
     * devices that require raw report processing, but aren't supported
     * by HIDRAW, such as Xbox One Guitars.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_GAMEINPUT_RAW]]
     *
     * @since 3.4.4
     */
    [Version (since = "3.4.4")]
    [CCode (cname = "SDL_HINT_JOYSTICK_GAMEINPUT_RAW")]
    public const string JOYSTICK_GAMEINPUT_RAW;

    /**
     * A variable containing a list of devices and their desired number of
     * haptic (force feedback) enabled axis.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HAPTIC_AXES]]
     *
     * @since 3.2.5
     */
    [Version (since = "3.2.5")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HAPTIC_AXES")]
    public const string SDL_HINT_JOYSTICK_HAPTIC_AXES;

    /**
     * A variable controlling whether the HIDAPI joystick drivers should be
     * used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI")]
    public const string JOYSTICK_HIDAPI;

    /**
     * A variable controlling whether the HIDAPI driver for 8BitDo controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_8BITDO]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_8BITDO")]
    public const string JOYSTICK_HIDAPI_8BITDO;

    /**
     * A variable controlling whether Nintendo Switch Joy-Con controllers will
     * be combined into a single Pro-like controller when using the HIDAPI
     * driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS")]
    public const string JOYSTICK_HIDAPI_COMBINE_JOY_CONS;

    /**
     * A variable controlling whether the HIDAPI driver for Flydigi controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_FLYDIGI]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_FLYDIGI")]
    public const string JOYSTICK_HIDAPI_FLYDIGI;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo GameCube
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE")]
    public const string JOYSTICK_HIDAPI_GAMECUBE;

    /**
     * A variable controlling whether rumble is used to implement the GameCube
     * controller's 3 rumble modes, Stop (0), Rumble (1), and StopHard (2).
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE")]
    public const string JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE;

    /**
     * A variable controlling whether the new HIDAPI driver for wired Xbox One
     * (GIP) controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_GIP]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_GIP")]
    public const string JOYSTICK_HIDAPI_GIP;

    /**
     * A variable controlling whether the new HIDAPI driver for wired Xbox One
     * (GIP) controllers should reset the controller if it can't get the
     * metadata from the controller.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA")]
    public const string JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo Switch
     * Joy-Cons should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_JOY_CONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_JOY_CONS")]
    public const string JOYSTICK_HIDAPI_JOY_CONS;

    /**
     * A variable controlling whether the Home button LED should be turned on
     * when a Nintendo Switch Joy-Con controller is opened.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_JOYCON_HOME_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_JOYCON_HOME_LED")]
    public const string JOYSTICK_HIDAPI_JOYCON_HOME_LED;

    /**
     * A variable controlling whether the HIDAPI driver for some Logitech wheels
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_LG4FF]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_LG4FF")]
    public const string JOYSTICK_HIDAPI_LG4FF;

    /**
     * A variable controlling whether the HIDAPI driver for Amazon Luna
     * controllers connected via Bluetooth should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_LUNA]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_LUNA")]
    public const string JOYSTICK_HIDAPI_LUNA;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo Online
     * classic controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_NINTENDO_CLASSIC]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_NINTENDO_CLASSIC")]
    public const string JOYSTICK_HIDAPI_NINTENDO_CLASSIC;

    /**
     * A variable controlling whether the HIDAPI driver for PS3 controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS3]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS3")]
    public const string JOYSTICK_HIDAPI_PS3;

    /**
     * A variable controlling whether the Sony driver (sixaxis.sys) for PS3
     * controllers (Sixaxis/DualShock 3) should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER")]
    public const string JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER;

    /**
     * A variable controlling whether the HIDAPI driver for PS4 controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS4]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS4")]
    public const string JOYSTICK_HIDAPI_PS4;

    /**
     * A variable controlling the update rate of the PS4 controller over
     * Bluetooth when using the HIDAPI driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL")]
    public const string JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL;

    /**
     * A variable controlling whether the HIDAPI driver for PS5 controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS5]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS5")]
    public const string JOYSTICK_HIDAPI_PS5;

    /**
     * A variable controlling whether the player LEDs should be lit to indicate
     * which player is associated with a PS5 controller.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_PS5_PLAYER_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_PS5_PLAYER_LED")]
    public const string JOYSTICK_HIDAPI_PS5_PLAYER_LED;

    /**
     * A variable controlling whether the HIDAPI driver for NVIDIA SHIELD
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SHIELD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SHIELD")]
    public const string JOYSTICK_HIDAPI_SHIELD;

    /**
     * A variable controlling whether the HIDAPI driver for SInput controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SINPUT]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SINPUT")]
    public const string JOYSTICK_HIDAPI_SINPUT;

    /**
     * A variable controlling whether the HIDAPI driver for Google Stadia
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_STADIA]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_STADIA")]
    public const string JOYSTICK_HIDAPI_STADIA;

    /**
     * A variable controlling whether the HIDAPI driver for Bluetooth Steam
     * Controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_STEAM]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_STEAM")]
    public const string JOYSTICK_HIDAPI_STEAM;

    /**
     * A variable controlling whether the Steam button LED should be turned on
     * when a Steam controller is opened.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_STEAM_HOME_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_STEAM_HOME_LED")]
    public const string JOYSTICK_HIDAPI_STEAM_HOME_LED;

    /**
     * A variable controlling whether the HIDAPI driver for HORI licensed Steam
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_STEAM_HORI]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_STEAM_HORI")]
    public const string JOYSTICK_HIDAPI_STEAM_HORI;

    /**
     * A variable controlling whether the HIDAPI driver for the Steam Deck
     * builtin controller should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK")]
    public const string JOYSTICK_HIDAPI_STEAMDECK;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo Switch
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SWITCH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SWITCH")]
    public const string JOYSTICK_HIDAPI_SWITCH;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo Switch 2
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SWITCH2]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SWITCH2")]
    public const string JOYSTICK_HIDAPI_SWITCH2;

    /**
     * A variable controlling whether the Home button LED should be turned on
     * when a Nintendo Switch Pro controller is opened.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SWITCH_HOME_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SWITCH_HOME_LED")]
    public const string JOYSTICK_HIDAPI_SWITCH_HOME_LED;

    /**
     * A variable controlling whether the player LEDs should be lit to indicate
     * which player is associated with a Nintendo Switch controller.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED")]
    public const string JOYSTICK_HIDAPI_SWITCH_PLAYER_LED;

    /**
     * A variable controlling whether Nintendo Switch Joy-Con controllers will
     * be in vertical mode when using the HIDAPI driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS")]
    public const string JOYSTICK_HIDAPI_VERTICAL_JOY_CONS;

    /**
     * A variable controlling whether the HIDAPI driver for Nintendo Wii and
     * Wii U controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_WII]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_WII")]
    public const string JOYSTICK_HIDAPI_WII;

    /**
     * A variable controlling whether the player LEDs should be lit to indicate
     * which player is associated with a Wii controller.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_WII_PLAYER_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_WII_PLAYER_LED")]
    public const string JOYSTICK_HIDAPI_WII_PLAYER_LED;

    /**
     * A variable controlling whether the HIDAPI driver for XBox controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX")]
    public const string JOYSTICK_HIDAPI_XBOX;

    /**
     * A variable controlling whether the HIDAPI driver for XBox 360 controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_360]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX_360")]
    public const string JOYSTICK_HIDAPI_XBOX_360;

    /**
     * A variable controlling whether the player LEDs should be lit to indicate
     * which player is associated with an Xbox 360 controller.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED")]
    public const string JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED;

    /**
     * A variable controlling whether the HIDAPI driver for XBox 360 wireless
     * controllers should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_WIRELESS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_WIRELESS")]
    public const string JOYSTICK_HIDAPI_XBOX_360_WIRELESS;

    /**
     * A variable controlling whether the HIDAPI driver for XBox One controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE")]
    public const string JOYSTICK_HIDAPI_XBOX_ONE;

    /**
     * A variable controlling whether the Home button LED should be turned on
     * when an Xbox One controller is opened.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED")]
    public const string JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED;

    /**
     * A variable controlling whether the HIDAPI driver for ZUIKI controllers
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_ZUIKI]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_HIDAPI_ZUIKI")]
    public const string JOYSTICK_HIDAPI_ZUIKI;

    /**
     * A variable controlling whether IOKit should be used for controller
     * handling.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_IOKIT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_IOKIT")]
    public const string JOYSTICK_IOKIT;

    /**
     * A variable controlling whether to use the classic /dev/input/js* joystick
     * interface or the newer /dev/input/event* joystick interface on Linux.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_LINUX_CLASSIC]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_LINUX_CLASSIC")]
    public const string JOYSTICK_LINUX_CLASSIC;

    /**
     * A variable controlling whether joysticks on Linux adhere to their
     * HID-defined deadzones or return unfiltered values.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_LINUX_DEADZONES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_LINUX_DEADZONES")]
    public const string JOYSTICK_LINUX_DEADZONES;

    /**
     * A variable controlling whether joysticks on Linux will always treat 'hat'
     * axis inputs (ABS_HAT0X - ABS_HAT3Y) as 8-way digital hats without
     * checking whether they may be analog.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_LINUX_DIGITAL_HATS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_LINUX_DIGITAL_HATS")]
    public const string JOYSTICK_LINUX_DIGITAL_HATS;

    /**
     * A variable controlling whether digital hats on Linux will apply deadzones
     * to their underlying input axes or use unfiltered values.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_LINUX_HAT_DEADZONES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_LINUX_HAT_DEADZONES")]
    public const string JOYSTICK_LINUX_HAT_DEADZONES;

    /**
     * A variable controlling whether GCController should be used for controller
     * handling.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_MFI]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_MFI")]
    public const string JOYSTICK_MFI;

    /**
     * A variable controlling whether the RAWINPUT joystick drivers should be
     * used for better handling XInput-capable devices.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_RAWINPUT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_RAWINPUT")]
    public const string JOYSTICK_RAWINPUT;

    /**
     * A variable controlling whether the RAWINPUT driver should pull correlated
     * data from XInput.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_RAWINPUT_CORRELATE_XINPUT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_RAWINPUT_CORRELATE_XINPUT")]
    public const string JOYSTICK_RAWINPUT_CORRELATE_XINPUT;

    /**
     * A variable controlling whether the ROG Chakram mice should show up as
     * joysticks.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ROG_CHAKRAM]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ROG_CHAKRAM")]
    public const string JOYSTICK_ROG_CHAKRAM;

    /**
     * A variable controlling whether a separate thread should be used for
     * handling joystick detection and raw input messages on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_THREAD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_THREAD")]
    public const string JOYSTICK_THREAD;

    /**
     * A variable containing a list of throttle style controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_THROTTLE_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_THROTTLE_DEVICES")]
    public const string JOYSTICK_THROTTLE_DEVICES;

    /**
     * A variable containing a list of devices that are not throttle style
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_THROTTLE_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_THROTTLE_DEVICES_EXCLUDED")]
    public const string JOYSTICK_THROTTLE_DEVICES_EXCLUDED;

    /**
     * A variable controlling whether Windows.Gaming.Input should be used for
     * controller handling.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_WGI]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_WGI")]
    public const string JOYSTICK_WGI;

    /**
     * A variable containing a list of wheel style controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_WHEEL_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_WHEEL_DEVICES")]
    public const string JOYSTICK_WHEEL_DEVICES;

    /**
     * A variable containing a list of devices that are not wheel style
     * controllers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_WHEEL_DEVICES_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_WHEEL_DEVICES_EXCLUDED")]
    public const string JOYSTICK_WHEEL_DEVICES_EXCLUDED;

    /**
     * A variable containing a list of devices known to have all axes centered
     * at zero.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_ZERO_CENTERED_DEVICES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_JOYSTICK_ZERO_CENTERED_DEVICES")]
    public const string JOYSTICK_ZERO_CENTERED_DEVICES;

    /**
     * A variable that controls keycode representation in keyboard events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_KEYCODE_OPTIONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_KEYCODE_OPTIONS")]
    public const string KEYCODE_OPTIONS;

    /**
     * A variable that controls whether KMSDRM will use "atomic" functionality.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_KMSDRM_ATOMIC]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_KMSDRM_ATOMIC")]
    public const string KMSDRM_ATOMIC;

    /**
     * A variable that controls what KMSDRM device to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_KMSDRM_DEVICE_INDEX]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_KMSDRM_DEVICE_INDEX")]
    public const string KMSDRM_DEVICE_INDEX;

    /**
     * A variable that controls whether SDL requires DRM master access in order
     * to initialize the KMSDRM video backend.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER")]
    public const string KMSDRM_REQUIRE_DRM_MASTER;

    /**
     * A variable controlling whether SDL backend information is logged.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_LOG_BACKENDS]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_LOG_BACKENDS")]
    public const string LOG_BACKENDS;

    /**
     * A variable controlling the default SDL log levels.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_LOGGING]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_LOGGING")]
    public const string LOGGING;

    /**
     * A variable controlling whether to force the application to become the
     * foreground process when launched on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_BACKGROUND_APP]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAC_BACKGROUND_APP")]
    public const string MAC_BACKGROUND_APP;

    /**
     * A variable that determines whether Ctrl+Click should generate a
     * right-click event on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK")]
    public const string MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK;

    /**
     * A variable controlling whether dispatching OpenGL context updates should
     * block the dispatching thread until the main thread finishes processing
     * on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_OPENGL_ASYNC_DISPATCH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAC_OPENGL_ASYNC_DISPATCH")]
    public const string MAC_OPENGL_ASYNC_DISPATCH;

    /**
     * A variable controlling whether the Option key on macOS should be remapped
     * to act as the Alt key.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_OPTION_AS_ALT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAC_OPTION_AS_ALT")]
    public const string MAC_OPTION_AS_ALT;

    /**
     * A variable controlling whether holding down a key will repeat the pressed
     * key or open the accents menu on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_PRESS_AND_HOLD]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_MAC_PRESS_AND_HOLD")]
    public const string MAC_PRESS_AND_HOLD;

    /**
     * A variable controlling whether {@link SDL.Events.EventType.MOUSE_WHEEL}
     * event values will have momentum on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAC_SCROLL_MOMENTUM]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAC_SCROLL_MOMENTUM")]
    public const string MAC_SCROLL_MOMENTUM;

#if SDL_MAIN_USE_GLIB_PTR_ARRAY
    /**
     * Request {@link Init.AppIterateFuncGLib} to be called at a specific
     * rate.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAIN_CALLBACK_RATE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAIN_CALLBACK_RATE")]
    public const string MAIN_CALLBACK_RATE;
#else
    /**
     * Request {@link Init.AppIterateFunc} to be called at a specific
     * rate.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MAIN_CALLBACK_RATE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MAIN_CALLBACK_RATE")]
    public const string MAIN_CALLBACK_RATE;
#endif

    /**
     * A variable controlling whether the mouse is captured while mouse buttons
     * are pressed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_AUTO_CAPTURE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_AUTO_CAPTURE")]
    public const string MOUSE_AUTO_CAPTURE;

    /**
     * A variable setting which system cursor to use as the default cursor.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR")]
    public const string MOUSE_DEFAULT_SYSTEM_CURSOR;

    /**
     * A variable setting the double click radius, in pixels.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_DOUBLE_CLICK_RADIUS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_DOUBLE_CLICK_RADIUS")]
    public const string MOUSE_DOUBLE_CLICK_RADIUS;

    /**
     * A variable setting the double click time, in milliseconds.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_DOUBLE_CLICK_TIME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_DOUBLE_CLICK_TIME")]
    public const string MOUSE_DOUBLE_CLICK_TIME;

    /**
     * A variable setting whether we should scale cursors by the current display scale.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_DPI_SCALE_CURSORS]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_MOUSE_DPI_SCALE_CURSORS")]
    public const string MOUSE_DPI_SCALE_CURSORS;

    /**
     * A variable controlling whether warping a hidden mouse cursor will
     * activate relative mouse mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_EMULATE_WARP_WITH_RELATIVE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_EMULATE_WARP_WITH_RELATIVE")]
    public const string MOUSE_EMULATE_WARP_WITH_RELATIVE;

    /**
     * Allow mouse click events when clicking to focus an SDL window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH")]
    public const string MOUSE_FOCUS_CLICKTHROUGH;

    /**
     * A variable setting the speed scale for mouse motion, in floating point,
     * when the mouse is not in relative mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_NORMAL_SPEED_SCALE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_NORMAL_SPEED_SCALE")]
    public const string MOUSE_NORMAL_SPEED_SCALE;

    /**
     * A variable controlling whether the hardware cursor stays visible when
     * relative mode is active.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_RELATIVE_CURSOR_VISIBLE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_RELATIVE_CURSOR_VISIBLE")]
    public const string MOUSE_RELATIVE_CURSOR_VISIBLE;

    /**
     * A variable controlling whether relative mouse mode constrains the mouse
     * to the center of the window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_RELATIVE_MODE_CENTER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_RELATIVE_MODE_CENTER")]
    public const string MOUSE_RELATIVE_MODE_CENTER;

    /**
     * A variable setting the scale for mouse motion, in floating point, when
     * the mouse is in relative mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE")]
    public const string MOUSE_RELATIVE_SPEED_SCALE;

    /**
     * A variable controlling whether the system mouse acceleration curve is
     * used for relative mouse motion.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE")]
    public const string MOUSE_RELATIVE_SYSTEM_SCALE;

    /**
     * A variable controlling whether a motion event should be generated for
     * mouse warping in relative mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_RELATIVE_WARP_MOTION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_RELATIVE_WARP_MOTION")]
    public const string MOUSE_RELATIVE_WARP_MOTION;

    /**
     * A variable controlling whether mouse events should generate synthetic
     * touch events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MOUSE_TOUCH_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MOUSE_TOUCH_EVENTS")]
    public const string MOUSE_TOUCH_EVENTS;

    /**
     * A variable controlling whether the keyboard should be muted on the
     * console.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_MUTE_CONSOLE_KEYBOARD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_MUTE_CONSOLE_KEYBOARD")]
    public const string MUTE_CONSOLE_KEYBOARD;

    /**
     * Tell SDL not to catch the SIGINT or SIGTERM signals on POSIX platforms.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_NO_SIGNAL_HANDLERS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_NO_SIGNAL_HANDLERS")]
    public const string NO_SIGNAL_HANDLERS;

    /**
     * A variable controlling what driver to use for OpenGL ES contexts.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_OPENGL_ES_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_OPENGL_ES_DRIVER")]
    public const string OPENGL_ES_DRIVER;

    /**
     * A variable controlling whether to force an sRGB-capable OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_OPENGL_FORCE_SRGB_CAPABLE]]
     *
     * @since 3.4.2
     */
    [Version (since = "3.4.2")]
    [CCode (cname = "SDL_HINT_OPENGL_FORCE_SRGB_CAPABLE")]
    public const string OPENGL_FORCE_SRGB_CAPABLE;

    /**
     * A variable controlling whether to force an sRGB-capable OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_OPENGL_FORCE_SRGB_FRAMEBUFFER]]
     *
     * @since 3.4.2
     */
    [Version (since = "3.4.2")]
    [CCode (cname = "SDL_HINT_OPENGL_FORCE_SRGB_FRAMEBUFFER")]
    public const string OPENGL_FORCE_SRGB_FRAMEBUFFER;

    /**
     * Specify the OpenGL library to load.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_OPENGL_LIBRARY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_OPENGL_LIBRARY")]
    public const string OPENGL_LIBRARY;

    /**
     * Mechanism to specify openvr_api library location
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_OPENVR_LIBRARY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_OPENVR_LIBRARY")]
    public const string OPENVR_LIBRARY;

    /**
     * A variable controlling which orientations are allowed on iOS/Android.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ORIENTATIONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ORIENTATIONS")]
    public const string ORIENTATIONS;

    /**
     * A variable controlling whether pen events should generate synthetic mouse
     * events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PEN_MOUSE_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_PEN_MOUSE_EVENTS")]
    public const string PEN_MOUSE_EVENTS;

    /**
     * A variable controlling whether pen events should generate synthetic touch
     * events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PEN_TOUCH_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_PEN_TOUCH_EVENTS")]
    public const string PEN_TOUCH_EVENTS;

    /**
     * A variable controlling the use of a sentinel event when polling the event
     * queue.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_POLL_SENTINEL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_POLL_SENTINEL")]
    public const string POLL_SENTINEL;

    /**
     * Override for {@link SDL.Locale.get_preferred_locales}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PREFERRED_LOCALES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_PREFERRED_LOCALES")]
    public const string PREFERRED_LOCALES;

    /**
     * Variable controlling the height of the PS2's framebuffer in pixels
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PS2_GS_HEIGHT]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_PS2_GS_HEIGHT")]
    public const string PS2_GS_HEIGHT;

    /**
     * Variable controlling the height of the PS2's framebuffer in pixels
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PS2_GS_MODE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_PS2_GS_MODE")]
    public const string PS2_GS_MODE;

    /**
     * Variable controlling whether the signal is interlaced or progressive
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PS2_GS_PROGRESSIVE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_PS2_GS_PROGRESSIVE")]
    public const string PS2_GS_PROGRESSIVE;

    /**
     * Variable controlling the width of the PS2's framebuffer in pixels
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_PS2_GS_WIDTH]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_PS2_GS_WIDTH")]
    public const string PS2_GS_WIDTH;

    /**
     * A variable that decides whether to send {@link SDL.Events.EventType.QUIT}
     * when closing the last window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE")]
    public const string QUIT_ON_LAST_WINDOW_CLOSE;

    /**
     * A variable controlling whether to enable Direct3D 11+'s Debug Layer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_DIRECT3D11_DEBUG]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_DIRECT3D11_DEBUG")]
    public const string RENDER_DIRECT3D11_DEBUG;

    /**
     * A variable controlling whether to use the Direct3D 11 WARP software
     * rasterizer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_DIRECT3D11_WARP]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_RENDER_DIRECT3D11_WARP")]
    public const string RENDER_DIRECT3D11_WARP;

    /**
     * A variable controlling whether the Direct3D device is initialized for
     * thread-safe operations.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_DIRECT3D_THREADSAFE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_DIRECT3D_THREADSAFE")]
    public const string RENDER_DIRECT3D_THREADSAFE;

    /**
     * A variable specifying which render driver to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_DRIVER")]
    public const string RENDER_DRIVER;

    /**
     * A variable controlling whether to create the GPU device in debug mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_GPU_DEBUG]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_GPU_DEBUG")]
    public const string RENDER_GPU_DEBUG;

    /**
     * A variable controlling whether to prefer a low-power GPU on multi-GPU
     * systems.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_GPU_LOW_POWER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_GPU_LOW_POWER")]
    public const string RENDER_GPU_LOW_POWER;

    /**
     * A variable controlling how the 2D render API renders lines.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_LINE_METHOD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_LINE_METHOD")]
    public const string RENDER_LINE_METHOD;

    /**
     * A variable controlling whether the Metal render driver select low power
     * device over default one.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_METAL_PREFER_LOW_POWER_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_METAL_PREFER_LOW_POWER_DEVICE")]
    public const string RENDER_METAL_PREFER_LOW_POWER_DEVICE;

    /**
     * A variable controlling whether updates to the SDL screen surface should
     * be synchronized with the vertical refresh, to avoid tearing.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_VSYNC]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_VSYNC")]
    public const string RENDER_VSYNC;

    /**
     * A variable controlling whether to enable Vulkan Validation Layers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RENDER_VULKAN_DEBUG]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RENDER_VULKAN_DEBUG")]
    public const string RENDER_VULKAN_DEBUG;

    /**
     * A variable to control whether the return key on the soft keyboard should
     * hide the soft keyboard on Android and iOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RETURN_KEY_HIDES_IME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RETURN_KEY_HIDES_IME")]
    public const string RETURN_KEY_HIDES_IME;

    /**
     * A variable containing a list of ROG gamepad capable mice.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ROG_GAMEPAD_MICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ROG_GAMEPAD_MICE")]
    public const string ROG_GAMEPAD_MICE;

    /**
     * A variable containing a list of devices that are not ROG gamepad capable
     * mice.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_ROG_GAMEPAD_MICE_EXCLUDED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_ROG_GAMEPAD_MICE_EXCLUDED")]
    public const string ROG_GAMEPAD_MICE_EXCLUDED;

    /**
     * A variable controlling which Dispmanx layer to use on a Raspberry PI.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_RPI_VIDEO_LAYER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_RPI_VIDEO_LAYER")]
    public const string RPI_VIDEO_LAYER;

    /**
     * Specify an "activity name" for screensaver inhibition.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_SCREENSAVER_INHIBIT_ACTIVITY_NAME]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_SCREENSAVER_INHIBIT_ACTIVITY_NAME")]
    public const string SCREENSAVER_INHIBIT_ACTIVITY_NAME;

    /**
     * A variable controlling whether SDL calls dbus_shutdown () on quit.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_SHUTDOWN_DBUS_ON_QUIT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_SHUTDOWN_DBUS_ON_QUIT")]
    public const string SHUTDOWN_DBUS_ON_QUIT;

    /**
     * A variable that specifies a backend to use for title storage.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_STORAGE_TITLE_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_STORAGE_TITLE_DRIVER")]
    public const string STORAGE_TITLE_DRIVER;

    /**
     * A variable that specifies a backend to use for user storage.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_STORAGE_USER_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_STORAGE_USER_DRIVER")]
    public const string STORAGE_USER_DRIVER;

    /**
     * Specifies whether {@link SDL.Threads.ThreadPriority.TIME_CRITICAL}
     * should be treated as realtime.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_THREAD_FORCE_REALTIME_TIME_CRITICAL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_THREAD_FORCE_REALTIME_TIME_CRITICAL")]
    public const string THREAD_FORCE_REALTIME_TIME_CRITICAL;

    /**
     * A string specifying additional information to use with
     * {@link SDL.Threads.set_current_thread_priority}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_THREAD_PRIORITY_POLICY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_THREAD_PRIORITY_POLICY")]
    public const string THREAD_PRIORITY_POLICY;

    /**
     * A variable that controls the timer resolution, in milliseconds.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_TIMER_RESOLUTION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_TIMER_RESOLUTION")]
    public const string TIMER_RESOLUTION;

    /**
     * A variable controlling whether touch events should generate synthetic
     * mouse events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_TOUCH_MOUSE_EVENTS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_TOUCH_MOUSE_EVENTS")]
    public const string TOUCH_MOUSE_EVENTS;

    /**
     * A variable controlling whether trackpads should be treated as touch
     * devices.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_TRACKPAD_IS_TOUCH_ONLY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_TRACKPAD_IS_TOUCH_ONLY")]
    public const string TRACKPAD_IS_TOUCH_ONLY;

    /**
     * A variable controlling whether the Android / tvOS remotes should be
     * listed as joystick devices, instead of sending keyboard events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_TV_REMOTE_AS_JOYSTICK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_TV_REMOTE_AS_JOYSTICK")]
    public const string TV_REMOTE_AS_JOYSTICK;

    /**
     * A variable controlling whether the screensaver is enabled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_ALLOW_SCREENSAVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_ALLOW_SCREENSAVER")]
    public const string VIDEO_ALLOW_SCREENSAVER;

    /**
     * A comma separated list containing the names of the displays that SDL
     * should sort to the front of the display list.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DISPLAY_PRIORITY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_DISPLAY_PRIORITY")]
    public const string VIDEO_DISPLAY_PRIORITY;

    /**
     * Tell the video driver that we only want a double buffer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DOUBLE_BUFFER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_DOUBLE_BUFFER")]
    public const string VIDEO_DOUBLE_BUFFER;

    /**
     * A variable that specifies a video backend to use.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DRIVER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_DRIVER")]
    public const string VIDEO_DRIVER;

    /**
     * A variable controlling whether the dummy video driver saves output
     * frames.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_DUMMY_SAVE_FRAMES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_DUMMY_SAVE_FRAMES")]
    public const string VIDEO_DUMMY_SAVE_FRAMES;

    /**
     * If ``eglGetPlatformDisplay`` fails, fall back to calling
     * ``eglGetDisplay``.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK")]
    public const string VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK;

    /**
     * A variable controlling whether the OpenGL context should be created with
     * EGL.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_FORCE_EGL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_FORCE_EGL")]
    public const string VIDEO_FORCE_EGL;

    /**
     * A variable that specifies the menu visibility when a window is fullscreen
     * in Spaces on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY")]
    public const string VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY;

    /**
     * A variable that specifies the policy for fullscreen Spaces on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES")]
    public const string VIDEO_MAC_FULLSCREEN_SPACES;

    /**
     * A variable controlling whether SDL will attempt to automatically set the
     * destination display to a mode most closely matching that of the previous
     * display if an exclusive fullscreen window is moved onto it.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_MATCH_EXCLUSIVE_MODE_ON_MOVE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_VIDEO_MATCH_EXCLUSIVE_MODE_ON_MOVE")]
    public const string VIDEO_MATCH_EXCLUSIVE_MODE_ON_MOVE;

    /**
     * A variable indicating whether the metal layer drawable size should be
     * updated for the {@link Events.EventType.WINDOW_PIXEL_SIZE_CHANGED} event
     * on macOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_METAL_AUTO_RESIZE_DRAWABLE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_VIDEO_METAL_AUTO_RESIZE_DRAWABLE")]
    public const string VIDEO_METAL_AUTO_RESIZE_DRAWABLE;

    /**
     * A variable controlling whether fullscreen windows are minimized when they
     * lose focus.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS")]
    public const string VIDEO_MINIMIZE_ON_FOCUS_LOSS;

    /**
     * A variable controlling whether the offscreen video driver saves output
     * frames.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_OFFSCREEN_SAVE_FRAMES]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_OFFSCREEN_SAVE_FRAMES")]
    public const string VIDEO_OFFSCREEN_SAVE_FRAMES;

    /**
     * A variable controlling whether all window operations will block until
     * complete.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS")]
    public const string VIDEO_SYNC_WINDOW_OPERATIONS;

    /**
     * A variable controlling whether the libdecor Wayland backend is allowed to
     * be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR")]
    public const string VIDEO_WAYLAND_ALLOW_LIBDECOR;

    /**
     * A variable controlling whether video mode emulation is enabled under
     * Wayland.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_MODE_EMULATION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WAYLAND_MODE_EMULATION")]
    public const string VIDEO_WAYLAND_MODE_EMULATION;

    /**
     * A variable controlling how modes with a non-native aspect ratio are
     * displayed under Wayland.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_MODE_SCALING]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WAYLAND_MODE_SCALING")]
    public const string VIDEO_WAYLAND_MODE_SCALING;

    /**
     * A variable controlling whether the libdecor Wayland backend is preferred
     * over native decorations.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_PREFER_LIBDECOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WAYLAND_PREFER_LIBDECOR")]
    public const string VIDEO_WAYLAND_PREFER_LIBDECOR;

    /**
     * A variable forcing non-DPI-aware Wayland windows to output at 1:1
     * scaling.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_SCALE_TO_DISPLAY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WAYLAND_SCALE_TO_DISPLAY")]
    public const string VIDEO_WAYLAND_SCALE_TO_DISPLAY;

    /**
     * A variable specifying which shader compiler to preload when using the
     * Chrome ANGLE binaries.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WIN_D3DCOMPILER]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_WIN_D3DCOMPILER")]
    public const string VIDEO_WIN_D3DCOMPILER;

    /**
     * A variable controlling whether SDL should call //XSelectInput ()// to
     * enable input events on X11 windows wrapped by SDL windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_EXTERNAL_WINDOW_INPUT]]
     *
     * @since 3.2.10
     */
    [Version (since = "3.2.10")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_EXTERNAL_WINDOW_INPUT")]
    public const string VIDEO_X11_EXTERNAL_WINDOW_INPUT;

    /**
     * A variable controlling whether the X11 //_NET_WM_BYPASS_COMPOSITOR// hint
     * should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR")]
    public const string VIDEO_X11_NET_WM_BYPASS_COMPOSITOR;

    /**
     * A variable controlling whether the X11 //_NET_WM_PING// protocol should
     * be supported.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_NET_WM_PING]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_NET_WM_PING")]
    public const string VIDEO_X11_NET_WM_PING;

    /**
     * A variable controlling whether SDL uses DirectColor visuals.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_NODIRECTCOLOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_NODIRECTCOLOR")]
    public const string VIDEO_X11_NODIRECTCOLOR;

    /**
     * A variable forcing the content scaling factor for X11 displays.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_SCALING_FACTOR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_SCALING_FACTOR")]
    public const string VIDEO_X11_SCALING_FACTOR;

    /**
     * A variable forcing the visual ID used for X11 display modes.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_VISUALID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_VISUALID")]
    public const string VIDEO_X11_VISUALID;

    /**
     * A variable forcing the visual ID chosen for new X11 windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_WINDOW_VISUALID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_WINDOW_VISUALID")]
    public const string VIDEO_X11_WINDOW_VISUALID;

    /**
     * A variable controlling whether the X11 XRandR extension should be used.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_X11_XRANDR]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VIDEO_X11_XRANDR")]
    public const string VIDEO_X11_XRANDR;

    /**
     * A variable controlling whether touch should be enabled on the back panel
     * of the PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_ENABLE_BACK_TOUCH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_ENABLE_BACK_TOUCH")]
    public const string VITA_ENABLE_BACK_TOUCH;

    /**
     * A variable controlling whether touch should be enabled on the front panel
     * of the PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_ENABLE_FRONT_TOUCH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_ENABLE_FRONT_TOUCH")]
    public const string VITA_ENABLE_FRONT_TOUCH;

    /**
     * A variable controlling the module path on the PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_MODULE_PATH]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_MODULE_PATH")]
    public const string VITA_MODULE_PATH;

    /**
     * A variable controlling whether to perform PVR initialization on the
     * PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_PVR_INIT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_PVR_INIT")]
    public const string VITA_PVR_INIT;

    /**
     * A variable controlling whether OpenGL should be used instead of OpenGL ES
     * on the PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_PVR_OPENGL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_PVR_OPENGL")]
    public const string VITA_PVR_OPENGL;

    /**
     * A variable overriding the resolution reported on the PlayStation Vita.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_RESOLUTION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_RESOLUTION")]
    public const string VITA_RESOLUTION;

    /**
     * A variable controlling which touchpad should generate synthetic mouse
     * events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VITA_TOUCH_MOUSE_DEVICE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VITA_TOUCH_MOUSE_DEVICE")]
    public const string VITA_TOUCH_MOUSE_DEVICE;

    /**
     * A variable overriding the display index used in
     * {@link SDL.Vulkan.create_surface}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VULKAN_DISPLAY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VULKAN_DISPLAY")]
    public const string VULKAN_DISPLAY;

    /**
     * Specify the Vulkan library to load.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_VULKAN_LIBRARY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_VULKAN_LIBRARY")]
    public const string VULKAN_LIBRARY;

    /**
     * A variable controlling the maximum number of chunks in a WAVE file.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WAVE_CHUNK_LIMIT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WAVE_CHUNK_LIMIT")]
    public const string WAVE_CHUNK_LIMIT;

    /**
     * A variable controlling how the fact chunk affects the loading of a WAVE
     * file.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WAVE_FACT_CHUNK]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WAVE_FACT_CHUNK")]
    public const string WAVE_FACT_CHUNK;

    /**
     * A variable controlling how the size of the RIFF chunk affects the loading
     * of a WAVE file.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WAVE_RIFF_CHUNK_SIZE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WAVE_RIFF_CHUNK_SIZE")]
    public const string WAVE_RIFF_CHUNK_SIZE;

    /**
     * A variable controlling how a truncated WAVE file is handled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WAVE_TRUNCATION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WAVE_TRUNCATION")]
    public const string WAVE_TRUNCATION;

    /**
     * A variable controlling whether the window is activated when the
     * {@link SDL.Video.raise_window} function is called.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOW_ACTIVATE_WHEN_RAISED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOW_ACTIVATE_WHEN_RAISED")]
    public const string WINDOW_ACTIVATE_WHEN_RAISED;

    /**
     * A variable controlling whether the window is activated when the
     * {@link SDL.Video.show_window} function is called.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN")]
    public const string WINDOW_ACTIVATE_WHEN_SHOWN;

    /**
     * If set to "0" then never set the top-most flag on an SDL Window even if
     * the application requests it.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOW_ALLOW_TOPMOST]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOW_ALLOW_TOPMOST")]
    public const string WINDOW_ALLOW_TOPMOST;

    /**
     * A variable controlling whether the window frame and title bar are
     * interactive when the cursor is hidden.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN")]
    public const string WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN;

    /**
     * A variable controlling whether SDL generates window-close events for
     * Alt+F4 on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4")]
    public const string WINDOWS_CLOSE_ON_ALT_F4;

    /**
     * A variable controlling whether menus can be opened with their keyboard
     * shortcut (Alt+mnemonic).
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_ENABLE_MENU_MNEMONICS]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_ENABLE_MENU_MNEMONICS")]
    public const string WINDOWS_ENABLE_MENU_MNEMONICS;

    /**
     * A variable controlling whether the windows message loop is processed by
     * SDL.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP")]
    public const string WINDOWS_ENABLE_MESSAGE_LOOP;

    /**
     * A variable controlling whether SDL will clear the window contents when
     * the WM_ERASEBKGND message is received.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_ERASE_BACKGROUND_MODE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_ERASE_BACKGROUND_MODE")]
    public const string WINDOWS_ERASE_BACKGROUND_MODE;

    /**
     * A variable controlling whether SDL uses Kernel Semaphores on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_FORCE_SEMAPHORE_KERNEL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_FORCE_SEMAPHORE_KERNEL")]
    public const string WINDOWS_FORCE_SEMAPHORE_KERNEL;

    /**
     * A variable controlling whether GameInput is used for raw keyboard and
     * mouse on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_GAMEINPUT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_GAMEINPUT")]
    public const string WINDOWS_GAMEINPUT;

    /**
     * A variable to specify custom icon resource id from RC file on Windows
     * platform.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_INTRESOURCE_ICON]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_INTRESOURCE_ICON")]
    public const string WINDOWS_INTRESOURCE_ICON;

    /**
     * A variable to specify custom icon resource id from RC file on Windows
     * platform.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_INTRESOURCE_ICON_SMALL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_INTRESOURCE_ICON_SMALL")]
    public const string WINDOWS_INTRESOURCE_ICON_SMALL;

    /**
     * A variable controlling whether raw keyboard events are used on Windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_RAW_KEYBOARD]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_RAW_KEYBOARD")]
    public const string WINDOWS_RAW_KEYBOARD;

    /**
     * A variable controlling whether or not the RIDEV_NOHOTKEYS flag is set
     * when enabling Windows raw keyboard events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_RAW_KEYBOARD_EXCLUDE_HOTKEYS]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_RAW_KEYBOARD_EXCLUDE_HOTKEYS")]
    public const string WINDOWS_RAW_KEYBOARD_EXCLUDE_HOTKEYS;

    /**
     * A variable controlling whether the RIDEV_INPUTSINK flag is set when
     * enabling Windows raw keyboard events.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_RAW_KEYBOARD_INPUTSINK]]
     *
     * @since 3.4.4
     */
    [Version (since = "3.4.4")]
    [CCode (cname = "SDL_HINT_WINDOWS_RAW_KEYBOARD_INPUTSINK")]
    public const string WINDOWS_RAW_KEYBOARD_INPUTSINK;

    /**
     * A variable controlling whether SDL uses the D3D9Ex API introduced in
     * Windows Vista, instead of normal D3D9.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_WINDOWS_USE_D3D9EX]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_WINDOWS_USE_D3D9EX")]
    public const string WINDOWS_USE_D3D9EX;

    /**
     * A variable controlling whether X11 windows are marked as
     * override-redirect.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_X11_FORCE_OVERRIDE_REDIRECT]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_X11_FORCE_OVERRIDE_REDIRECT")]
    public const string X11_FORCE_OVERRIDE_REDIRECT;

    /**
     * A variable specifying the type of an X11 window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_X11_WINDOW_TYPE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_X11_WINDOW_TYPE")]
    public const string X11_WINDOW_TYPE;

    /**
     * Specify the XCB library to load for the X11 driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_X11_XCB_LIBRARY]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_X11_XCB_LIBRARY")]
    public const string X11_XCB_LIBRARY;

    /**
     * A variable controlling whether XInput should be used for controller
     * handling.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HINT_XINPUT_ENABLED]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HINT_XINPUT_ENABLED")]
    public const string XINPUT_ENABLED;
} // SDL.Hints

/**
 * Object Properties
 *
 * A property is a variable that can be created and retrieved by name at
 * runtime.
 *
 * All properties are part of a property group
 * ({@link SDL.Properties.PropertiesID}). A property group can be created
 * with the {@link SDL.Properties.create_properties} function and destroyed
 * with the {@link SDL.Properties.destroy_properties} function.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryProperties]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_properties.h")]
namespace SDL.Properties {
    /**
     * Clear a property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ClearProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to clear.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ClearProperty")]
    public bool clear_property (PropertiesID props, string name);

    /**
     * Copy a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CopyProperties]]
     *
     * @param src the properties to copy.
     * @param dst the destination properties.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CopyProperties")]
    public bool copy_properties (PropertiesID src, PropertiesID dst);

    /**
     * Create a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProperties]]
     *
     * @return an ID for a new group of properties, or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreateProperties")]
    public static PropertiesID create_properties ();

    /**
     * Destroy a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DestroyProperties]]
     *
     * @param props the properties to destroy.
     *
     * @since 3.2.0
     *
     * @see create_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DestroyProperties")]
    public static void destroy_properties (PropertiesID props);

    /**
     * Enumerate the properties contained in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EnumerateProperties]]
     *
     * @param props the properties to query.
     * @param callback the function to call for each property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EnumerateProperties")]
    public static bool enumerate_properties (PropertiesID props,
            EnumeratePropertiesCallback callback);

    /**
     * Get a boolean property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetBooleanProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     * @param default_value the default value of the property.
     *
     * @return the value of the property, or default_value if it is not set or
     * not a boolean property.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     * @see has_property
     * @see set_boolean_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetBooleanProperty")]
    public static bool get_boolean_property (PropertiesID props, string name, bool default_value);

    /**
     * Get a floating point property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetFloatProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     * @param default_value the default value of the property.
     *
     * @return the value of the property, or default_value if it is not set or
     * not a float property.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     * @see has_property
     * @see set_float_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetFloatProperty")]
    public static float get_float_property (PropertiesID props, string name, float default_value);

    /**
     * Get the global SDL properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGlobalProperties]]
     *
     * @return an valid property ID on success, or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetGlobalProperties")]
    public static PropertiesID get_global_properties ();

    /**
     * Get a number property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetNumberProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     * @param default_value the default value of the property.
     *
     * @return the value of the property, or default_value if it is not set or
     * not a number property.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     * @see has_property
     * @see set_number_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetNumberProperty")]
    public int64 get_number_property (PropertiesID props, string name, int64 default_value);

    /**
     * Get a pointer property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPointerProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     * @param default_value the default value of the property.
     *
     * @return the value of the property, or default_value if it is not set or
     * not a pointer property.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     * @see has_property
     * @see set_pointer_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetPointerProperty")]
    public static void * get_pointer_property (PropertiesID props, string name, void* default_value);

    /**
     * Get the type of a property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPropertyType]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     *
     * @return the type of the property, or {@link PropertyType.INVALID} if it
     * is not set.
     *
     * @since 3.2.0
     *
     * @see has_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetPropertyType")]
    public PropertyType get_property_type (PropertiesID props, string name);

    /**
     * Get a string property from a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetStringProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     * @param default_value the default value of the property.
     *
     * @return the value of the property, or default_value if it is not set or
     * not a string property.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     * @see has_property
     * @see set_string_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetStringProperty")]
    public unowned string ? get_string_property (PropertiesID props, string name,
            string? default_value);

    /**
     * Return whether a property exists in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HasProperty]]
     *
     * @param props the properties to query.
     * @param name the name of the property to query.
     *
     * @return true if the property exists, or false if it doesn't.
     *
     * @since 3.2.0
     *
     * @see get_property_type
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HasProperty")]
    public bool has_property (PropertiesID props, string name);

    /**
     * Lock a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LockProperties]]
     *
     * @param props the properties to lock.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see unlock_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LockProperties")]
    public bool lock_properties (PropertiesID props);

    /**
     * Set a boolean property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetBooleanProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_boolean_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetBooleanProperty")]
    public bool set_boolean_property (PropertiesID props, string name, bool value);

    /**
     * Set a floating point property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetFloatProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_float_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetFloatProperty")]
    public bool set_float_property (PropertiesID props, string name, float value);

    /**
     * Set an integer property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetNumberProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_number_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetNumberProperty")]
    public bool set_number_property (PropertiesID props, string name, int64 value);

    /**
     * Set a pointer property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetPointerProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property, or null to delete the
     * property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_pointer_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetPointerProperty")]
    public bool set_pointer_property (PropertiesID props, string name, void* value);

    /**
     * Set a pointer property in a group of properties with a cleanup function
     * that is called when the property is deleted.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetPointerPropertyWithCleanup]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property, or null to delete the
     * property.
     * @param cleanup the function to call when this property is deleted, or
     * null if no cleanup is necessary.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_pointer_property
     * @see set_pointer_property
     * @see CleanupPropertyCallback
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetPointerPropertyWithCleanup", has_target = true)]
    public bool set_pointer_property_with_cleanup (PropertiesID props, string name, void* value,
            CleanupPropertyCallback? cleanup);

    /**
     * Set a string property in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetStringProperty]]
     *
     * @param props the properties to modify.
     * @param name the name of the property to modify.
     * @param value the new value of the property, or null to delete the
     * property.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_string_property
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetStringProperty")]
    public bool set_string_property (PropertiesID props, string name, string? value);

    /**
     * Unlock a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_UnlockProperties]]
     *
     * @param props the properties to unlock.
     *
     * @since 3.2.0
     *
     * @see lock_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_UnlockProperties")]
    public void unlock_properties (PropertiesID props);

    /**
     * A callback used to free resources when a property is deleted.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CleanupPropertyCallback]]
     *
     * @param value the pointer assigned to the property to clean up.
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CleanupPropertyCallback", has_target = true, instance_pos = 0)]
    public delegate void CleanupPropertyCallback (void* value);

    /**
     * A callback used to enumerate all the properties in a group of properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EnumeratePropertiesCallback]]
     *
     * @param props the {@link PropertiesID} that is being enumerated.
     * @param name the next property name in the enumeration.
     *
     * @since 3.2.0
     *
     * @see enumerate_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EnumeratePropertiesCallback", has_target = true, instance_pos = 0)]
    public delegate void EnumeratePropertiesCallback (PropertiesID props, string name);

    /**
     * An ID that represents a properties set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PropertiesID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_PropertiesID", has_type_id = false)]
    public struct PropertiesID : uint32 {}

    /**
     * SDL property type
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PropertyType]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_PropertyType", cprefix = "SDL_PROPERTY_TYPE_", has_type_id = false)]
    public enum PropertyType {
        INVALID,
        POINTER,
        STRING,
        NUMBER,
        FLOAT,
        BOOLEAN
    } // PropertyType

    /**
     * A generic property for naming things.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PROP_NAME_STRING]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_PROP_NAME_STRING")]
    public const string PROP_NAME_STRING;
} // SDL.Properties

/**
 * Error Handling
 *
 * Simple error message routines for SDL.
 *
 * Most apps will interface with these APIs in exactly one function: when almost
 * any SDL function call reports failure, you can get a human-readable string of
 * the problem from {@link SDL.Error.get_error}.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryError]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_error.h")]
namespace SDL.Error {
    /**
     * Clear any previous error message for this thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ClearError]]
     *
     * @return true
     *
     * @since 3.2.0
     *
     * @see get_error
     * @see set_error
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ClearError")]
    public static bool clear_error ();

    /**
     * Retrieve a message about the last error that occurred on the current
     * thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetError]]
     *
     * @return a message with information about the specific error that
     * occurred, or an empty string if there hasn't been an error message set
     * since the last call to {@link clear_error}.
     *
     * @since 3.2.0
     *
     * @see clear_error
     * @see set_error
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetError")]
    public static unowned string get_error ();

    /**
     * Set an error indicating that memory allocation failed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OutOfMemory]]
     *
     * @return false
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OutOfMemory")]
    public static bool out_of_memory ();

    /**
     * Set the SDL error message for the current thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetError]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @return false
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_SetError", sentinel = "")]
    public static bool set_error (string format, ...);

    /**
     * Set the SDL error message for the current thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetErrorV]]
     *
     * @param format a printf()-style message format string.
     * @param ap a variable argument list.
     *
     * @return false
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetErrorV")]
    public static bool set_errorv (string format, va_list ap);

    /**
     * A macro to standardize error reporting on "parameter invalid" operations.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_InvalidParamError]]
     *
     * @param param the invalid parameter name
     *
     * @return false
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_InvalidParamError")]
    public static bool invalid_param_error (string param);

    /**
     * A macro to standardize error reporting on "unsupported"" operations.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Unsupported]]
     *
     * @return false
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_Unsupported")]
    public static bool unsupported ();
} // SDL.Error

/**
 * Log Handling
 *
 * Simple log messages with priorities and categories. A message's
 * {@link SDL.Log.LogPriority} signifies how important the message is.
 * A message's {@link SDL.Log.LogCategory} signifies from what domain it
 * belongs to. Every category has a minimum priority specified: when a message
 * belongs to that category, it will only be sent out if it has that minimum
 * priority or higher.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryLog]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_log.h")]
namespace SDL.Log {
    /**
     * Get the default log output function.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDefaultLogOutputFunction]]
     *
     * @return the default log output callback.
     *
     * @since 3.2.0
     *
     * @see set_log_output_function
     * @see get_log_output_function
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDefaultLogOutputFunction")]
    public static LogOutputFunction get_default_log_output_function ();

    /**
     * Get the current log output function.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetLogOutputFunction]]
     *
     * @param callback a {@link LogOutputFunction} filled in with the current
     * log callback.
     *
     * @since 3.2.0
     *
     * @see get_default_log_output_function
     * @see set_log_output_function
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetLogOutputFunction")]
    public static void get_log_output_function (out unowned LogOutputFunction callback);

    /**
     * Get the priority of a particular log category.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetLogPriority]]
     *
     * @param category the category to query.
     *
     * @since 3.2.0
     *
     * @see set_log_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetLogPriority")]
    public static LogPriority get_log_priority (LogCategory category);

    /**
     * Log a message with {@link LogCategory.APPLICATION} and
     * {@link LogPriority.INFO}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Log]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log_critical
     * @see log_debug
     * @see log_error
     * @see log_info
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_Log", sentinel = "")]
    public static void log (string format, ...);

    /**
     * Log a message with {@link LogPriority.CRITICAL}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogCritical]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_debug
     * @see log_error
     * @see log_info
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogCritical", sentinel = "")]
    public static void log_critical (LogCategory category, string format, ...);

    /**
     * Log a message with {@link LogPriority.DEBUG}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogDebug]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_error
     * @see log_info
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogDebug", sentinel = "")]
    public static void log_debug (LogCategory category, string format, ...);

    /**
     * Log a message with {@link LogPriority.ERROR}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogError]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_info
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogError", sentinel = "")]
    public static void log_error (LogCategory category, string format, ...);

    /**
     * Log a message with {@link LogPriority.INFO}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogInfo]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_error
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogInfo", sentinel = "")]
    public static void log_info (LogCategory category, string format, ...);

    /**
     * Log a message with the specified category and priority.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogMessage]]
     *
     * @param category the category of the message.
     * @param priority the priority of the message.
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_error
     * @see log_info
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogMessage", sentinel = "")]
    public static void log_message (LogCategory category,
            LogPriority priority,
            string format,
            ...);

    /**
     * Log a message with the specified category and priority.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogMessageV]]
     *
     * @param category the category of the message.
     * @param priority the priority of the message.
     * @param format a printf()-style message format string.
     * @param ap a variable argument list.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_error
     * @see log_info
     * @see log_message
     * @see log_trace
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LogMessageV")]
    public static void log_messagev (LogCategory category, LogPriority priority, string format, va_list ap);

    /**
     * Log a message with {@link LogPriority.TRACE}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogTrace]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_info
     * @see log_error
     * @see log_message
     * @see log_messagev
     * @see log_verbose
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogTrace", sentinel = "")]
    public static void log_trace (LogCategory category, string format, ...);

    /**
     * Log a message with {@link LogPriority.VERBOSE}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogVerbose]]
     *
     * @param format a printf()-style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_info
     * @see log_error
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_warn
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogVerbose", sentinel = "")]
    public static void log_verbose (LogCategory category, string format, ...);

    /**
     * Log a message with {@link LogPriority.WARN}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogWarn]]
     *
     * @param format a printf() style message format string.
     * @param ... additional parameters matching % tokens in the fmt string,
     * if any.
     *
     * @since 3.2.0
     *
     * @see log
     * @see log_critical
     * @see log_debug
     * @see log_info
     * @see log_error
     * @see log_message
     * @see log_messagev
     * @see log_trace
     * @see log_verbose
     */
    [Version (since = "3.2.0")]
    [PrintfFormat]
    [CCode (cname = "SDL_LogWarn", sentinel = "")]
    public static void log_warn (LogCategory category, string format, ...);

    /**
     * Reset all priorities to default.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ResetLogPriorities]]
     *
     * @since 3.2.0
     *
     * @see set_log_priorities
     * @see set_log_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ResetLogPriorities")]
    public static void reset_log_priorities ();

    /**
     * Replace the default log output function with one of your own.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLogOutputFunction]]
     *
     * @param callback a {@link LogOutputFunction} to call instead of the
     * default.
     *
     * @since 3.2.0
     *
     * @see get_default_log_output_function
     * @see get_log_output_function
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLogOutputFunction", has_target = true)]
    public static void set_log_output_function (LogOutputFunction callback);

    /**
     * Replace the default log output function with one of your own.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLogPriorities]]
     *
     * @param priority the {@link LogPriority} to assign.
     *
     * @since 3.2.0
     *
     * @see reset_log_priorities
     * @see set_log_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLogPriorities")]
    public static void set_log_priorities (LogPriority priority);

    /**
     * Set the priority of a particular log category.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLogPriority]]
     *
     * @param category the category to assign a priority to.
     * @param priority the {@link LogPriority} to assign.
     *
     * @since 3.2.0
     *
     * @see get_log_priority
     * @see reset_log_priorities
     * @see set_log_priorities
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLogPriority")]
    public static void set_log_priority (LogCategory category, LogPriority priority);

    /**
     * Set the text prepended to log messages of a given priority.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLogPriorityPrefix]]
     *
     * @param priority the {@link LogPriority} to modify.
     * @param prefix the prefix to use for that log priority, or null to use
     * no prefix.
     *
     * @since 3.2.0
     *
     * @see set_log_priorities
     * @see set_log_priority
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLogPriorityPrefix")]
    public static void set_log_priority_prefix (LogPriority priority, string? prefix);

    /**
     * The prototype for the log output callback function.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogOutputFunction]]
     *
     * @param category the category of the message.
     * @param priority the priority of the message.
     * @param message the message being output.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LogOutputFunction", has_target = true, instance_pos = 0)]
    public delegate void LogOutputFunction (LogCategory category,
            LogPriority priority,
            string message);

    /**
     * The predefined log categories
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogCategory]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LogCategory", cprefix = "SDL_LOG_CATEGORY_", has_type_id = false)]
    public enum LogCategory {
    /**
     * Application category
     *
     */
        APPLICATION,

        /**
         * Error category
         *
         */
        ERROR,

        /**
         * Assert category
         *
         */
        ASSERT,

        /**
         * System category
         */
        SYSTEM,

        /**
         * Audio category
         *
         */
        AUDIO,

        /**
         * Video category
         *
         */
        VIDEO,

        /**
         * Render category
         *
         */
        RENDER,

        /**
         * Input category
         *
         */
        INPUT,

        /**
         * Test category
         *
         */
        TEST,

        /**
         * GPU category
         *
         */
        GPU,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED2,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED3,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED4,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED5,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED6,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED7,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED8,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED9,

        /**
         * Reserved for future SDL library use
         *
         */
        RESERVED10,

        /**
         * Beyond this point is reserved for application use.
         *
         * Example:
         * {{{
         *   public enum MyAppCategories {
         *      MYAPP_CATEGORY_AWESOME1 = SDL_LOG_CATEGORY_CUSTOM,
         *      MYAPP_CATEGORY_AWESOME2,
         *      MYAPP_CATEGORY_AWESOME3,
         *      ...
         *   };
         * }}}
         *
         */
        CUSTOM,
    } // LogCategory

    /**
     * The predefined log priorities
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LogPriority]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LogPriority", cprefix = "SDL_LOG_PRIORITY_", has_type_id = false)]
    public enum LogPriority {
    /**
     * Invalid Priority.
     *
     */
        INVALID,

        /**
         * Trace Priority.
         *
         */
        TRACE,

        /**
         * Verbose Priority.
         *
         */
        VERBOSE,

        /**
         * Debug Priority.
         *
         */
        DEBUG,

        /**
         * Info Priority.
         *
         */
        INFO,

        /**
         * Warning Priority.
         *
         */
        WARN,

        /**
         * Error Priority.
         *
         */
        ERROR,

        /**
         * Critical Priority.
         *
         */
        CRITICAL,

        /**
         * A value marking the amount of priorities in the enum.
         *
         */
        COUNT
    } // LogPriority
} // SDL.Log

/**
 * Assertions
 *
 * SDL assertions operate like your usual assert macro, but with some added
 * features.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryAssert]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_assert.h")]
namespace SDL.Assert {
    /**
     * Get the current assertion handler.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAssertionHandler]]
     *
     * @return the {@link AssertionHandler} that is called when an assert
     * triggers.
     *
     * @since 3.2.0
     *
     * @see set_assertion_handler
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAssertionHandler")]
    public static AssertionHandler get_assertion_handler ();

    /**
     * Get a list of all assertion failures.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAssertionReport]]
     *
     * @return a list of all failed assertions or NULL if the list is empty.
     * This memory should not be modified or freed by the application. This
     * pointer remains valid until the next call to {@link SDL.Init.quit} or
     * {@link reset_assertion_report}.
     *
     * @since 3.2.0
     *
     * @see reset_assertion_report
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAssertionReport")]
    public static unowned AssertData ? get_assertion_report ();

    /**
     * Get the default assertion handler.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDefaultAssertionHandler]]
     *
     * @return the default {@link AssertionHandler} that is called when an
     * assert triggers.
     *
     * @since 3.2.0
     *
     * @see get_assertion_handler
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDefaultAssertionHandler")]
    public static AssertionHandler get_default_assertion_handler ();

    /**
     * Clear the list of all assertion failures.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ReportAssertion]]
     *
     * @since 3.2.0
     *
     * @see get_assertion_report
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ResetAssertionReport")]
    public static void reset_assertion_report ();

    /**
     * Clear the list of all assertion failures.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ReportAssertion]]
     *
     * @param handler the {@link AssertionHandler} function to call when an
     * assertion fails or null for the default handler.
     *
     * @since 3.2.0
     *
     * @see get_assertion_handler
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetAssertionHandler", has_target = true)]
    public static void set_assertion_handler (AssertionHandler? handler);

    /**
     * A callback that fires when an SDL assertion fails.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AssertionHandler]]
     *
     * @param data a pointer to the {@link AssertData} structure corresponding
     * to the current assertion.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AssertionHandler", has_target = true)]
    public delegate AssertState AssertionHandler (AssertData data);

    /**
     * Information about an assertion failure.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AssertData]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AssertData", has_type_id = false)]
    public struct AssertData {
    /**
     * Set to true if app should always continue when assertion is
     * triggered.
     *
     */
        public bool always_ignore;

    /**
     * Number of times this assertion has been triggered.
     *
     */
        public uint trigger_count;

    /**
     * A string of this assert's test code.
     *
     */
        public string condition;

    /**
     * The source file where this assert lives.
     *
     */
        public string filename;

    /**
     * The line in `filename` where this assert lives.
     *
     */
        public int linenum;

    /**
     * The name of the function where this assert lives.
     *
     */
        public string function;

    /**
     * Next item in the linked list
     *
     */
        public AssertData* next;
    } // AssertData

    /**
     * Possible outcomes from a triggered assertion.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AssertState]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_AssertState", cprefix = "SDL_ASSERTION_", has_type_id = false)]
    public enum AssertState {
    /**
     * Retry the assert immediately.
     */
        RETRY,

        /**
         * Make the debugger trigger a breakpoint.
         */
        BREAK,

        /**
         * Terminate the program.
         */
        ABORT,

        /**
         * Ignore the assert.
         */
        IGNORE,

        /**
         * Ignore the assert from now on.
         */
        ALWAYS_IGNORE
    } // AssertState

    /**
     * An assertion test that is normally performed only in debug builds.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_assert]]
     *
     * @param condition boolean value to test.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_assert")]
    public static void assert (bool condition);

    /**
     * An assertion test that is always performed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_assert_always]]
     *
     * @param condition boolean value to test.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_assert_always")]
    public static void assert_always (bool condition);

    /**
     * A macro that reports the current file being compiled,
     * for use in assertions.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ASSERT_FILE]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_ASSERT_FILE")]
    public const string ASSERT_FILE;

    /**
     * The level of assertion aggressiveness.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ASSERT_LEVEL]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ASSERT_LEVEL")]
    public const int ASSERT_LEVEL;

    /**
     * An assertion test that is performed only when built with paranoid
     * settings.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_assert_paranoid]]
     *
     * @param condition boolean value to test.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_assert_paranoid")]
    public static void assert_paranoid (bool condition);

    /**
     * An assertion test that is performed even in release builds.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_assert_release]]
     *
     * @param condition boolean value to test.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_assert_release")]
    public static bool assert_release (bool condition);

    /**
     * A macro that reports the current file being compiled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FILE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FILE")]
    public const string FILE;

    /**
     * A macro that reports the current function being compiled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FUNCTION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FUNCTION")]
    public const string FUNCTION;

    /**
     * A macro that reports the current line number of the file being compiled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LINE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "LINE")]
    public const string LINE;

    /**
     * A macro for wrapping code in do {} while (0); without compiler warnings.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_NULL_WHILE_LOOP_CONDITION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_NULL_WHILE_LOOP_CONDITION")]
    public const int NULL_WHILE_LOOP_CONDITION;

    /**
     * Attempt to tell an attached debugger to pause.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_TriggerBreakpoint]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_TriggerBreakpoint")]
    public static void trigger_breakpoint ();
} // SDL.Assert

/**
 * Querying SDL Version
 *
 * Functionality to query the current SDL version, both as headers the app was
 * compiled against, and a library the app is linked to.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryVersion]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_version.h")]
namespace SDL.Version {
    /**
     * Attempt to tell an attached debugger to pause.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetRevision]]
     *
     * @return an arbitrary string, uniquely identifying the exact revision
     * of the SDL library in use.
     *
     * @since 3.2.0
     *
     * @see get_version
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetRevision")]
    public static unowned string get_revision ();

    /**
     * Get the version of SDL that is linked against your program.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetVersion]]
     *
     * @return the version of the linked library.
     *
     * @since 3.2.0
     *
     * @see get_revision
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetVersion")]
    public static unowned int get_version ();

    /**
     * The current major version of SDL headers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MAJOR_VERSION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MAJOR_VERSION")]
    public const int MAJOR;

    /**
     * The current micro (or patchlevel) version of the SDL headers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MAJOR_VERSION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MICRO_VERSION")]
    public const int MICRO;

    /**
     * The current minor version of the SDL headers.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MAJOR_VERSION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MINOR_VERSION")]
    public const int MINOR;

    /**
     * This macro is a string describing the source at a particular point in
     * development.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_REVISION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cheader_filename = "SDL3/SDL_revision.h", cname = "SDL_REVISION")]
    public const string REVISION;

    /**
     * This is the version number macro for the current SDL version.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSION]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSION")]
    public const int VERSION;

    /**
     * This macro will evaluate to true if compiled with SDL at least X.Y.Z.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSION_ATLEAST]]
     *
     * @param major the major version number.
     * @param minor the minor version number.
     * @param micro the micro/patch version number.
     *
     * @return true if the compiled version is at least major.minor.micro;
     * false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSION_ATLEAST")]
    public static bool sdl_version_at_least (int major, int minor, int micro);

    /**
     * This macro turns the version numbers into a numeric value.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSIONNUM]]
     *
     * @param major the major version number.
     * @param minor the minor version number.
     * @param micro the micro/patch version number.
     *
     * @return a full version number. e.g. (1,2,3) becomes 1002003.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSIONNUM")]
    public static int version_num (int major, int minor, int micro);

    /**
     * This macro extracts the major version from a version number
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSIONNUM_MAJOR]]
     *
     * @param version the version number in full format (e.g. 1002003).
     *
     * @return the major version number. e.g. 1002003 becomes 1.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSIONNUM_MAJOR")]
    public static int version_num_major (int version);

    /**
     * This macro extracts the micro/patch version from a version number
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSIONNUM_MICRO]]
     *
     * @param version the version number in full format (e.g. 1002003).
     *
     * @return the micro/patch version number. e.g. 1002003 becomes 3.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSIONNUM_MICRO")]
    public static int version_num_micro (int version);

    /**
     * This macro extracts the minor version from a version number
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_VERSIONNUM_MINOR]]
     *
     * @param version the version number in full format (e.g. 1002003).
     *
     * @return the minor version number. e.g. 1002003 becomes 2.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_VERSIONNUM_MINOR")]
    public static int version_num_minor (int version);
} // SDL.Version

///
/// VIDEO
///

/**
 * Display and Window Management
 *
 * SDL's video subsystem is largely interested in abstracting window
 * management from the underlying operating system. You can create windows,
 * manage them in various ways, set them fullscreen, and get events when
 * interesting things happen with them, such as the mouse or keyboard
 * interacting with a window.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryVideo]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_video.h")]
namespace SDL.Video {
    /**
     * Create a child popup window of the specified parent window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreatePopupWindow]]
     *
     * @param parent the parent of the window.
     * @param offset_x the x position of the popup window relative
     * to the origin of the parent.
     * @param offset_y the y position of the popup window relative
     * to the origin of the parent window.
     * @param w the width of the window.
     * @param h the height of the window.
     * @param flags {@link WindowFlags.TOOLTIP} or
     * {@link WindowFlags.POPUP_MENU}, and zero or more additional
     * {@link WindowFlags} OR'd together.
     *
     * @return the window that was created or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_window
     * @see create_window_with_properties
     * @see destroy_window
     * @see get_window_parent
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreatePopupWindow")]
    public static Window ? create_popup_window (Window parent,
            int offset_x,
            int offset_y,
            int w,
            int h,
            WindowFlags flags);

    /**
     * Create a window with the specified dimensions and flags.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindow]]
     *
     * @param title the title of the window, in UTF-8 encoding.
     * @param w the width of the window.
     * @param h the height of the window.
     * @param flags 0, or one or more {@link WindowFlags} OR'd
     * together.
     *
     * @return the window that was created or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see Render.create_window_and_renderer
     * @see create_popup_window
     * @see create_window_with_properties
     * @see destroy_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreateWindow")]
    public static Window ? create_window (string title, int w, int h, WindowFlags flags);

    /**
     * Create a window with the specified dimensions and flags.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindow]]
     *
     * @param props the properties to use.
     *
     * @return the window that was created or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see Properties.create_properties
     * @see create_window
     * @see destroy_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreateWindowWithProperties")]
    public static Window ? create_window_with_properties (SDL.Properties.PropertiesID props);

    /**
     * Destroy a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DestroyWindow]]
     *
     * @param window the window to destroy.
     *
     * @since 3.2.0
     *
     * @see create_popup_window
     * @see create_window
     * @see create_window_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DestroyWindow")]
    public static void destroy_window (Window window);

    /**
     * Destroy the surface associated with the window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DestroyWindowSurface]]
     *
     * @param window the window to update.
     *
     * @since 3.2.0
     *
     * @see get_window_surface
     * @see window_has_surface
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DestroyWindowSurface")]
    public static bool destroy_window_surface (Window window);

    /**
     * Prevent the screen from being blanked by a screen saver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DisableScreenSaver]]
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see enable_screensaver
     * @see screensaver_enabled
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DisableScreenSaver")]
    public static bool disable_screensaver ();

    /**
     * Get the currently active EGL config.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGL_GetCurrentConfig]]
     *
     * @return the currently active EGL config or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGL_GetCurrentConfig")]
    public static EGLConfig ? egl_get_current_config ();

    /**
     * Get the currently active EGL display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGL_GetCurrentConfig]]
     *
     * @return the currently active EGL display or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGL_GetCurrentDisplay")]
    public static EGLDisplay ? egl_get_current_display ();

    /**
     * Get an EGL library function by name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGL_GetProcAddress]]
     *
     * @param proc the name of an EGL function.
     *
     * @return a pointer to the named EGL function. The returned pointer
     * should be cast to the appropriate function signature.
     *
     * @since 3.2.0
     *
     * @see egl_get_current_display
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGL_GetProcAddress")]
    public static StdInc.FunctionPointer egl_get_proc_address (string proc);

    /**
     * Get the EGL surface associated with the window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGL_GetWindowSurface]]
     *
     * @param window the window to query.
     *
     * @return the {@link EGLSurface} pointer associated with the window, or
     * null on failure.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGL_GetWindowSurface")]
    public static EGLSurface ? egl_get_window_surface (Window window);

    /**
     * Sets the callbacks for defining custom EGLAttrib arrays for EGL
     * initialization.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGL_SetAttributeCallbacks]]
     *
     * @param platform_attrib_callback callback for attributes to pass to
     * ``eglGetPlatformDisplay``. May be null.
     * @param surface_attrib_callback callback for attributes to pass to
     * ``eglCreateSurface``. May be null.
     * @param context_attrib_callback callback for attributes to pass to
     * ``eglCreateContext``. May be null.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGL_SetAttributeCallbacks", has_target = true)]
    public static void egl_set_attribute_callbacks (
            EGLAttribArrayCallback? platform_attrib_callback,
            EGLIntArrayCallback? surface_attrib_callback,
            EGLIntArrayCallback? context_attrib_callback);

    /**
     *Allow the screen to be blanked by a screen saver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EnableScreenSaver]]
     *
     * @since 3.2.0
     *
     * @see disable_screensaver
     * @see screensaver_enabled
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EnableScreenSaver")]
    public static bool enable_screensaver ();

    /**
     * Request a window to demand attention from the user.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FlashWindow]]
     *
     * @param window the window to be flashed.
     * @param operation the operation to perform.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FlashWindow")]
    public static bool flash_window (Window window, FlashOperation operation);

    /**
     * Get the closest match to the requested display mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetClosestFullscreenDisplayMode]]
     *
     * @param display_id the instance ID of the display to query.
     * @param w the width in pixels of the desired display mode.
     * @param h the height in pixels of the desired display mode.
     * @param refresh_rate the refresh rate of the desired display mode, or
     * 0.0f for the desktop refresh rate.
     * @param include_high_density_modes boolean to include high density
     * modes in the search.
     * @param closest a pointer filled in with the closest display mode equal
     * to or larger than the desired mode.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_displays
     * @see get_fullscreen_display_modes
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetClosestFullscreenDisplayMode")]
    public static bool get_closest_fullscreen_display_mode (DisplayID display_id,
            int w,
            int h,
            float refresh_rate,
            bool include_high_density_modes,
            out DisplayMode closest);

    /**
     * Get information about the current display mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetClosestFullscreenDisplayMode]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return a pointer to the desktop display mode or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_desktop_display_mode
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetCurrentDisplayMode")]
    public static DisplayMode ? get_current_display_mode (DisplayID display_id);

    /**
     * Get the orientation of a display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetCurrentDisplayOrientation]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return the {@link DisplayOrientation} enum value of the display, or
     * {@link DisplayOrientation.UNKNOWN} if it isn't available.
     *
     * @since 3.2.0
     *
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetCurrentDisplayOrientation")]
    public static DisplayOrientation get_current_display_orientation (DisplayID display_id);

    /**
     * Get the name of the currently initialized video driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetCurrentVideoDriver]]
     *
     * @return the name of the current video driver or null if no driver has
     * been initialized.
     *
     * @since 3.2.0
     *
     * @see get_num_video_drivers
     * @see get_video_driver
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetCurrentVideoDriver")]
    public static unowned string ? get_current_video_driver ();

    /**
     * Get information about the desktop's display mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDesktopDisplayMode]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return a pointer to the desktop display mode or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_current_display_mode
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDesktopDisplayMode")]
    public static DisplayMode ? get_desktop_display_mode (DisplayID display_id);

    /**
     * Get the desktop area represented by a display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayBounds]]
     *
     * @param display_id the instance ID of the display to query.
     * @param rect the {@link Rect.Rect} structure filled in with the display
     * bounds.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_display_usable_bounds
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayBounds")]
    public static bool get_display_bounds (DisplayID display_id, out Rect.Rect rect);

    /**
     * Get the content scale of a display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayContentScale]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return the content scale of the display, or 0.0f on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_display_scale
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayContentScale")]
    public static float get_display_content_scale (DisplayID display_id);

    /**
     * Get the display containing a point.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayForPoint]]
     *
     * @param point the point to query.
     *
     * @return the instance ID of the display containing the point or 0 on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_display_bounds
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayForPoint")]
    public static DisplayID get_display_for_point (Rect.Point point);

    /**
     * Get the display containing a rect.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayForRect]]
     *
     * @param rect the rect to query.
     *
     * @return the instance ID of the display entirely containing the rect or
     * closest to the center of the rect on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_display_bounds
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayForRect")]
    public static DisplayID get_display_for_rect (Rect.Rect rect);

    /**
     * Get the display associated with a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayForWindow]]
     *
     * @param window the window to query.
     *
     * @return the instance ID of the display containing the center of the
     * window on success or 0 on failure; call {@link SDL.Error.get_error}
     * for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayForWindow")]
    public static DisplayID get_display_for_window (Window window);

    /**
     * Get the name of a display in UTF-8 encoding.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayName]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return the name of a display or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayName")]
    public static unowned string ? get_display_name (DisplayID display_id);

    /**
     * Get the properties associated with a display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayProperties]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return a valid property ID on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayProperties")]
    public static SDL.Properties.PropertiesID get_display_properties (DisplayID display_id);

    /**
     * Get a list of currently connected displays.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplays]]
     *
     * @return 0 terminated array of display instance IDs or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplays")]
    public static DisplayID[] ? get_displays ();

    /**
     * Get the usable desktop area represented by a display, in screen coordinates.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayUsableBounds]]
     *
     * @param display_id the instance ID of the display to query.
     * @param rect the {@link Rect.Rect} structure filled in with the display
     * bounds.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_display_bounds
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDisplayUsableBounds")]
    public static bool get_display_usable_bounds (DisplayID display_id, out Rect.Rect rect);

    /**
     * Get a list of fullscreen display modes available on a display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetFullscreenDisplayModes]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return a null terminated array of display mode pointers or null on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetFullscreenDisplayModes")]
    public static DisplayMode[] ? get_fullscreen_display_modes (DisplayID display_id);

    /**
     * Get the window that currently has an input grab enabled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGrabbedWindow]]
     *
     * @return the window if input is grabbed or null otherwise.
     *
     * @since 3.2.0
     *
     * @see set_window_mouse_grab
     * @see set_window_keyboard_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetGrabbedWindow")]
    public static Window ? get_grabbed_window ();

    /**
     * Get the orientation of a display when it is unrotated.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetNaturalDisplayOrientation]]
     *
     * @param display_id the instance ID of the display to query.
     *
     * @return the {@link DisplayOrientation} enum value of the display, or
     * {@link DisplayOrientation.UNKNOWN} if it isn't available.
     *
     * @since 3.2.0
     *
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetNaturalDisplayOrientation")]
    public static DisplayOrientation get_natural_display_orientation (DisplayID display_id);

    /**
     * Get the number of video drivers compiled into SDL.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetNumVideoDrivers]]
     *
     * @return the number of built in video drivers.
     *
     * @since 3.2.0
     *
     * @see get_video_driver
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetNumVideoDrivers")]
    public static int get_num_video_drivers ();

    /**
     * Return the primary display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPrimaryDisplay]]
     *
     * @return the instance ID of the primary display on success or 0 on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_displays
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetPrimaryDisplay")]
    public static DisplayID get_primary_display ();

    /**
     * Get the current system theme.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetSystemTheme]]
     *
     * @return the current system theme, light, dark, or unknown.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetSystemTheme")]
    public static SystemTheme get_sytem_theme ();

    /**
     * Get the name of a built in video driver.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetVideoDriver]]
     *
     * @param index the index of a video driver.
     *
     * @return the name of the video driver with the given index, or null if
     * index is out of bounds.
     *
     * @since 3.2.0
     *
     * @see get_num_video_drivers
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetVideoDriver")]
    public static unowned string get_video_driver (int index);

    /**
     * Get the aspect ratio of a window's client area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowAspectRatio]]
     *
     * @param window the window to query.
     * @param min_aspect a pointer filled in with the minimum aspect ratio of
     * the window, may be null.
     * @param min_aspect a pointer filled in with the minimum aspect ratio of
     * the window, may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_aspect_ratio
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowAspectRatio")]
    public static bool get_window_aspect_ratio (Window window,
            out float? min_aspect,
            out float? max_aspect);

    /**
     * Get the size of a window's borders (decorations) around the client
     * area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowBordersSize]]
     *
     * @param window the window to query.
     * @param top pointer to variable for storing the size of the top border;
     * null is permitted.
     * @param left pointer to variable for storing the size of the left
     * border; null is permitted.
     * @param bottom pointer to variable for storing the size of the bottom
     * border; null is permitted.
     * @param right pointer to variable for storing the size of the right
     * border; null is permitted.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowBordersSize")]
    public static bool get_window_borders_size (Window window,
            out int? top,
            out int? left,
            out int? bottom,
            out int? right);

    /**
     * Get the content display scale relative to a window's pixel size.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowDisplayScale]]
     *
     * @param window the window to query.
     *
     * @return the display scale, or 0.0f on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowDisplayScale")]
    public static float get_window_display_scale (Window window);

    /**
     * Get a window from a stored ID.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowFlags]]
     *
     * @param window the window to query.
     *
     * @return a mask of the {@link WindowFlags} associated with window.
     *
     * @since 3.2.0
     *
     * @see create_window
     * @see hide_window
     * @see maximize_window
     * @see minimize_window
     * @see set_window_fullscreen
     * @see set_window_mouse_grab
     * @see set_window_fill_document
     * @see show_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowFlags")]
    public static WindowFlags get_window_flags (Window window);

    /**
     * Get the window flags.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowFlags]]
     *
     * @param id the ID of the window.
     *
     * @return the window associated with id or null if it doesn't exist; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_id
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowFromID")]
    public static Window ? get_window_from_id (WindowID id);

    /**
     * Query the display mode to use when a window is visible at fullscreen.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowFullscreenMode]]
     *
     * @param window the window to query.
     *
     * @return a class to the exclusive fullscreen mode to use or null for
     * borderless fullscreen desktop mode.
     *
     * @since 3.2.0
     *
     * @see set_window_fullscreen_mode
     * @see set_window_fullscreen
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowFullscreenMode")]
    public static DisplayMode ? get_window_fullscreen_mode (Window window);

    /**
     * Get the raw ICC profile data for the screen the window is currently on.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowICCProfile]]
     *
     * @param window the window to query.
     * @param size the size of the ICC profile.
     *
     * @return the raw ICC profile data on success or NULL on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowICCProfile")]
    public static void * get_window_icc_profile (Window window, size_t size);

    /**
     * Get the numeric ID of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowID]]
     *
     * @param window the window to query.
     *
     * @return the the ID of the window on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_from_id
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowID")]
    public static WindowID get_window_id (Window window);

    /**
     * Get a window's keyboard grab mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowKeyboardGrab]]
     *
     * @param window the window to query.
     *
     * @return true if keyboard is grabbed, and false otherwise.
     *
     * @since 3.2.0
     *
     * @see set_window_keyboard_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowKeyboardGrab")]
    public static bool get_window_keyboard_grab (Window window);

    /**
     * Get the maximum size of a window's client area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowMaximumSize]]
     *
     * @param window the window to query.
     * @param w an out parameter filled in with the maximum width of the
     * window, may be null.
     * @param h an out parameter filled in with the maximum height of the
     * window, may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_minimum_size
     * @see set_window_maximum_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowMaximumSize")]
    public static bool get_window_maximum_size (Window window, out int ? w, out int ? h);

    /**
     * Get the minimum size of a window's client area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowMinimumSize]]
     *
     * @param window the window to query.
     * @param w an out parameter filled in with the minimum width of the
     * window, may be null.
     * @param h an out parameter filled in with the minimum height of the
     * window, may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_maximum_size
     * @see set_window_minimum_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowMinimumSize")]
    public static bool get_window_minimum_size (Window window, out int ? w, out int ? h);

    /**
     * Get a window's mouse grab mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowMouseGrab]]
     *
     * @param window the window to query.
     *
     * @return true if mouse is grabbed, and false otherwise.
     *
     * @since 3.2.0
     *
     * @see set_window_mouse_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowMouseGrab")]
    public static bool get_window_mouse_grab (Window window);

    /**
     * Get the mouse confinement rectangle of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowMouseRect]]
     *
     * @param window the window to query.
     *
     * @return a pointer to the mouse confinement rectangle of a window, or
     * null if there isn't one.
     *
     * @since 3.2.0
     *
     * @see set_window_mouse_rect
     * @see get_window_mouse_grab
     * @see set_window_mouse_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowMouseRect")]
    public static Rect.Rect ? get_window_mouse_rect (Window window);

    /**
     * Get the opacity of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowOpacity]]
     *
     * @param window the window to query.
     *
     * @return the opacity, (0.0f - transparent, 1.0f - opaque), or -1.0f on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_opacity
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowOpacity")]
    public static float get_window_opacity (Window window);

    /**
     * Get parent of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowParent]]
     *
     * @param window the window to query.
     *
     * @return the parent of the window on success or null if the window has
     * no parent.
     *
     * @since 3.2.0
     *
     * @see create_popup_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowParent")]
    public static Window ? get_window_parent (Window window);

    /**
     * Get parent of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowPixelDensity]]
     *
     * @param window the window to query.
     *
     * @return the pixel density or 0.0f on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_display_scale
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowPixelDensity")]
    public static float get_window_pixel_density (Window window);

    /**
     * Get parent of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowPixelFormat]]
     *
     * @param window the window to query.
     *
     * @return the pixel format of the window on success or
     * {Pixels.PixelFormat.UNKNOWN} on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_display_scale
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowPixelFormat")]
    public static Pixels.PixelFormat get_window_pixel_format (Window window);

    /**
     * Get the position of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowPosition]]
     *
     * @param window the window to query.
     * @param x an out parameter filled in with the x position of the window,
     * may be null.
     * @param y an out parameter filled in with the y position of the window,
     * may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowPosition")]
    public static bool get_window_position (Window window, out int x, out int y);

    /**
     * Get the state of the progress bar for the given window’s taskbar icon.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowProgressState]]
     *
     * @param window the window to query.
     *
     * @return the progress state, or {@link ProgressState} on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetWindowProgressState")]
    public static ProgressState get_window_progress_state (Window window);

    /**
     * Get the value of the progress bar for the given window’s taskbar icon.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowProgressValue]]
     *
     * @param window the window to query.
     *
     * @return the progress value in the range of [0.0f - 1.0f], or -1.0f on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetWindowProgressValue")]
    public static float get_window_progress_value (Window window);

    /**
     * Get the properties associated with a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowProperties]]
     *
     * @param window the window to query.
     *
     * @return a valid property ID on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowProperties")]
    public static SDL.Properties.PropertiesID get_window_properties (Window window);

    /**
     * Get a list of valid windows.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindows]]
     *
     * @return a null terminated array of {@link Window} classes or null on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindows")]
    public static unowned Window[] ? get_windows ();

    /**
     * Get the safe area for this window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowSafeArea]]
     *
     * @param window the window to query.
     * @param rect an out parameter filled in with the client area that is
     * safe for interactive content.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowSafeArea")]
    public static bool get_window_safe_area (Window window, out Rect.Rect rect);

    /**
     * Get the safe area for this window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowSize]]
     *
     * @param window the window to query.
     * @param w an out parameter filled in with the width of the window,
     * may be null.
     * @param h an out parameter filled in with the height of the window,
     * may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see Render.get_render_output_size
     * @see get_window_size_in_pixels
     * @see set_window_size
     * @see Events.EventType.WINDOW_RESIZED
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowSize")]
    public static bool get_window_size (Window window, out int w, out int h);

    /**
     * Get the size of a window's client area, in pixels.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowSizeInPixels]]
     *
     * @param window the window to query.
     * @param w an out parameter filled in with the width in pixels,
     * may be null.
     * @param h an out parameter filled in with the height in pixels,
     * may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_window
     * @see get_window_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowSizeInPixels")]
    public static bool get_window_size_in_pixels (Window window, out int w, out int h);

    /**
     * Get the SDL surface associated with the window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowSurface]]
     *
     * @param window the window to query.
     *
     * @return the surface associated with the window, or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see destroy_window_surface
     * @see window_has_surface
     * @see update_window_surface
     * @see update_window_surface_rects
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowSurface")]
    public static Surface.Surface ? get_window_surface (Window window);

    /**
     * Get VSync for the window surface.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowSurfaceVSync]]
     *
     * @param window the window to query.
     * @param vsync an int out parameter with the current vertical refresh
     * sync interval. {@link set_window_surface_vsync} for the meaning of
     * the value.
     *
     * @return the surface associated with the window, or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_surface_vsync
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowSurfaceVSync")]
    public static bool get_window_surface_vsync (Window window, out int vsync);

    /**
     * Get the title of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetWindowTitle]]
     *
     * @param window the window to query.
     *
     * @return the title of the window in UTF-8 format or "" if there is no
     * title.
     *
     * @since 3.2.0
     *
     * @see set_window_title
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetWindowTitle")]
    public static unowned string get_window_title (Window window);

    /**
     * Create an OpenGL context for an OpenGL window, and make it current.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_CreateContext]]
     *
     * @param window the window to associate with the context.
     *
     * @return the OpenGL context associated with window or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_destroy_context
     * @see gl_make_curent
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_CreateContext")]
    public static GLContext ? gl_create_context (Window window);

    /**
     * Delete an OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_DestroyContext]]
     *
     * @param context the OpenGL context to be deleted.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_create_context
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_DestroyContext")]
    public static bool gl_destroy_context (GLContext context);

    /**
     * Check if an OpenGL extension is supported for the current context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_ExtensionSupported]]
     *
     * @param extension the name of the extension to check.
     *
     * @return true if the extension is supported, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_ExtensionSupported")]
    public static bool gl_extension_supported (string extension);

    /**
     * Delete an OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_GetAttribute]]
     *
     * @param attr an {@link GLAttr} enum value specifying the OpenGL
     * attribute to get.
     * @param val an oout parameter filled in with the current value of attr.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_reset_attributes
     * @see gl_set_attribute
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_GetAttribute")]
    public static bool gl_get_attribute (GLAttr attr, out int val);

    /**
     * Get the currently active OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_GetCurrentContext]]
     *
     * @return the currently active OpenGL context or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_make_curent
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_GetCurrentContext")]
    public static GLContext ? gl_get_current_context ();

    /**
     * Get the currently active OpenGL window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_GetCurrentWindow]]
     *
     * @return the currently active OpenGL window on success or null on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_make_curent
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_GetCurrentWindow")]
    public static Window ? gl_get_current_window ();

    /**
     * Get an OpenGL function by name.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_GetProcAddress]]
     *
     * @param proc the name of an OpenGL function.
     *
     * @return a pointer to the named OpenGL function. The returned
     * pointer should be cast to the appropriate function signature.
     *
     * @since 3.2.0
     *
     * @see gl_extension_supported
     * @see gl_load_library
     * @see gl_unload_library
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_GetProcAddress")]
    public static StdInc.FunctionPointer gl_get_proc_address (string proc);

    /**
     * Get the swap interval for the current OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_GetSwapInterval]]
     *
     * @param interval an out parameter with the interval value. 0 if there is
     * no vertical retrace synchronization, 1 if the buffer swap is
     * synchronized with the vertical retrace, and -1 if late swaps happen
     * immediately instead of waiting for the next retrace.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_set_swap_interval
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_GetSwapInterval")]
    public static bool gl_get_swap_interval (out int interval);

    /**
     * Dynamically load an OpenGL library.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_LoadLibrary]]
     *
     * @param path the platform dependent OpenGL library name, or null to open
     * the default OpenGL library.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_get_proc_address
     * @see gl_unload_library
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_LoadLibrary")]
    public static bool gl_load_library (string ? path);

    /**
     * Set up an OpenGL context for rendering into an OpenGL window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_MakeCurrent]]
     *
     * @param window the window to associate with the context.
     * @param context the OpenGL context to associate with the window.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_create_context
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_MakeCurrent")]
    public static bool gl_make_curent (Window window, GLContext context);

    /**
     * Reset all previously set OpenGL context attributes to their default
     * values.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_ResetAttributes]]
     *
     * @since 3.2.0
     *
     * @see gl_get_attribute
     * @see gl_set_attribute
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_ResetAttributes")]
    public static void gl_reset_attributes ();

    /**
     * Set an OpenGL window attribute before window creation.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_SetAttribute]]
     *
     * @param attr an enum value specifying the OpenGL attribute to set.
     * @param val the desired value for the attribute.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_create_context
     * @see gl_get_attribute
     * @see gl_set_attribute
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_SetAttribute")]
    public static bool gl_set_attribute (GLAttr attr, int val);

    /**
     * Set the swap interval for the current OpenGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_SetSwapInterval]]
     *
     * @param interval 0 for immediate updates, 1 for updates synchronized
     * with the vertical retrace, -1 for adaptive vsync.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see gl_get_swap_interval
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_SetSwapInterval")]
    public static bool gl_set_swap_interval (int interval);

    /**
     * Update a window with OpenGL rendering.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_SwapWindow]]
     *
     * @param window the window to change.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_SwapWindow")]
    public static bool gl_swap_window (Window window);

    /**
     * Unload the OpenGL library previously loaded by {@link gl_load_library}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GL_UnloadLibrary]]
     *
     * @since 3.2.0
     *
     * @see gl_load_library
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GL_UnloadLibrary")]
    public static void gl_unload_library ();

    /**
     * Hide a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HideWindow]]
     *
     * @param window the window to hide.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see show_window
     * @see WindowFlags.HIDDEN
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HideWindow")]
    public static bool hide_window (Window window);

    /**
     * Request that the window be made as large as possible.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MaximizeWindow]]
     *
     * @param window the window to maximize.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see minimize_window
     * @see restore_window
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MaximizeWindow")]
    public static bool maximize_window (Window window);

    /**
     * Request that the window be minimized to an iconic representation.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MinimizeWindow]]
     *
     * @param window the window to minimize.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see maximize_window
     * @see restore_window
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MinimizeWindow")]
    public static bool minimize_window (Window window);

    /**
     * Request that a window be raised above other windows and gain the input
     * focus.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RaiseWindow]]
     *
     * @param window the window to raise.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RaiseWindow")]
    public static bool raise_window (Window window);

    /**
     * Request that the size and position of a minimized or maximized window
     * be restored.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RestoreWindow]]
     *
     * @param window the window to restore.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see maximize_window
     * @see minimize_window
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RestoreWindow")]
    public static bool restore_window (Window window);

    /**
     * Check whether the screensaver is currently enabled.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ScreenSaverEnabled]]
     *
     * @return true if the screensaver is enabled, false if it is disabled.
     *
     * @since 3.2.0
     *
     * @see disable_screensaver
     * @see enable_screensaver
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ScreenSaverEnabled")]
    public static bool screensaver_enabled ();

    /**
     * Set the window to always be above the others.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowAlwaysOnTop]]
     *
     * @param window the window of which to change the always on top state.
       @param on_top true to set the window always on top, false to disable.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_flags
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowAlwaysOnTop")]
    public static bool set_window_always_on_top (Window window, bool on_top);

    /**
     * Request that the aspect ratio of a window's client area be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowAspectRatio]]
     *
     * @param window the window to change.
     * @param min_aspect the minimum aspect ratio of the window, or 0.0f for
     * no limit.
     * @param max_aspect the maximum aspect ratio of the window, or 0.0f for
     * no limit.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_aspect_ratio
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowAspectRatio")]
    public static bool set_window_aspect_ratio (Window window, float min_aspect, float max_aspect);

    /**
     * Set the border state of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowBordered]]
     *
     * @param window the window of which to change the border state.
     * @param bordered false to remove border, true to add border.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_flags
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowBordered")]
    public static bool set_window_bordered (Window window, bool bordered);

    /**
     * Set the window to fill the current document space (Emscripten only).
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowFillDocument]]
     *
     * @param window the window of which to change the fill-document state.
     * @param fill true to set the window to fill the document, false to
     * disable.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see get_window_flags
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetWindowFillDocument")]
    public static bool set_window_fill_document (Window window, bool fill);

    /**
     * Set whether the window may have input focus.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowFocusable]]
     *
     * @param window the window to set focusable state.
     * @param focusable true to allow input focus, false to not allow input
     * focus.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowFocusable")]
    public static bool set_window_focusable (Window window, bool focusable);

    /**
     * Request that the window's fullscreen state be changed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowFullscreen]]
     *
     * @param window the window to change.
     * @param fullscreen true for fullscreen mode, false for windowed mode.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_fullscreen_mode
     * @see set_window_fullscreen_mode
     * @see sync_window
     * @see WindowFlags.FULLSCREEN
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowFullscreen")]
    public static bool set_window_fullscreen (Window window, bool fullscreen);

    /**
     * Set the display mode to use when a window is visible and fullscreen.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowFullscreenMode]]
     *
     * @param window the window to affect.
     * @param mode a class to the display mode to use, which can be null for
     * borderless fullscreen desktop mode, or one of the fullscreen modes
     * returned by {@link get_fullscreen_display_modes} to set an exclusive
     * fullscreen mode.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_fullscreen_mode
     * @see set_window_fullscreen
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowFullscreenMode")]
    public static bool set_window_fullscreen_mode (Window window, DisplayMode? mode);

    /**
     * Provide a callback that decides if a window region has special
     * properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowHitTest]]
     *
     * @param window the window to set hit-testing on.
     * @param callback the function to call when doing a hit-test.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowHitTest", has_target = true)]
    public static bool set_window_hit_test (Window window, HitTest? callback);

    /**
     * Set the icon for a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowFullscreenMode]]
     *
     * @param window the window to change.
     * @param icon an {@link Surface.Surface} structure containing the icon
     * for the window.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see Surface.add_surface_alternate_image
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowIcon")]
    public static bool set_window_icon (Window window, Surface.Surface icon);

    /**
     * Set a window's keyboard grab mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowKeyboardGrab]]
     *
     * @param window the window for which the keyboard grab mode should be set.
     * @param grabbed true to grab keyboard, and false to release.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_keyboard_grab
     * @see set_window_keyboard_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowKeyboardGrab")]
    public static bool set_window_keyboard_grab (Window window, bool grabbed);

    /**
     * Set the maximum size of a window's client area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowMaximumSize]]
     *
     * @param window the window to change.
     * @param max_w the maximum width of the window, or 0 for no limit.
     * @param max_h the maximum height of the window, or 0 for no limit.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_maximum_size
     * @see set_window_minimum_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowMaximumSize")]
    public static bool set_window_maximum_size (Window window, int max_w, int max_h);

    /**
     * Set the minimum size of a window's client area.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowMinimumSize]]
     *
     * @param window the window to change.
     * @param min_w the minium width of the window, or 0 for no limit.
     * @param min_h the minium height of the window, or 0 for no limit.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_minimum_size
     * @see set_window_maximum_size
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowMinimumSize")]
    public static bool set_window_minimum_size (Window window, int min_w, int min_h);

    /**
     * Toggle the state of the window as modal.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowModal]]
     *
     * @param window the window to change.
     * @param modal true to toggle modal status on, false to toggle it off.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_parent
     * @see WindowFlags.MODAL
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowModal")]
    public static bool set_window_modal (Window window, bool modal);

    /**
     * Set a window's mouse grab mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowMouseGrab]]
     *
     * @param window the window for which the mouse grab mode should be set.
     * @param grabbed true to grab mouse, and false to release.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_mouse_rect
     * @see set_window_mouse_rect
     * @see set_window_keyboard_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowMouseGrab")]
    public static bool set_window_mouse_grab (Window window, bool grabbed);

    /**
     * Confines the cursor to the specified area of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowMouseRect]]
     *
     * @param window the window that will be associated with the barrier.
     * @param rect a rectangle area in window-relative coordinates. If null
     * the barrier for the specified window will be destroyed.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_mouse_rect
     * @see get_window_mouse_grab
     * @see set_window_mouse_grab
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowMouseRect")]
    public static bool set_window_mouse_rect (Window window, Rect.Rect? rect);

    /**
     * Set the opacity for a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowOpacity]]
     *
     * @param window the window which will be made transparent or opaque.
     * @param opacity the opacity value (0.0f - transparent, 1.0f - opaque).
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_opacity
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowOpacity")]
    public static bool set_window_opacity (Window window, float opacity);

    /**
     * Set the window as a child of a parent window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowParent]]
     *
     * @param window the window that should become the child of a parent.
     * @param parent the new parent window for the child window.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_modal
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowParent")]
    public static bool set_window_parent (Window window, Window? parent);

    /**
     * Request that the window's position be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowPosition]]
     *
     * @param window the window to reposition.
     * @param x the x coordinate of the window, or {@link WINDOW_POS_CENTERED}
     * or {@link WINDOW_POS_UNDEFINED}.
     * @param y the y coordinate of the window, or {@link WINDOW_POS_CENTERED}
     * or {@link WINDOW_POS_UNDEFINED}.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_position
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowPosition")]
    public static bool set_window_position (Window window, int x, int y);

    /**
     * Request that the window's position be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowProgressState]]
     *
     * @param window the window whose progress state is to be modified.
     * @param state the progress state. {@link ProgressState.NONE} stops
     * displaying the progress bar.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetWindowProgressState")]
    public static bool set_window_progress_state (Window window, ProgressState state);

    /**
     * Request that the window's position be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowProgressValue]]
     *
     * @param window the window whose progress value is to be modified.
     * @param val the progress value in the range of [0.0f - 1.0f]. If the
     * value is outside the valid range, it gets clamped.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetWindowProgressValue")]
    public static bool set_window_progress_value (Window window, float val);

    /**
     * Set the user-resizable state of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowResizable]]
     *
     * @param window the window of which to change the resizable state.
     * @param resizable true to allow resizing, false to disallow.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_flags
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowResizable")]
    public static bool set_window_resizable (Window window, bool resizable);

    /**
     * Set the shape of a transparent window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowShape]]
     *
     * @param window the window.
     * @param shape the surface representing the shape of the window, or null
     * to remove any current shape.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowShape")]
    public static bool set_window_shape (Window window, Surface.Surface? shape);

    /**
     * Request that the size of a window's client area be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowSize]]
     *
     * @param window the window to change.
     * @param w the width of the window, must be > 0.
     * @param h the height of the window, must be > 0.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_size
     * @see set_window_fullscreen_mode
     * @see sync_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowSize")]
    public static bool set_window_size (Window window, int w, int h);

    /**
     * Request that the size of a window's client area be set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowSurfaceVSync]]
     *
     * @param window the window.
     * @param vsync the vertical refresh sync interval.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_surface_vsync
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowSurfaceVSync")]
    public static bool set_window_surface_vsync (Window window, int vsync);

    /**
     * Set the title of a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowTitle]]
     *
     * @param window the window to change.
     * @param title the desired window title in UTF-8 format.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_title
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowTitle")]
    public static bool set_window_title (Window window, string title);

    /**
     * Show a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowWindow]]
     *
     * @param window the window to show.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see hide_window
     * @see raise_window
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowWindow")]
    public static bool show_window (Window window);

    /**
     * Display the system-level window menu.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowWindowSystemMenu]]
     *
     * @param window the window for which the menu will be displayed.
     * @param x the x coordinate of the menu, relative to the origin
     * (top-left) of the client area.
     * @param y the y coordinate of the menu, relative to the origin
     * (top-left) of the client area.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowWindowSystemMenu")]
    public static bool show_window_system_menu (Window window, int x, int y);

    /**
     * Block until any pending window state is finalized.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SyncWindow]]
     *
     * @param window the window for which to wait for the pending state to
     * be applied.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see set_window_size
     * @see set_window_position
     * @see set_window_fullscreen
     * @see minimize_window
     * @see maximize_window
     * @see restore_window
     * @see SDL.Hints.VIDEO_SYNC_WINDOW_OPERATIONS
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SyncWindow")]
    public static bool sync_window (Window window);

    /**
     * Copy the window surface to the screen.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_UpdateWindowSurface]]
     *
     * @param window the window to update.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_surface
     * @see update_window_surface_rects
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_UpdateWindowSurface")]
    public static bool update_window_surface (Window window);

    /**
     * Copy the window surface to the screen.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_UpdateWindowSurfaceRects]]
     *
     * @param window the window to update.
     * @param rects an array of {@link Rect.Rect} structures representing
     * areas of the surface to copy, in pixels.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_window_surface
     * @see update_window_surface
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_UpdateWindowSurfaceRects")]
    public static bool update_window_surface_rects (Window window, Rect.Rect[] rects);

    /**
     * Return whether the window has a surface associated with it.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WindowHasSurface]]
     *
     * @param window the window to query.
     *
     * @return true if there is a surface associated with the window,
     * or false otherwise.
     *
     * @since 3.2.0
     *
     * @see get_window_surface
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WindowHasSurface")]
    public static bool window_has_surface (Window window);

    /**
     * This is a unique ID for a display for the time it is connected to the
     * system, and is never reused for the lifetime of the application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DisplayID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_DisplayID", has_type_id = false)]
    public struct DisplayID : uint32 {}

    /**
     * Internal display mode data.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DisplayModeData]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_DisplayModeData", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class DisplayModeData {}

    /**
     * An EGL attribute, used when creating an EGL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLAttrib]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_EGLAttrib", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class EGLAttrib {}

    /**
     * EGL platform attribute initialization callback.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLAttribArrayCallback]]
     *
     * @return a newly-allocated array of attributes, terminated with
     * EGL_NONE.
     *
     * @since 3.2.0
     *
     * @see egl_set_attribute_callbacks
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGLAttribArrayCallback", has_target = true)]
    public delegate EGLAttrib EGLAttribArrayCallback ();

    /**
     * Opaque type for an EGL config.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLConfig]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_EGLConfig", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class EGLConfig {}

    /**
     * Opaque type for an EGL display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLDisplay]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_EGLDisplay", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class EGLDisplay {}

    /**
     * An EGL integer attribute, used when creating an EGL surface.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLDisplay]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_EGLint", has_type_id = false)]
    public struct EGLint : int {}

    /**
     * EGL platform attribute initialization callback.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLIntArrayCallback]]
     *
     * @param display the EGL display to be used.
     * @param config the EGL config to be used.
     *
     * @return a newly-allocated array of attributes, terminated with
     * EGL_NONE.
     *
     * @since 3.2.0
     *
     * @see egl_set_attribute_callbacks
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_EGLIntArrayCallback", has_target = true, instance_pos = 0)]
    public delegate EGLint[] EGLIntArrayCallback (EGLDisplay display, EGLConfig config);

    /**
     * Opaque type for an EGL surface.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_EGLSurface]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_EGLSurface", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class EGLSurface {}

    /**
     * Opaque type for a GL context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLContext]]
     *
     * @since 3.2.0
     *
     * @see gl_create_context
     * @see gl_set_attribute
     * @see gl_make_curent
     * @see gl_destroy_context
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_GLContext", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GLContext {}

    /**
     * Possible flags to be set for the {@link GLAttr.CONTEXT_FLAGS}
     * attribute.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLContextFlag]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "int", cprefix = "SDL_GL_CONTEXT_", has_type_id = false)]
    public enum GLContextFlag {
        DEBUG_FLAG,
        FORWARD_COMPATIBLE_FLAG,
        ROBUST_ACCESS_FLAG,
        RESET_ISOLATION_FLAG
    } // GLContextFlag

    /**
     * Possible flags to be set for the {@link GLAttr.CONTEXT_RELEASE_BEHAVIOR}
     * attribute.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLContextReleaseFlag]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "int", cprefix = "SDL_GL_CONTEXT_RELEASE_", has_type_id = false)]
    public enum GLContextReleaseFlag {
        BEHAVIOR_NONE,
        BEHAVIOR_FLUSH,
    } // GlContextReleaseFlag

    /**
     * Possible flags to be set for the
     * {@link GLAttr.CONTEXT_RESET_NOTIFICATION} attribute.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLContextResetNotification]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "int", cprefix = "SDL_GL_CONTEXT_RESET_", has_type_id = false)]
    public enum GLContextResetNotification {
        NO_NOTIFICATION,
        LOSE_CONTEXT
    } // GLContextResetNotification

    /**
     * Possible flags to be set for the {@link GLAttr.CONTEXT_PROFILE_MASK}
     * attribute.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLProfile]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "int", cprefix = "SDL_GL_CONTEXT_PROFILE_", has_type_id = false)]
    public enum GLProfile {
    /**
     * OpenGL Core Profile context
     *
     */
        CORE,

        /**
         * OpenGL Compatibility Profile context
         *
         */
        COMPATIBILITY,

        /**
         * GLX_CONTEXT_ES2_PROFILE_BIT_EXT
         *
         */
        ES,
    } // GLProfile

    /**
     * Callback used for hit-testing.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HitTest]]
     *
     * @param win the {@link Window} where hit-testing was set on.
     * @param area an {@link Rect.Point} which should be hit-tested.
     *
     * @return a {@link HitTestResult} value.
     *
     * @since 3.2.0
     *
     * @see set_window_hit_test
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HitTest", has_target = true)]
    public delegate HitTestResult HitTest (Window win, Rect.Point area);

    /**
     * The struct used as an opaque handle to a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Window]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_Window", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Window {}

    /**
     * The flags on a window.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WindowFlags]]
     *
     * @since 3.2.0
     */
    [Flags, CCode (cname = "int", cprefix = "SDL_WINDOW_")]
    public enum WindowFlags {
    /**
     * Window is in fullscreen window at desktop resolution.
     *
     */
        FULLSCREEN,

        /**
         * Window is usable with an OpenGL context.
         *
         */
        OPENGL,

        /**
         * Window is occluded.
         *
         */
        OCCLUDED,

        /**
         * Window is neither mapped onto the desktop nor shown in the
         * taskbar/dock/window list; {@link show_window} is required for it to
         * become visible.
         *
         */
        HIDDEN,

        /**
         * No window decoration.
         *
         */
        BORDERLESS,

        /**
         * Window can be resized.
         *
         */
        RESIZABLE,

        /**
         * Window is minimized.
         *
         */
        MINIMIZED,

        /**
         * Window is maximized.
         *
         */
        MAXIMIZED,

        /**
         * Window has grabbed mouse focus.
         *
         */
        MOUSE_GRABBED,

        /**
         * Window has input focus.
         *
         */
        INPUT_FOCUS,

        /**
        * Window has mouse focus.
        *
        */
        MOUSE_FOCUS,

        /**
         * Window not created by SDL.
         *
         */
        EXTERNAL,

        /**
         * Window is modal.
         *
         */
        MODAL,

        /**
         * Window uses high pixel density back buffer if possible.
         *
         */
        HIGH_PIXEL_DENSITY,

        /**
         * Window has mouse captured (unrelated to
         * {@link WindowFlags.MOUSE_GRABBED}).
         *
         */
        MOUSE_CAPTURE,

        /**
         * Window has relative mode enabled.
         *
         */
        MOUSE_RELATIVE_MODE,

        /**
         * Window should always be above others
         *
         */
        ALWAYS_ON_TOP,

        /**
         * Window should be treated as a utility window, not showing in the
         * task bar and window list.
         *
         */
        UTILITY,

        /**
         * Window should be treated as a tooltip and does not get mouse or
         * keyboard focus, requires a parent window.
         *
         */
        TOOLTIP,

        /**
         * Window should be treated as a popup menu, requires a parent
         * window.
         *
         */
        POPUP_MENU,

        /**
         * Window has grabbed keyboard input.
         *
         */
        KEYBOARD_GRABBED,

        /**
         * Window is in fill-document mode (Emscripten only).
         *
         */
        [Version (since = "3.4.0")]
        FILL_DOCUMENT,

        /**
         * Window is usable with a Vulkan instance.
         *
         */
        VULKAN,

        /**
         * Window is usable with a Metal instance.
         *
         */
        METAL,

        /**
         * Window with transparent buffer.
         *
         */
        TRANSPARENT,

        /**
         * Window should not be focusable.
         *
         */
        NOT_FOCUSABLE,
    } // WindowFlags

    /**
     * This is a unique ID for a window.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_WindowID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_WindowID", has_type_id = false)]
    public struct WindowID : uint32 {}

    /**
     * The structure that defines a display mode.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_DisplayMode]]
     *
     * @since 3.2.0
     *
     * @see get_fullscreen_display_modes
     * @see get_desktop_display_mode
     * @see get_current_display_mode
     * @see set_window_fullscreen_mode
     * @see get_window_fullscreen_mode
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_DisplayMode", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class DisplayMode {
        /**
         * The display this mode is associated with.
         *
         */
        public DisplayID display_id;

        /**
         * Pixel format.
         *
         */
        public Pixels.PixelFormat format;

        /**
         * Width.
         *
         */
        public int w;

        /**
         * Height.
         *
         */
        public int h;

        /**
         * Scale converting size to pixels (e.g. a 1920x1080 mode with 2.0
         * scale would have 3840x2160 pixels)
         *
         */
        public float pixel_density;

        /**
         * Refresh rate (or 0.0f for unspecified).
         *
         */
        public float refresh_rate;

        /**
         * Precise refresh rate numerator (or 0 for unspecified).
         *
         */
        public int refresh_rate_numerator;

        /**
         * Precise refresh rate denominator.
         *
         */
        public int refresh_rate_denominator;

        /**
         * For private use.
         *
         */
        [CCode (cname = "internal")]
        public DisplayModeData internal_data;
    } // DisplayMode

    /**
     * Display orientation values; the way a display is rotated.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DisplayOrientation]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DisplayOrientation", cprefix = "SDL_ORIENTATION_", has_type_id = false)]
    public enum DisplayOrientation {
    /**
     * The display orientation can't be determined
     *
     */
        UNKNOWN,

        /**
         * The display is in landscape mode, with the right side up, relative
         * to portrait mode
         *
         */
        LANDSCAPE,

        /**
         * The display is in landscape mode, with the left side up, relative
         * to portrait mode
         *
         */
        LANDSCAPE_FLIPPED,

        /**
         * The display is in portrait mode
         *
         */
        PORTRAIT,

        /**
         * The display is in portrait mode, upside down
         *
         */
        PORTRAIT_FLIPPED,
    } // DisplayOrientation

    /**
     * Window flash operation.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FlashOperation]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FlashOperation", cprefix = "SDL_FLASH_", has_type_id = false)]
    public enum FlashOperation {
    /**
     * Cancel any window flash state
     *
     */
        CANCEL,

        /**
         * Flash the window briefly to get attention
         *
         */
        BRIEFLY,

        /**
         * Flash the window until it gets focus
         *
         */
        UNTIL_FOCUSED,
    } // FlashOperation

    /**
     * An enumeration of OpenGL configuration attributes.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GLAttr]]
     *
     * @since 3.2.0
     *
     * @see gl_get_attribute
     * @see gl_set_attribute
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GLAttr", cprefix = "SDL_GL_", has_type_id = false)]
    public enum GLAttr {
    /**
     * The minimum number of bits for the red channel of the color
     * buffer; defaults to 8.
     *
     */
        RED_SIZE,

        /**
         * The minimum number of bits for the green channel of the color
         * buffer; defaults to 8.
         *
         */
        GREEN_SIZE,

        /**
         * The minimum number of bits for the blue channel of the color
         * buffer; defaults to 8.
         *
         */
        BLUE_SIZE,

        /**
         * The minimum number of bits for the alpha channel of the color
         * buffer; defaults to 8.
         *
         */
        ALPHA_SIZE,

        /**
         * The minimum number of bits for frame buffer size; defaults to 0.
         *
         */
        BUFFER_SIZE,

        /**
         * Whether the output is single or double buffered; defaults to double
         * buffering on.
         *
         */
        [CCode (cname = "SDL_GL_DOUBLEBUFFER")]
        DOUBLE_BUFFER,

        /**
         * The minimum number of bits in the depth buffer; defaults to 16.
         *
         */
        DEPTH_SIZE,

        /**
         * The minimum number of bits in the stencil buffer; defaults to 0.
         *
         */
        STENCIL_SIZE,

        /**
         * The minimum number of bits for the red channel of the accumulation
         * buffer; defaults to 0.
         *
         */
        ACCUM_RED_SIZE,

        /**
         * The minimum number of bits for the green channel of the accumulation
         * buffer; defaults to 0.
         *
         */
        ACCUM_GREEN_SIZE,

        /**
         * The minimum number of bits for the blue channel of the accumulation
         * buffer; defaults to 0.
         *
         */
        ACCUM_BLUE_SIZE,

        /**
         * The minimum number of bits for the alpha channel of the accumulation
         * buffer; defaults to 0.
         *
         */
        ACCUM_ALPHA_SIZE,

        /**
         * Whether the output is stereo 3D; defaults to off.
         *
         */
        STEREO,

        /**
         * The number of buffers used for multisample anti-aliasing; defaults
         * to 0.
         *
         */
        [CCode (cname = "SDL_GL_MULTISAMPLEBUFFERS")]
        MULTISAMPLE_BUFFERS,

        /**
         * The number of samples used around the current pixel used for
         * multisample anti-aliasing.
         *
         */
        [CCode (cname = "SDL_GL_MULTISAMPLESAMPLES")]
        MULTISAMPLE_SAMPLES,

        /**
         * Set to 1 to require hardware acceleration, set to 0 to force
         * software rendering; defaults to allow either.
         *
         */
        ACCELERATED_VISUAL,

        /**
         * Not used.
         *
         */
        [Version (deprecated = true)]
        RETAINED_BACKING,

        /**
         * OpenGL context major version.
         *
         */
        CONTEXT_MAJOR_VERSION,

        /**
         * OpenGL context minor version.
         *
         */
        CONTEXT_MINOR_VERSION,

        /**
         * Some combination of 0 or more of elements of the
         * {@link GLContextFlag} enumeration; defaults to 0.
         *
         */
        CONTEXT_FLAGS,

        /**
         * Type of GL context (Core, Compatibility, ES). See
         * {@link GLProfile}; default value depends on platform.
         *
         */
        CONTEXT_PROFILE_MASK,

        /**
         * OpenGL context sharing; defaults to 0.
         *
         */
        SHARE_WITH_CURRENT_CONTEXT,

        /**
         * Requests sRGB-capable visual if 1. Defaults to -1 ("don't care").
         * This is a request; GL drivers might not comply!
         *
         */
        FRAMEBUFFER_SRGB_CAPABLE,

        /**
         * Sets context the release behavior. See
         * {@link GLContextReleaseFlag}; defaults to
         * {@link GLContextReleaseFlag.BEHAVIOR_FLUSH}.
         *
         */
        CONTEXT_RELEASE_BEHAVIOR,

        /**
         * Set context reset notification. See
         * {@link GLContextResetNotification};
         * defaults to {@link GLContextResetNotification.NO_NOTIFICATION}.
         *
         */
        CONTEXT_RESET_NOTIFICATION,

        /**
         * No error context
         *
         */
        CONTEXT_NO_ERROR,

        /**
         * Float buffers
         *
         */
        FLOATBUFFERS,

        /**
         * EGL platform
         *
         */
        EGL_PLATFORM,
    } // GLAttr

    /**
     * Possible return values from the {@link HitTest} callback.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HitTestResult]]
     *
     * @since 3.2.0
     *
     * @see HitTest
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HitTestResult", cprefix = "SDL_HITTEST_", has_type_id = false)]
    public enum HitTestResult {
    /**
     * Region is normal. No special properties.
     *
     */
        NORMAL,

        /**
         * Region can drag entire window.
         *
         */
        DRAGGABLE,

        /**
         * Region is the resizable top-left corner border.
         *
         */
        [CCode (cname = "SDL_HITTEST_RESIZE_TOPLEFT")]
        RESIZE_TOP_LEFT,

        /**
         * Region is the resizable top border.
         *
         */
        RESIZE_TOP,

        /**
         * Region is the resizable top-right corner border.
         *
         */
        [CCode (cname = "SDL_HITTEST_RESIZE_TOPRIGHT")]
        RESIZE_TOP_RIGHT,

        /**
         * Region is the resizable right border.
         *
         */
        RESIZE_RIGHT,

        /**
         * Region is the resizable bottom-right corner border.
         *
         */
        [CCode (cname = "SDL_HITTEST_RESIZE_BOTTOMRIGHT")]
        RESIZE_BOTTOM_RIGHT,

        /**
         * Region is the resizable bottom border.
         *
         */
        [CCode (cname = "SDL_HITTEST_RESIZE_BOTTOM")]
        RESIZE_BOTTOM,

        /**
         * Region is the resizable bottom-left corner border.
         *
         */
        [CCode (cname = "SDL_HITTEST_RESIZE_BOTTOMLEFT")]
        RESIZE_BOTTOM_LEFT,

        /**
         * Region is the resizable left border.
         *
         */
        RESIZE_LEFT,
    } // HitTestResult

    /**
     * Possible return values from the {@link HitTest} callback.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ProgressState]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_ProgressState", cprefix = "SDL_PROGRESS_STATE_", has_type_id = false)]
    public enum ProgressState {
    /**
     * An invalid progress state indicating an error; check
     * {@link SDL.Error.get_error} for more information.
     *
     */
        INVALID,

        /**
         * No progress bar is shown.
         *
         */
        NONE,

        /**
         * The progress bar is shown in a indeterminate state.
         *
         */
        INDETERMINATE,

        /**
         * The progress bar is shown in a normal state.
         *
         */
        NORMAL,

        /**
         * The progress bar is shown in a paused state.
         *
         */
        PAUSED,

        /**
         * The progress bar is shown in a state indicating the application
         * had an error.
         *
         */
        ERROR,
    } // ProgressState

    /**
     * System theme.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_SystemTheme]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SystemTheme", cprefix = "SDL_SYSTEM_THEME_", has_type_id = false)]
    public enum SystemTheme {
    /**
     * Unknown system theme
     *
     */
        UNKNOWN,

        /**
         * Light colored system theme
         *
         */
        LIGHT,

        /**
         * Dark colored system theme
         *
         */
        DARK,
    } // SDL_SystemTheme;

    /**
     * Used to indicate that the window position should be centered.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_CENTERED]]
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_CENTERED")]
    public const int WINDOW_POS_CENTERED;

    /**
     * Used to indicate that the window position should be centered.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_CENTERED]]
     *
     * @param display_id the {@link DisplayID} of the display to use.
     *
     * @return the appropiate flag value to center the window in the display.
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_CENTERED_DISPLAY")]
    public static int window_pos_centered_display (DisplayID display_id);

    /**
     * A magic value used with {@link WINDOW_POS_CENTERED}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_CENTERED]]
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_CENTERED_MASK")]
    public const int WINDOW_POS_CENTERED_MASK;

    /**
     * A macro to test if the window position is marked as "centered."
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_ISCENTERED]]
     *
     * @param val the window position value.
     *
     * @return true if the window is marked as "centered", false otherwise.
     *
     * @since 3.2.0
     *
     * @see get_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_ISCENTERED")]
    public static bool window_pos_is_centered (int val);

    /**
     * A macro to test if the window position is marked as "undefined."
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_ISUNDEFINED]]
     *
     * @param val the window position value.
     *
     * @return true if the window is marked as "undefined", false otherwise.
     *
     * @since 3.2.0
     *
     * @see get_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_ISUNDEFINED")]
    public static bool windows_pos_is_undefined (int val);

    /**
     * Used to indicate that you don't care what the window position is.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_ISUNDEFINED]]
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_UNDEFINED")]
    public const int WINDOW_POS_UNDEFINED;

    /**
     * Used to indicate that you don't care what the window position is.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_UNDEFINED_DISPLAY]]
     *
     * @param display_id the {@link DisplayID} of the display to use.
     *
     * @return The appropiate flag indicating undefined position for the disaply
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_UNDEFINED_DISPLAY")]
    public static int window_pos_undefined_display (DisplayID display_id);

    /**
     * A magic value used with {@link WINDOW_POS_UNDEFINED}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WINDOWPOS_UNDEFINED_MASK]]
     *
     * @since 3.2.0
     *
     * @see set_window_position
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOWPOS_UNDEFINED_MASK")]
    public const uint32 WINDOW_POS_UNDEFINED_MASK;

    /**
     * A constant indicating that VSync is disabled
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowSurfaceVSync]]
     *
     * @since 3.2.0
     *
     * @see set_window_surface_vsync
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOW_SURFACE_VSYNC_DISABLED")]
    public const int WINDOW_SURFACE_VSYNC_DISABLED;

    /**
     * A constant indicating that VSync is adaptative
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowSurfaceVSync]]
     *
     * @since 3.2.0
     *
     * @see set_window_surface_vsync
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE")]
    public const int WINDOW_SURFACE_VSYNC_ADAPTIVE;

    /**
     * Global Video Properties
     *
     */
    namespace PropGlobalVideo {
        /**
         * The pointer to the global wl_display object used by the Wayland
         * video backend.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER")]
        public const string WAYLAND_WL_DISPLAY_POINTER;
    } // PropGlobalVideo

    /**
     * Window creation properties for {@link create_window_with_properties}
     *
     */
    namespace PropWindowCreate {
        /**
         * True if the window should be always on top.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_ALWAYS_ON_TOP_BOOLEAN")]
        public const string ALWAYS_ON_TOP_BOOLEAN;

        /**
         * True if the window has no window decoration.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_BORDERLESS_BOOLEAN:")]
        public const string BORDERLESS_BOOLEAN;

        /**
         * True if the "tooltip" and "menu" window types should be
         * automatically constrained to be entirely within display bounds
         * (default), false if no constraints on the position are desired.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_CONSTRAIN_POPUP_BOOLEAN")]
        public const string CONSTRAIN_POPUP_BOOLEAN;

        /**
         * True if the window will be used with an externally managed graphics
         * context.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_EXTERNAL_GRAPHICS_CONTEXT_BOOLEAN")]
        public const string EXTERNAL_GRAPHICS_CONTEXT_BOOLEAN;

        /**
         * True if the window should accept keyboard input (defaults true).
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_FOCUSABLE_BOOLEAN")]
        public const string FOCUSABLE_BOOLEAN;

        /**
         * True if the window should start in fullscreen mode at desktop
         * resolution.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_FULLSCREEN_BOOLEAN")]
        public const string FULLSCREEN_BOOLEAN;

        /**
         * The height of the window.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER")]
        public const string HEIGHT_NUMBER;

        /**
         * True if the window should start hidden.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN")]
        public const string HIDDEN_BOOLEAN;

        /**
         * True if the window uses a high pixel density buffer if possible.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN")]
        public const string HIGH_PIXEL_DENSITY_BOOLEAN;

        /**
         * True if the window should start maximized.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_MAXIMIZED_BOOLEAN")]
        public const string MAXIMIZED_BOOLEAN;

        /**
         * True if the window is a popup menu.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_MENU_BOOLEAN")]
        public const string MENU_BOOLEAN;

        /**
         * True if the window will be used with Metal rendering.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_METAL_BOOLEAN")]
        public const string METAL_BOOLEAN;

        /**
         * True if the window should start minimized.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_MINIMIZED_BOOLEAN")]
        public const string MINIMIZED_BOOLEAN;

        /**
         * True if the window is modal to its parent.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_MODAL_BOOLEAN")]
        public const string MODAL_BOOLEAN;

        /**
         * True if the window starts with grabbed mouse focus.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_MOUSE_GRABBED_BOOLEAN")]
        public const string MOUSE_GRABBED_BOOLEAN;

        /**
         * True if the window will be used with OpenGL rendering.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_OPENGL_BOOLEAN")]
        public const string OPENGL_BOOLEAN;

        /**
         * A {@link Video.Window} that will be the parent of this window,
         * required for windows with the "tooltip", "menu", and "modal"
         * properties.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_PARENT_POINTER")]
        public const string PARENT_POINTER;

        /**
         * True if the window should be resizable.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN")]
        public const string RESIZABLE_BOOLEAN;

        /**
         * The title of the window, in UTF-8 encoding.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_TITLE_STRING")]
        public const string TITLE_STRING;

        /**
         * True if the window show transparent in the areas with alpha of 0.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_TRANSPARENT_BOOLEAN")]
        public const string TRANSPARENT_BOOLEAN;

        /**
         * True if the window is a tooltip
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_TOOLTIP_BOOLEAN")]
        public const string TOOLTIP_BOOLEAN;

        /**
         * True if the window is a utility window, not showing in the task bar
         * and window list.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_UTILITY_BOOLEAN")]
        public const string UTILITY_BOOLEAN;

        /**
         * True if the window will be used with Vulkan rendering.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_VULKAN_BOOLEAN")]
        public const string VULKAN_BOOLEAN;

        /**
         * The width of the window.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER")]
        public const string WIDTH_NUMBER;

        /**
         * The x position of the window, or {@link WINDOW_POS_CENTERED},
         * defaults to {@link WINDOW_POS_UNDEFINED}. This is relative to the
         * parent for windows with the "tooltip" or "menu" property set.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_X_NUMBER")]
        public const string X_NUMBER;

        /**
         * The y position of the window, or {@link WINDOW_POS_CENTERED},
         * defaults to {@link WINDOW_POS_UNDEFINED}. This is relative to the
         * parent for windows with the "tooltip" or "menu" property set.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_Y_NUMBER")]
        public const string Y_NUMBER;

        /// MacOS

        /**
         * The (unsafe_unretained) NSWindow associated with the window,
         * if you want to wrap an existing window.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER")]
        public const string COCOA_WINDOW_POINTER;

        /**
         * The (unsafe_unretained) NSView associated with the window,
         * defaults to ``[window contentView]``
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_COCOA_VIEW_POINTER")]
        public const string COCOA_VIEW_POINTER;

        /// iOS, tvOS, visionOS

        /**
         * The (unsafe_unretained) UIWindowScene associated with the window,
         * defaults to the active window scene.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WINDOWSCENE_POINTER")]
        public const string WINDOWSCENE_POINTER;

        /// Wayland

        /**
         * True if the application wants to use the Wayland surface for a
         * custom role and does not want it attached to an XDG toplevel window.
         * See README-wayland for more information on using custom surfaces.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN")]
        public const string WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN;

        /**
         * True if the application wants an associated wl_egl_window object to
         * be created and attached to the window, even if the window does not
         * have the OpenGL property or {@link WindowFlags.OPENGL} flag set.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WAYLAND_CREATE_EGL_WINDOW_BOOLEAN")]
        public const string WAYLAND_CREATE_EGL_WINDOW_BOOLEAN;

        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WAYLAND_WL_SURFACE_POINTER")]
        public const string WAYLAND_WL_SURFACE_POINTER;

        /// Windows

        /**
         * The HWND associated with the window, if you want to wrap an
         * existing window.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WIN32_HWND_POINTER")]
        public const string WIN32_HWND_POINTER;

        /**
         * Optional, another window to share pixel format with, useful for
         * OpenGL windows.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_WIN32_PIXEL_FORMAT_HWND_POINTER")]
        public const string WIN32_PIXEL_FORMAT_HWND_POINTER;

        /// X11

        /**
         * The X11 Window associated with the window, if you want to wrap an
         * existing window.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_X11_WINDOW_NUMBER")]
        public const string X11_WINDOW_NUMBER;

        /// Emscriptem

        /**
         * The id given to the canvas element. This should start with a '#'
         * sign.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_EMSCRIPTEN_CANVAS_ID_STRING")]
        public const string EMSCRIPTEN_CANVAS_ID_STRING;

        /**
         * Override the binding element for keyboard inputs for this canvas.
         *
         * The variable can be one of:
         * * "#window": the javascript window object (default)
         * * "#document": the javascript document object
         * * "#screen": the javascript window.screen object
         * * "#canvas": the WebGL canvas element
         * * "#none": Don't bind anything at all
         *
         * Any other string without a leading # sign applies to the element on
         * the page with that ID. Windows with the "tooltip" and "menu"
         * properties are popup windows and have the behaviors and guidelines
         * outlined in {@link Video.create_popup_window}
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateWindowWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_CREATE_EMSCRIPTEN_KEYBOARD_ELEMENT_STRING")]
        public const string EMSCRIPTEN_KEYBOARD_ELEMENT_STRING;
    } // ProWindowCreate

    /**
     * Properties associcated with a display.
     * Aquired via {@link get_display_properties}
     *
     */
    namespace PropDisplay {
        /**
         * True if the display has HDR headroom above the SDR white point.
         *
         * This is for informational and diagnostic purposes only, as not all
         * platforms provide this information at the display level.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_DISPLAY_HDR_ENABLED_BOOLEAN")]
        public const string HDR_ENABLED_BOOLEAN;

        /// KMS/DRM

        /**
         * The "panel orientation" property for the display in degrees of
         * clockwise rotation.
         *
         * Note that this is provided only as a hint, and the application is
         * responsible for any coordinate transformations needed to conform
         * to the requested display orientation.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_DISPLAY_KMSDRM_PANEL_ORIENTATION_NUMBER")]
        public const string KMSDRM_PANEL_ORIENTATION_NUMBER;

        /// Wayland

        /**
         * The wl_output associated with the display.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_DISPLAY_WAYLAND_WL_OUTPUT_POINTER")]
        public const string WAYLAND_WL_OUTPUT_POINTER;

        /// Windows

        /**
         * The monitor handle (HMONITOR) associated with the display.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDisplayProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_DISPLAY_WINDOWS_HMONITOR_POINTER")]
        public const string WINDOWS_HMONITOR_POINTER;
    } // PropDisplay

    namespace PropWindow {
        /**
         * The surface associated with a shaped window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_SHAPE_POINTER")]
        public const string SHAPE_POINTER;

        /**
         * True if the window has HDR headroom above the SDR white point.
         *
         * This property can change dynamically when
         * {@link Events.EventType.WINDOW_HDR_STATE_CHANGED} is sent.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_HDR_ENABLED_BOOLEAN")]
        public const string HDR_ENABLED_BOOLEAN;

        /**
         * The value of SDR white in the {@link Pixels.ColorSpace.SRGB_LINEAR}
         * colorspace.
         *
         * On Windows this corresponds to the SDR white level in scRGB
         * colorspace, and on Apple platforms this is always 1.0 for EDR
         * content. This property can change dynamically when
         * {@link Events.EventType.WINDOW_HDR_STATE_CHANGED} is sent.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_SDR_WHITE_LEVEL_FLOAT")]
        public const string SDR_WHITE_LEVEL_FLOAT;

        /**
         * The additional high dynamic range that can be displayed, in terms
         * of the SDR white point.
         *
         * When HDR is not enabled, this will be 1.0. This property can change
         * dynamically when {@link Events.EventType.WINDOW_HDR_STATE_CHANGED}
         * is sent.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_HDR_HEADROOM_FLOAT")]
        public const string HDR_HEADROOM_FLOAT;

        /// Android

        /**
         * The ANativeWindow associated with the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER")]
        public const string ANDROID_WINDOW_POINTER;

        /**
         * The EGLSurface associated with the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_ANDROID_SURFACE_POINTER")]
        public const string ANDROID_SURFACE_POINTER;

        /// iOS

        /**
         * The (unsafe_unretained) UIWindow associated with the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER")]
        public const string UIKIT_WINDOW_POINTER;

        /**
         * The NSInteger tag associated with metal views on the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_UIKIT_METAL_VIEW_TAG_NUMBER")]
        public const string UIKIT_METAL_VIEW_TAG_NUMBER;

        /**
         * The OpenGL view's framebuffer object. It must be bound when
         * rendering to the screen using OpenGL.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_UIKIT_OPENGL_FRAMEBUFFER_NUMBER")]
        public const string UIKIT_OPENGL_FRAMEBUFFER_NUMBER;

        /**
         * The OpenGL view's renderbuffer object. It must be bound when
         * {@link Video.gl_swap_window} is called.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_UIKIT_OPENGL_RENDERBUFFER_NUMBER")]
        public const string UIKIT_OPENGL_RENDERBUFFER_NUMBER;

        /**
         * The OpenGL view's resolve framebuffer, when MSAA is used.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_UIKIT_OPENGL_RESOLVE_FRAMEBUFFER_NUMBER")]
        public const string UIKIT_OPENGL_RESOLVE_FRAMEBUFFER_NUMBER;

        /// KMS/DRM

        /**
         * The device index associated with the window (e.g. the X in
         * /dev/dri/cardX)
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_KMSDRM_DEVICE_INDEX_NUMBER")]
        public const string KMSDRM_DEVICE_INDEX_NUMBER;

        /**
         * The DRM FD associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_KMSDRM_DRM_FD_NUMBER")]
        public const string KMSDRM_DRM_FD_NUMBER;

        /**
         * The GBM device associated with the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_KMSDRM_GBM_DEVICE_POINTER")]
        public const string KMSDRM_GBM_DEVICE_POINTER;

        /// macOS

        /**
         * The (unsafe_unretained) NSWindow associated with the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_COCOA_WINDOW_POINTER")]
        public const string COCOA_WINDOW_POINTER;

        /**
         * The NSInteger tag associated with metal views on the window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_COCOA_METAL_VIEW_TAG_NUMBER")]
        public const string COCOA_METAL_VIEW_TAG_NUMBER;

        /// OpenVR

        /**
         * The OpenVR Overlay Handle ID for the associated overlay window.
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_OPENVR_OVERLAY_ID_NUMBER")]
        public const string OPENVR_OVERLAY_ID_NUMBER;

        /// Vivante

        /**
         * The EGLNativeDisplayType associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_VIVANTE_DISPLAY_POINTER")]
        public const string VIVANTE_DISPLAY_POINTER;

        /**
         * The EGLNativeWindowType associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_VIVANTE_WINDOW_POINTER")]
        public const string VIVANTE_WINDOW_POINTER;

        /**
         * The EGLSurface associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_VIVANTE_SURFACE_POINTER")]
        public const string VIVANTE_SURFACE_POINTER;

        /// Windows

        /**
         * The HWND associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WIN32_HWND_POINTER")]
        public const string WIN32_HWND_POINTER;

        /**
         * The HDC associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WIN32_HDC_POINTER")]
        public const string WIN32_HDC_POINTER;

        /**
         * The HINSTANCE associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER")]
        public const string WIN32_INSTANCE_POINTER;

        /// Wayland

        /**
         * The wl_display associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER")]
        public const string WAYLAND_DISPLAY_POINTER;

        /**
         * The wl_surface associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER")]
        public const string WAYLAND_SURFACE_POINTER;

        /**
         * The wp_viewport associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_VIEWPORT_POINTER")]
        public const string WAYLAND_VIEWPORT_POINTER;

        /**
         * The wl_egl_window associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_EGL_WINDOW_POINTER")]
        public const string WAYLAND_EGL_WINDOW_POINTER;

        /**
         * The xdg_surface associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_XDG_SURFACE_POINTER")]
        public const string WAYLAND_XDG_SURFACE_POINTER;

        /**
         * The xdg_toplevel role associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_XDG_TOPLEVEL_POINTER")]
        public const string WAYLAND_XDG_TOPLEVEL_POINTER;

        /**
         * The export handle associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_XDG_TOPLEVEL_EXPORT_HANDLE_STRING")]
        public const string WAYLAND_XDG_TOPLEVEL_EXPORT_HANDLE_STRING;

        /**
         * The xdg_popup role associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_XDG_POPUP_POINTER")]
        public const string WAYLAND_XDG_POPUP_POINTER;

        /**
         * The xdg_positioner associated with the window, in popup mode
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_WAYLAND_XDG_POSITIONER_POINTER")]
        public const string WAYLAND_XDG_POSITIONER_POINTER;

        /// X11

        /**
         * The X11 Display associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_X11_DISPLAY_POINTER")]
        public const string X11_DISPLAY_POINTER;

        /**
         * The screen number associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_X11_SCREEN_NUMBER")]
        public const string X11_SCREEN_NUMBER;

        /**
         * The X11 Window associated with the window
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_WINDOW_X11_WINDOW_NUMBER")]
        public const string X11_WINDOW_NUMBER;

        /// Emscriptem

        /**
         * The id the canvas element will have
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_EMSCRIPTEN_CANVAS_ID_STRING")]
        public const string WINDOW_EMSCRIPTEN_CANVAS_ID_STRING;

        /**
         * The keyboard element that associates keyboard events to this window
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_WINDOW_EMSCRIPTEN_KEYBOARD_ELEMENT_STRING")]
        public const string EMSCRIPTEN_KEYBOARD_ELEMENT_STRING;
    } // PropWindow
} // SDL.Video

///
/// 2D Accelerated Rendering (SDL_render.h)
///
[CCode (cheader_filename = "SDL3/SDL_render.h")]
namespace SDL.Render {
    [CCode (cname = "SDL_AddVulkanRenderSemaphores")]
    public static bool add_vulkan_render_semaphores (Renderer renderer,
            uint32 wait_stage_mask,
            int64 wait_semaphore,
            int64 signal_semaphore);

    [CCode (cname = "SDL_ConvertEventToRenderCoordinates")]
    public static bool convert_event_to_render_coordinates (Renderer renderer,
            ref Events.Event event);

    /**
     * Create a 2D GPU rendering context.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPURenderer]]
     *
     * @param device the GPU device to use with the renderer, or null to
     * create a device.
     * @param window the window where rendering is displayed, or null to
     * create an offscreen renderer.
     *
     * @return a valid rendering context or null if there was an error; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see create_renderer_with_properties
     * @see get_gpu_renderer_device
     * @see GPU.create_gpu_shader
     * @see create_gpu_render_state
     * @see set_gpu_render_state
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_CreateGPURenderer")]
    public static Renderer ? create_gpu_renderer (GPU.GPUDevice device, Video.Window window);

    /**
     * Create custom GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPURenderState]]
     *
     * @param renderer the renderer to use.
     * @param create_info a struct describing the GPU render state to create.
     *
     * @return a custom GPU render state or NULL on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see set_gpu_render_state_fragment_uniforms
     * @see set_gpu_render_state
     * @see destroy_gpu_render_state
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_CreateGPURenderState")]
    public static GPURenderState ? create_gpu_render_state (Renderer renderer,
            GPURenderStateCreateInfo create_info);

    [CCode (cname = "SDL_CreateRenderer")]
    public static Renderer ? create_renderer (Video.Window window, string? name);

    [CCode (cname = "SDL_CreateRendererWithProperties")]
    public static Renderer ? create_renderer_with_properties (SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_CreateSoftwareRenderer")]
    public static Renderer ? create_software_renderer (Surface.Surface surface);

    [CCode (cname = "SDL_CreateTexture")]
    public static Texture ? create_texture (Renderer renderer,
            Pixels.PixelFormat format,
            TextureAccess access,
            int w,
            int h);

    [CCode (cname = "SDL_CreateTextureFromSurface")]
    public static Texture ? create_texture_from_surface (Renderer renderer,
            Surface.Surface surface);

    [CCode (cname = "SDL_CreateTextureWithProperties")]
    public static Texture ? create_texture_with_properties (Renderer renderer,
            SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_CreateWindowAndRenderer")]
    public static bool create_window_and_renderer (string title,
            int width,
            int height,
            Video.WindowFlags window_flags,
            out Video.Window? window,
            out Renderer? renderer);

    /**
     * Destroy custom GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DestroyGPURenderState]]
     *
     * @param state the state to destroy.
     *
     * @since 3.4.0
     *
     * @see create_gpu_render_state
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_DestroyGPURenderState")]
    public static void destroy_gpu_render_state (GPURenderState state);

    [CCode (cname = "SDL_DestroyRenderer")]
    public static void destroy_renderer (Renderer renderer);

    [CCode (cname = "SDL_DestroyTexture")]
    public static void destroy_texture (Texture texture);

    [CCode (cname = "SDL_FlushRenderer")]
    public static bool flush_renderer (Renderer renderer);

    [CCode (cname = "SDL_GetCurrentRenderOutputSize")]
    public static bool get_current_render_output_size (Renderer renderer, out int w, out int h);

    /**
     * Get default texture scale mode of the given renderer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDefaultTextureScaleMode]]
     *
     * @param renderer the renderer to get data from.
     * @param scale_mode a {@link Surface.ScaleMode} filled with current default
     * scale mode. See {@link set_default_texture_scale_mode} for the meaning
     * of the value.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
    * @see set_default_texture_scale_mode
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetDefaultTextureScaleMode")]
    public static bool get_default_texture_scale_mode (Renderer renderer,
            out Surface.ScaleMode scale_mode);

    /**
     * Return the GPU device used by a renderer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPURendererDevice]]
     *
     * @param renderer the rendering context.
     *
     * @return the GPU device used by the renderer, or nullif the renderer is
     * not a GPU renderer; call {@link SDL.Error.get_error} for more
     * information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetGPURendererDevice")]
    public static GPU.GPUDevice ? get_gpu_renderer_device (Renderer renderer);

    [CCode (cname = "SDL_GetNumRenderDrivers")]
    public static int get_num_render_drivers ();

    [CCode (cname = "SDL_GetRenderClipRect")]
    public static bool get_render_clip_rect (Renderer renderer, out Rect.Rect rect);

    [CCode (cname = "SDL_GetRenderColorScale")]
    public static bool get_render_color_scale (Renderer renderer, out float scale);

    [CCode (cname = "SDL_GetRenderDrawBlendMode")]
    public static bool get_render_draw_blend_mode (Renderer renderer,
            out BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_GetRenderDrawColor")]
    public static bool get_render_draw_color (Renderer renderer,
            out uint8 r,
            out uint8 g,
            out uint8 b,
            out uint8 a);

    [CCode (cname = "SDL_GetRenderDrawColorFloat")]
    public static bool get_render_draw_color_float (Renderer renderer,
            out float r,
            out float g,
            out float b,
            out float a);

    [CCode (cname = "SDL_GetRenderDriver")]
    public static unowned string ? get_render_driver (int index);

    [CCode (cname = "SDL_GetRenderer")]
    public static Renderer ? get_renderer (Video.Window window);

    [CCode (cname = "SDL_GetRendererFromTexture")]
    public static Renderer ? get_renderer_from_texture (Texture texture);

    [CCode (cname = "SDL_GetRendererName")]
    public static unowned string ? get_renderer_name (Renderer renderer);

    [CCode (cname = "SDL_GetRendererProperties")]
    public static SDL.Properties.PropertiesID get_renderer_properties (Renderer renderer);

    [CCode (cname = "SDL_GetRenderLogicalPresentation")]
    public static bool get_render_logical_presentation (Renderer renderer,
            out int w,
            out int h,
            out RendererLogicalPresentation mode);

    [CCode (cname = "SDL_GetRenderLogicalPresentationRect")]
    public static bool get_render_logical_presentation_rect (Renderer renderer,
            out Rect.FRect? rect);

    [CCode (cname = "SDL_GetRenderMetalCommandEncoder")]
    public static void * get_render_metal_command_encoder (Renderer renderer);

    [CCode (cname = "SDL_GetRenderMetalLayer")]
    public static void * get_render_metal_layer (Renderer renderer);

    [CCode (cname = "SDL_GetRenderOutputSize")]
    public static bool get_render_output_size (Renderer renderer, out int w, out int h);

    [CCode (cname = "SDL_GetRenderSafeArea")]
    public static bool get_render_safe_area (Renderer renderer, out Rect.Rect rect);

    [CCode (cname = "SDL_GetRenderScale")]
    public static bool get_render_scale (Renderer renderer, out float scale_x, out float scale_y);

    [CCode (cname = "SDL_GetRenderTarget")]
    public static Texture ? get_render_target (Renderer renderer);

    /**
     * Get the texture addressing mode used in {@link render_geometry}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetRenderTextureAddressMode]]
     *
     * @param renderer the rendering context.
     * @param u_mode an out parameter filled in with the
     * {@link TextureAddressMode} to use for horizontal texture coordinates
     * in {@link render_geometry}, may be null.
     * @param v_mode an out parameter filled in with the
     * {@link TextureAddressMode} to use for vertical texture coordinates
     * in {@link render_geometry}, may be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see set_render_texture_address_mode
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetRenderTextureAddressMode")]
    public static bool get_render_texture_address_mode (Renderer renderer,
            out TextureAddressMode ? u_mode,
            out TextureAddressMode ? v_mode);

    [CCode (cname = "SDL_GetRenderViewport")]
    public static bool get_render_viewport (Renderer renderer, out Rect.Rect rect);

    [CCode (cname = "SDL_GetRenderVSync")]
    public static bool get_render_vsync (Renderer renderer, out int vsync);

    [CCode (cname = "SDL_GetRenderWindow")]
    public static Video.Window ? get_render_window (Renderer renderer);

    [CCode (cname = "SDL_GetTextureAlphaMod")]
    public static bool get_texture_alpha_mod (Texture texture, out uint8 alpha);

    [CCode (cname = "SDL_GetTextureAlphaModFloat")]
    public static bool get_texture_alpha_mod_float (Texture texture, out float alpha);

    [CCode (cname = "SDL_GetTextureBlendMode")]
    public static bool get_texture_blend_mode (Texture texture,
            out BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_GetTextureColorMod")]
    public static bool get_texture_color_mod (Texture texture,
            out uint8 r,
            out uint8 g,
            out uint8 b);

    [CCode (cname = "SDL_GetTextureColorModFloat")]
    public static bool get_texture_color_mod_float (Texture texture,
            out float r,
            out float g,
            out float b);

    /**
     * Get the palette used by a texture.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetTexturePalette]]
     *
     * @param texture the texture to query.
     *
     * @return a pointer to the palette used by the texture, or null if there
     * is no palette used.
     *
     * @since 3.4.0
     *
     * @see set_texture_palette
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetTexturePalette")]
    public static Pixels.Palette get_texture_palette (Texture texture);

    [CCode (cname = "SDL_GetTextureProperties")]
    public static SDL.Properties.PropertiesID get_texture_properties (Texture texture);

    [CCode (cname = "SDL_GetTextureScaleMode")]
    public static bool get_texture_scale_mode (Texture* texture, out Surface.ScaleMode scale_mode);

    [CCode (cname = "SDL_GetTextureSize")]
    public static bool get_texture_size (Texture texture, out float w, out float h);

    [CCode (cname = "SDL_LockTexture")]
    public static bool lock_texture (Texture texture,
            Rect.Rect? rect,
            out void* pixels,
            out int pitch);

    [CCode (cname = "SDL_LockTextureToSurface")]
    public static bool lock_texture_to_surface (Texture texture,
            Rect.Rect? rect,
            out Surface.Surface surface);

    [CCode (cname = "SDL_RenderClear")]
    public static bool render_clear (Renderer renderer);

    [CCode (cname = "SDL_RenderClipEnabled")]
    public static bool render_clip_enabled (Renderer renderer);

    [CCode (cname = "SDL_RenderCoordinatesFromWindow")]
    public static bool render_coordinates_from_window (Renderer renderer,
            float window_x,
            float window_y,
            out float x,
            out float y);

    [CCode (cname = "SDL_RenderCoordinatesToWindow")]
    public static bool render_coordinates_to_window (Renderer renderer,
            float x,
            float y,
            out float window_x,
            out float window_y);

    [CCode (cname = "SDL_RenderDebugText")]
    public static bool render_debug_text (Renderer renderer, float x, float y, string str);

    [PrintfFormat]
    [CCode (cname = "SDL_RenderDebugTextFormat", sentinel = "")]
    public static bool render_debug_text_format (Renderer renderer,
            float x,
            float y,
            string format,
            ...);

    [CCode (cname = "SDL_RenderFillRect")]
    public static bool render_fill_rect (Renderer renderer, Rect.FRect rect);

    [CCode (cname = "SDL_RenderFillRects")]
    public static bool render_fill_rects (Renderer renderer, Rect.FRect[] rects);

    [CCode (cname = "SDL_RenderGeometry")]
    public static bool render_geometry (Renderer renderer,
            Texture? texture,
            Vertex[] vertices,
            int[]? indices);

    [CCode (cname = "SDL_RenderGeometryRaw")]
    public static bool render_geometry_raw (Renderer renderer,
            Texture? texture,
            [CCode (array_length = false)] float[] xy,
            int xy_stride,
            [CCode (array_length = false)] Pixels.FColor[] color,
            int color_stride,
            [CCode (array_length = false)] float[] uv,
            int uv_stride,
            int num_vertices,
            [CCode (array_length = false)] void* indices,
            int size_indices);

    [CCode (cname = "SDL_RenderLine")]
    public static bool render_line (Renderer renderer, float x1, float y1, float x2, float y2);

    [CCode (cname = "SDL_RenderLines")]
    public static bool render_lines (Renderer renderer, Rect.FPoint[] points);

    [CCode (cname = "SDL_RenderPoint")]
    public static bool render_point (Renderer renderer, float x, float y);

    [CCode (cname = "SDL_RenderPoints")]
    public static bool render_points (Renderer renderer, Rect.FPoint[] points);

    [CCode (cname = "SDL_RenderPresent")]
    public static bool render_present (Renderer renderer);

    [CCode (cname = "SDL_RenderReadPixels")]
    public static Surface.Surface ? render_read_pixels (Renderer renderer, Rect.Rect ? rect);

    [CCode (cname = "SDL_RenderRect")]
    public static bool render_rect (Renderer renderer, Rect.FRect rect);

    [CCode (cname = "SDL_RenderRects")]
    public static bool render_rects (Renderer renderer, Rect.FRect[] rects);

    [CCode (cname = "SDL_RenderTexture")]
    public static bool render_texture (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            Rect.FRect? dst_rect);

    [CCode (cname = "SDL_RenderTexture9Grid")]
    public static bool render_texture_9grid (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            float left_width,
            float right_width,
            float top_height,
            float bottom_height,
            float scale,
            Rect.FRect? dst_rect);

    /**
     * Perform a scaled copy using the 9-grid algorithm to the current
     * rendering target at subpixel precision.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RenderTexture9GridTiled]]
     *
     * @param renderer the renderer which should copy parts of a texture.
     * @param texture the source texture.
     * @param src_rect the {@link Rect.Rect} structure representing the
     * rectangle to be used for the 9-grid, or null to use the entire texture.
     * @param left_width the width, in pixels, of the left corners in src_rect.
     * @param right_width the width, in pixels, of the right corners in
     * src_rect.
     * @param top_height the height, in pixels, of the top corners in src_rect.
     * @param bottom_height the height, in pixels, of the bottom corners in
     * src_rect.
     * @param scale the scale used to transform the corner of srcrect into the
     * corner of dst_rect, or 0.0f for an unscaled copy.
     * @param dst_rect a pointer to the destination rectangle, or null for the
     * entire rendering target.
     * @param tile_scale the scale used to transform the borders and center of
     * src_rect into the borders and middle of dstrect, or 1.0f for an
     * unscaled copy.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see render_texture
     * @see render_texture_9grid
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_RenderTexture9GridTiled")]
    public static bool render_texture_9grid_tiled (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            float left_width,
            float right_width,
            float top_height,
            float bottom_height,
            float scale,
            Rect.FRect? dst_rect,
            float tile_scale);

    [CCode (cname = "SDL_RenderTextureAffine")]
    public static bool render_texture_affine (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            Rect.FPoint? origin,
            Rect.FPoint? right,
            Rect.FPoint? down);

    [CCode (cname = "SDL_RenderTextureRotated")]
    public static bool render_texture_rotated (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            Rect.FRect? dst_rect,
            double angle,
            Rect.FPoint? center,
            Surface.FlipMode flip);

    [CCode (cname = "SDL_RenderTextureTiled")]
    public static bool render_texture_tiled (Renderer renderer,
            Texture texture,
            Rect.FRect? src_rect,
            float scale,
            Rect.FRect? dst_rect);

    [CCode (cname = "SDL_RenderViewportSet")]
    public static bool render_viewport_set (Renderer renderer);

    /**
     * Set default scale mode for new textures for given renderer.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetDefaultTextureScaleMode]]
     *
     * @param renderer the renderer to get data from.
     * @param scale_mode the scale mode to change to for new textures.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see get_default_texture_scale_mode
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetDefaultTextureScaleMode")]
    public static bool set_default_texture_scale_mode (Renderer renderer,
            Surface.ScaleMode scale_mode);

    /**
     * Set custom GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetGPURenderState]]
     *
     * @param renderer the renderer to use.
     * @param state the state to to use, or null to clear custom GPU render
     * state.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetGPURenderState")]
    public static bool set_gpu_render_state (Renderer renderer, GPURenderState state);

    /**
     * Set fragment shader uniform variables in a custom GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetGPURenderStateFragmentUniforms]]
     *
     * @param state the state to modify.
     * @param slot_index the fragment uniform slot to* push data to.
     * @param data client data to write.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetGPURenderStateFragmentUniforms")]
    public static bool set_gpu_render_state_fragment_uniforms (GPURenderState state,
            uint32 slot_index,
            uint8[] data);

    [CCode (cname = "SDL_SetRenderClipRect")]
    public static bool set_render_clip_rect (Renderer renderer, Rect.Rect? rect);

    [CCode (cname = "SDL_SetRenderColorScale")]
    public static bool set_render_color_scale (Renderer renderer, float scale);

    [CCode (cname = "SDL_SetRenderDrawBlendMode")]
    public static bool set_render_draw_blend_mode (Renderer renderer,
            BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_SetRenderDrawColor")]
    public static bool set_render_draw_color (Renderer renderer,
            uint8 r,
            uint8 g,
            uint8 b,
            uint8 a);

    [CCode (cname = "SDL_SetRenderDrawColorFloat")]
    public static bool set_render_draw_color_float (Renderer renderer,
            float r,
            float g,
            float b,
            float a);

    [CCode (cname = "SDL_SetRenderLogicalPresentation")]
    public static bool set_render_logical_presentation (Renderer renderer,
            int w,
            int h,
            RendererLogicalPresentation mode);

    [CCode (cname = "SDL_SetRenderScale")]
    public static bool set_render_scale (Renderer renderer, float scale_x, float scale_y);

    [CCode (cname = "SDL_SetRenderTarget")]
    public static bool set_render_target (Renderer renderer, Texture? texture);

    /**
     * Set the texture addressing mode used in {@link render_geometry}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetRenderTextureAddressMode]]
     *
     * @param renderer the rendering context.
     * @param u_mode the {@link TextureAddressMode} to use for horizontal
     * texture coordinates in {@link render_geometry}.
     * @param v_mode the {@link TextureAddressMode} to use for vertical
     * texture coordinates {@link render_geometry}.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see render_geometry
     * @see render_geometry_raw
     * @see get_render_texture_address_mode
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetRenderTextureAddressMode")]
    public static bool set_render_texture_address_mode (Renderer renderer,
            TextureAddressMode u_mode,
            TextureAddressMode v_mode);

    [CCode (cname = "SDL_SetRenderViewport")]
    public static bool set_render_viewport (Renderer renderer, Rect.Rect? rect);

    [CCode (cname = "SDL_SetRenderVSync")]
    public static bool set_render_vsync (Renderer renderer, int vsync);

    [CCode (cname = "SDL_SetTextureAlphaMod")]
    public static bool set_texture_alpha_mod (Texture texture, uint8 alpha);

    [CCode (cname = "SDL_SetTextureAlphaMod")]
    public static bool set_texture_alpha_mod_float (Texture texture, float alpha);

    [CCode (cname = "SDL_SetTextureBlendMode")]
    public static bool set_texture_blend_mode (Texture texture, BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_SetTextureColorMod")]
    public static bool set_texture_color_mod (Texture texture, uint8 r, uint8 g, uint8 b);

    [CCode (cname = "SDL_SetTextureColorModFloat")]
    public static bool set_texture_color_mod_float (Texture texture, float r, float g, float b);

    /**
     * Set the palette used by a texture.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetTexturePalette]]
     *
     * @param texture the texture to update.
     * @param palette the {@link Pixels.Palette} structure to use.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see get_texture_palette
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetTexturePalette")]
    public static bool set_texture_palette (Texture texture, Pixels.Palette palette);

    [CCode (cname = "SDL_SetTextureScaleMode")]
    public static bool set_texture_scale_mode (Texture texture, Surface.ScaleMode scale_mode);

    [CCode (cname = "SDL_UnlockTexture")]
    public static void unlock_texture (Texture texture);

    [CCode (cname = "SDL_UpdateNVTexture")]
    public static bool update_nv_texture (Texture texture,
            Rect.Rect? rect,
            uint8 y_plane,
            int y_pitch,
            uint8 uv_plane,
            int uv_pitch);

    [CCode (cname = "SDL_UpdateTexture")]
    public static bool update_texture (Texture texture,
            Rect.Rect? rect,
            void* pixels,
            int pitch);

    [CCode (cname = "SDL_UpdateYUVTexture")]
    public static bool update_yuv_texture (Texture texture,
            Rect.Rect? rect,
            uint8 y_plane,
            int y_pitch,
            uint8 u_plane,
            int u_pitch,
            uint8 v_plane,
            int v_pitch);

    /**
     * A custom GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPURenderState]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [Compact, CCode (cname = "SDL_GPURenderState", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPURenderState {}

    [Compact, CCode (cname = "SDL_Renderer", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Renderer {}

    /**
     * A structure specifying the parameters of a GPU render state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPURenderStateCreateInfo]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GPURenderStateCreateInfo", has_type_id = false)]
    public struct GPURenderStateCreateInfo {
    /**
     * The fragment shader to use when this render state is active.
     *
     */
        public GPU.GPUShader fragment_shader;

    /**
     * Additional fragment samplers to bind when this render state is
     * active.
     *
     */
        [CCode (array_length_cname = "num_sampler_bindings", array_length_type = "Sint32")]
        public GPU.GPUTextureSamplerBinding[] sampler_bindings;

    /**
     * Storage textures to bind when this render state is active.
     *
     */
        [CCode (array_length_cname = "num_storage_textures", array_length_type = "Sint32")]
        public GPU.GPUTexture[] storage_textures;

    /**
     * Storage buffers to bind when this render state is active.
     *
     */
        [CCode (array_length_cname = "num_storage_buffers", array_length_type = "Sint32")]
        public GPU.GPUBuffer[] storage_buffers;

    /**
     * A properties ID for extensions. Should be 0 if no extensions are
     * needed.
     *
     */
        public SDL.Properties.PropertiesID props;
    } // GPURenderStateCreateInfo

    /**
     * GPU render state description.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPURenderStateDesc]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GPURenderStateDesc", has_type_id = false)]
    public struct GPURenderStateCreateDesc {
    /**
     * The fragment shader to use when this render state is active.
     *
     */
        public uint32 version;

    /**
     * Additional fragment samplers to bind when this render state is
     * active.
     *
     */
        [CCode (array_length_cname = "num_sampler_bindings", array_length_type = "Sint32")]
        public GPU.GPUTextureSamplerBinding[] sampler_bindings;

    /**
     * Storage textures to bind when this render state is active.
     *
     */
        [CCode (array_length_cname = "num_storage_textures", array_length_type = "Sint32")]
        public GPU.GPUTexture[] storage_textures;

    /**
     * Storage buffers to bind when this render state is active.
     *
     */
        [CCode (array_length_cname = "num_storage_buffers", array_length_type = "Sint32")]
        public GPU.GPUBuffer[] storage_buffers;
    } // GPURenderStateCreateDesc

    [Compact, CCode (cname = "SDL_Texture", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Texture {
        public Pixels.PixelFormat format;
        public int w;
        public int h;
        public int refcount;
    }

    [CCode (cname = "SDL_Vertex", has_type_id = false)]
    public struct Vertex {
        public Rect.FPoint position;
        public Pixels.FColor color;
        public Rect.FPoint tex_coord;
    } // Vertex

    [CCode (cname = "SDL_RendererLogicalPresentation", cprefix = "SDL_LOGICAL_PRESENTATION_",
    has_type_id = false)]
    public enum RendererLogicalPresentation {
        DISABLED,
        STRETCH,
        LETTERBOX,
        OVERSCAN,
        INTEGER_SCALE,
    } // RendererLogicalPresentation

    [CCode (cname = "SDL_TextureAccess", cprefix = "SDL_TEXTUREACCESS_", has_type_id = false)]
    public enum TextureAccess {
        STATIC,
        STREAMING,
        TARGET,
    } // TextureAccess

    /**
     * The addressing mode for a texture when used in {@link render_geometry}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_TextureAddressMode]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_TextureAddressMode", cprefix = "SDL_TEXTURE_ADDRESS_",
    has_type_id = false)]
    public enum TextureAddressMode {
    /**
     * Invalid
     *
     */
        INVALID,

        /**
         * Wrapping is enabled if texture coordinates are outside [0, 1],
         * this is the default.
         *
         */
        AUTO,

        /**
         * Texture coordinates are clamped to the [0, 1] range
         *
         */
        CLAMP,

        /**
         * The texture is repeated (tiled)
         *
         */
        WRAP,
    } // TextureAddressMode

    [CCode (cname = "SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE")]
    public const int DEBUG_TEXT_FONT_CHARACTER_SIZE;

    [CCode (cname = "SDL_SOFTWARE_RENDERER")]
    public const string SOFTWARE_RENDERER;

    [CCode (cname = "SDL_RENDERER_VSYNC_DISABLED")]
    public const int RENDERER_VSYNC_DISABLED;

    [CCode (cname = "SDL_RENDERER_VSYNC_ADAPTIVE")]
    public const int RENDERER_VSYNC_ADAPTIVE;

    namespace PropRendererCreate {
        [CCode (cname = "SDL_PROP_RENDERER_CREATE_NAME_STRING")]
        public const string NAME_STRING;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_WINDOW_POINTER")]
        public const string WINDOW_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_SURFACE_POINTER")]
        public const string SURFACE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_OUTPUT_COLORSPACE_NUMBER")]
        public const string OUTPUT_COLORSPACE_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER")]
        public const string PRESENT_VSYNC_NUMBER;

        // GPU Renderer

        /**
         * The device to use with the renderer, optional.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_CREATE_GPU_DEVICE_POINTER")]
        public const string GPU_DEVICE_POINTER;

        /**
         * The app is able to provide SPIR-V shaders to
         * {@link Render.GPURenderState}, optional.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_CREATE_GPU_SHADERS_SPIRV_BOOLEAN")]
        public const string GPU_SHADERS_SPIRV_BOOLEAN;

        /**
         * The app is able to provide DXIL shaders to
         * {@link Render.GPURenderState}, optional.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_CREATE_GPU_SHADERS_DXIL_BOOLEAN")]
        public const string GPU_SHADERS_DXIL_BOOLEAN;

        /**
         * The app is able to provide MSL shaders to
         * {@link Render.GPURenderState}, optional.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_CREATE_GPU_SHADERS_MSL_BOOLEAN")]
        public const string GPU_SHADERS_MSL_BOOLEAN;

        /// Vulkan renderer

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_INSTANCE_POINTER")]
        public const string VULKAN_INSTANCE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_SURFACE_NUMBER")]
        public const string VULKAN_SURFACE_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_PHYSICAL_DEVICE_POINTER")]
        public const string VULKAN_PHYSICAL_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_DEVICE_POINTER")]
        public const string VULKAN_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER")]
        public const string VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_CREATE_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER")]
        public const string VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER;
    } // PropRendererCreate

    namespace PropTextureCreate {
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER")]
        public const string COLORSPACE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER")]
        public const string FORMAT_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER")]
        public const string ACCESS_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER")]
        public const string WIDTH_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER")]
        public const string HEIGHT_NUMBER;

        /**
         * An {@link Pixels.Palette} to use with palettized texture formats.
         * This can be set later with {@link Render.set_texture_palette}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_PALETTE_POINTER")]
        public const string PALETTE_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT")]
        public const string SDR_WHITE_POINT_FLOAT;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT")]
        public const string HDR_HEADROOM_FLOAT;

        /// Direct3D 11

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_POINTER")]
        public const string D3D11_TEXTURE_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_U_POINTER")]
        public const string D3D11_TEXTURE_U_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_V_POINTER")]
        public const string D3D11_TEXTURE_V_POINTER;

        /// Direct3D 12

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_POINTER")]
        public const string D3D12_TEXTURE_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_U_POINTER")]
        public const string D3D12_TEXTURE_U_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_V_POINTER")]
        public const string D3D12_TEXTURE_V_POINTER;

        /// Metal

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_METAL_PIXELBUFFER_POINTER")]
        public const string METAL_PIXELBUFFER_POINTER;

        /// OpenGL

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER")]
        public const string OPENGL_TEXTURE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_UV_NUMBER")]
        public const string OPENGL_TEXTURE_UV_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_U_NUMBER")]
        public const string OPENGL_TEXTURE_U_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_V_NUMBER")]
        public const string OPENGL_TEXTURE_V_NUMBER;

        /// OpenGL ES2

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER")]
        public const string OPENGLES2_TEXTURE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_UV_NUMBER")]
        public const string OPENGLES2_TEXTURE_UV_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_U_NUMBER")]
        public const string OPENGLES2_TEXTURE_U_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_V_NUMBER")]
        public const string OPENGLES2_TEXTURE_V_NUMBER;

        /// Vulkan

        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_VULKAN_TEXTURE_NUMBER")]
        public const string VULKAN_TEXTURE_NUMBER;

        /**
         * The VkImageLayout for the VkImage, defaults to
         * VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_VULKAN_LAYOUT_NUMBER")]
        public const string VULKAN_LAYOUT_NUMBER;

        /// GPU renderer

        /**
         * The {@link GPU.GPUTexture} associated with the texture, if you want
         * to wrap an existing texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_POINTER")]
        public const string GPU_TEXTURE_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the UV plane of an NV12
         * texture, if you want to wrap an existing texture.
         * an existing texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_UV_POINTER")]
        public const string GPU_TEXTURE_UV_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the U plane of a YUV
         * texture, if you want to wrap an existing texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_U_POINTER")]
        public const string GPU_TEXTURE_U_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the V plane of a YUV
         * texture, if you want to wrap an existing texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateTextureWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_V_POINTER")]
        public const string GPU_TEXTURE_V_POINTER;
    } // PropTextureCreate

    namespace PropRenderer {
        [CCode (cname = "SDL_PROP_RENDERER_NAME_STRING")]
        public const string NAME_STRING;

        [CCode (cname = "SDL_PROP_RENDERER_WINDOW_POINTER")]
        public const string WINDOW_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_SURFACE_POINTER")]
        public const string SURFACE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_VSYNC_NUMBER")]
        public const string VSYNC_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER")]
        public const string MAX_TEXTURE_SIZE_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_TEXTURE_FORMATS_POINTER")]
        public const string TEXTURE_FORMATS_POINTER;

        /**
         * True if the renderer supports {@link TextureAddressMode.WRAP}
         * on non-power-of-two textures.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetRendererProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_TEXTURE_WRAPPING_BOOLEAN")]
        public const string TEXTURE_WRAPPING_BOOLEAN;

        [CCode (cname = "SDL_PROP_RENDERER_OUTPUT_COLORSPACE_NUMBER")]
        public const string OUTPUT_COLORSPACE_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN")]
        public const string HDR_ENABLED_BOOLEAN;

        [CCode (cname = "SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT")]
        public const string SDR_WHITE_POINT_FLOAT;

        [CCode (cname = "SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT")]
        public const string HDR_HEADROOM_FLOAT;

        /// Direct3D

        [CCode (cname = "SDL_PROP_RENDERER_D3D9_DEVICE_POINTER")]
        public const string D3D9_DEVICE_POINTER;

        /// Direct3D 11

        [CCode (cname = "SDL_PROP_RENDERER_D3D11_DEVICE_POINTER")]
        public const string D3D11_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_D3D11_SWAPCHAIN_POINTER")]
        public const string D3D11_SWAPCHAIN_POINTER;

        /// Direct3D 12

        [CCode (cname = "SDL_PROP_RENDERER_D3D12_DEVICE_POINTER")]
        public const string D3D12_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_D3D12_SWAPCHAIN_POINTER")]
        public const string D3D12_SWAPCHAIN_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_D3D12_COMMAND_QUEUE_POINTER")]
        public const string D3D12_COMMAND_QUEUE_POINTER;

        /// Vulkan

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_INSTANCE_POINTER")]
        public const string VULKAN_INSTANCE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_SURFACE_NUMBER")]
        public const string VULKAN_SURFACE_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_PHYSICAL_DEVICE_POINTER")]
        public const string VULKAN_PHYSICAL_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_DEVICE_POINTER")]
        public const string VULKAN_DEVICE_POINTER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER")]
        public const string VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER")]
        public const string VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER;

        [CCode (cname = "SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER")]
        public const string VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER;

        // GPU Renderer

        /**
         * The {@link GPU.GPUDevice} associated with the renderer.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetRendererProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_RENDERER_GPU_DEVICE_POINTER")]
        public const string GPU_DEVICE_POINTER;
    } // PropRenderer

    namespace PropTexture {
        [CCode (cname = "SDL_PROP_TEXTURE_COLORSPACE_NUMBER")]
        public const string COLORSPACE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_FORMAT_NUMBER")]
        public const string FORMAT_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_ACCESS_NUMBER")]
        public const string ACCESS_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_WIDTH_NUMBER")]
        public const string WIDTH_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_HEIGHT_NUMBER")]
        public const string HEIGHT_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_SDR_WHITE_POINT_FLOAT")]
        public const string SDR_WHITE_POINT_FLOAT;

        [CCode (cname = "SDL_PROP_TEXTURE_HDR_HEADROOM_FLOAT")]
        public const string HDR_HEADROOM_FLOAT;

        // Direct3D 11
        [CCode (cname = "SDL_PROP_TEXTURE_D3D11_TEXTURE_POINTER")]
        public const string D3D11_TEXTURE_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_D3D11_TEXTURE_U_POINTER")]
        public const string D3D11_TEXTURE_U_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_D3D11_TEXTURE_V_POINTER")]
        public const string D3D11_TEXTURE_V_POINTER;

        // Direct3D 12
        [CCode (cname = "SDL_PROP_TEXTURE_D3D12_TEXTURE_POINTER")]
        public const string D3D12_TEXTURE_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_D3D12_TEXTURE_U_POINTER")]
        public const string D3D12_TEXTURE_U_POINTER;

        [CCode (cname = "SDL_PROP_TEXTURE_D3D12_TEXTURE_V_POINTER")]
        public const string D3D12_TEXTURE_V_POINTER;

        // Vulkan
        [CCode (cname = "SDL_PROP_TEXTURE_VULKAN_TEXTURE_NUMBER")]
        public const string VULKAN_TEXTURE_NUMBER;

        // OpenGL
        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEXTURE_NUMBER")]
        public const string OPENGL_TEXTURE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEXTURE_UV_NUMBER")]
        public const string OPENGL_TEXTURE_UV_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEXTURE_U_NUMBER")]
        public const string OPENGL_TEXTURE_U_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEXTURE_V_NUMBER")]
        public const string OPENGL_TEXTURE_V_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEXTURE_TARGET_NUMBER")]
        public const string OPENGL_TEXTURE_TARGET_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEX_W_FLOAT")]
        public const string OPENGL_TEX_W_FLOAT;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGL_TEX_H_FLOAT")]
        public const string OPENGL_TEX_H_FLOAT;

        // OpenGL ES2
        [CCode (cname = "SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_NUMBER")]
        public const string OPENGLES2_TEXTURE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_UV_NUMBER")]
        public const string OPENGLES2_TEXTURE_UV_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_U_NUMBER")]
        public const string OPENGLES2_TEXTURE_U_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_V_NUMBER")]
        public const string OPENGLES2_TEXTURE_V_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_TARGET_NUMBER")]
        public const string OPENGLES2_TEXTURE_TARGET_NUMBER;

        /// GPU renderer

        /**
         * The {@link GPU.GPUTexture} associated with the texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetTextureProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_GPU_TEXTURE_POINTER")]
        public const string GPU_TEXTURE_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the UV plane of an NV12
         * texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetTextureProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_GPU_TEXTURE_UV_POINTER")]
        public const string GPU_TEXTURE_UV_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the U plane of a YUV
         * texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetTextureProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_GPU_TEXTURE_U_POINTER")]
        public const string GPU_TEXTURE_U_POINTER;

        /**
         * The {@link GPU.GPUTexture} associated with the V plane of a YUV
         * texture.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetTextureProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_TEXTURE_GPU_TEXTURE_V_POINTER")]
        public const string GPU_TEXTURE_V_POINTER;
    } // PropTexture
} // SDL.Render

///
/// Pixel Formats and Conversion Routines (SDL_pixels.h)
///
namespace SDL.Pixels {
    [CCode (cname = "SDL_CreatePalette")]
    public static Palette ? create_palette (int ncolors);

    [CCode (cname = "SDL_DestroyPalette")]
    public static void destroy_palette (Palette palette);

    [CCode (cname = "SDL_GetMasksForPixelFormat")]
    public static bool get_masks_for_pixel_format (PixelFormat format,
            int bpp,
            out uint32 r_mask,
            out uint32 g_mask,
            out uint32 b_mask,
            out uint32 a_mask);

    [CCode (cname = "SDL_GetPixelFormatDetails")]
    public static PixelFormatDetails ? get_pixel_format_details (PixelFormat format);

    [CCode (cname = "SDL_GetPixelFormatForMasks")]
    public static PixelFormat get_pixel_format_for_masks (int bpp,
            uint32 r_mask,
            uint32 g_mask,
            uint32 b_mask,
            uint32 a_mask);

    [CCode (cname = "SDL_GetPixelFormatName")]
    public static unowned string get_pixel_format_name (PixelFormat format);

    [CCode (cname = "SDL_GetRGB")]
    public static void get_rgb (uint32 pixel_value,
            PixelFormatDetails format,
            Palette? palette,
            out uint8 r,
            out uint8 g,
            out uint8 b);

    [CCode (cname = "SDL_GetRGBA")]
    public static void get_rgba (uint32 pixel_value,
            PixelFormatDetails format,
            Palette? palette,
            out uint8 r,
            out uint8 g,
            out uint8 b,
            out uint8 a);

    [CCode (cname = "SDL_MapRGB")]
    public static uint32 map_rgb (PixelFormatDetails format,
            Palette? palette,
            uint8 r,
            uint8 g,
            uint8 b);

    [CCode (cname = "SDL_MapRGBA")]
    public static uint32 map_rgba (PixelFormatDetails format,
            Palette? palette,
            uint8 r,
            uint8 g,
            uint8 b,
            uint8 a);

    [CCode (cname = "SDL_MapSurfaceRGB")]
    public static uint32 map_surface_rgb (Surface.Surface surface,
            uint8 r,
            uint8 g,
            uint8 b);

    [CCode (cname = "SDL_MapSurfaceRGBA")]
    public static uint32 map_surface_rgba (Surface.Surface surface,
            uint8 r,
            uint8 g,
            uint8 b,
            uint8 a);

    [CCode (cname = "SDL_SetPaletteColors")]
    public static bool set_palette_colors (Palette palette,
            [CCode (array_length = false)] Color[] colors,
            int first_color,
            int number_of_colors);

    [SimpleType, CCode (cname = "SDL_Color", has_type_id = false)]
    public struct Color {
        public uint8 r;
        public uint8 g;
        public uint8 b;
        public uint8 a;
    } // Color;

    [SimpleType, CCode (cname = "SDL_FColor", has_type_id = false)]
    public struct FColor {
        public float r;
        public float g;
        public float b;
        public float a;
    } // FColor

    [Compact, CCode (cname = "SDL_Palette", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Palette {
        public int ncolors;
        public Color[] colors;
        public uint32 version;
        public int refcount;
    } // Palette

    [CCode (cname = "SDL_PixelFormatDetails", has_type_id = false)]
    public struct PixelFormatDetails {
        public PixelFormat format;
        public uint8 bits_per_pixel;
        public uint8 bytes_per_pixel;
        public uint8 padding[2];
        [CCode (cname = "Rmask")]
        public uint32 r_mask;
        [CCode (cname = "Gmask")]
        public uint32 g_mask;
        [CCode (cname = "Bmask")]
        public uint32 b_mask;
        [CCode (cname = "Amask")]
        public uint32 a_mask;
        [CCode (cname = "Rbits")]
        public uint8 r_bits;
        [CCode (cname = "Gbits")]
        public uint8 g_bits;
        [CCode (cname = "Bbits")]
        public uint8 b_bits;
        [CCode (cname = "Abits")]
        public uint8 a_bits;
        [CCode (cname = "Rshift")]
        public uint8 r_shift;
        [CCode (cname = "Gshift")]
        public uint8 g_shift;
        [CCode (cname = "Bshift")]
        public uint8 b_shift;
        [CCode (cname = "Ashift")]
        public uint8 a_shift;
    } // PixelFormatDetails

    [CCode (cname = "SDL_ArrayOrder", cprefix = "SDL_ARRAYORDER_", has_type_id = false)]
    public enum ArrayOrder {
        NONE,
        RGB,
        RGBA,
        ARGB,
        BGR,
        BGRA,
        ABGR,
    } // ArrayOrder

    [CCode (cname = "SDL_BitmapOrder", cprefix = "SDL_", has_type_id = false)]
    public enum BitmapOrder {
        BITMAPORDER_NONE,
        BITMAPORDER_4321,
        BITMAPORDER_1234,
    } // BitmapOrder

    [CCode (cname = "SDL_ChromaLocation", cprefix = "SDL_CHROMA_LOCATION_", has_type_id = false)]
    public enum ChromaLocation {
        NONE,
        LEFT,
        CENTER,
        TOPLEFT,
    } // ChromaLocation

    [CCode (cname = "SDL_ColorPrimaries", cprefix = "SDL_COLOR_PRIMARIES_", has_type_id = false)]
    public enum ColorPrimaries {
        UNKNOWN,
        BT709,
        UNSPECIFIED,
        BT470M,
        BT470BG,
        BT601,
        SMPTE240,
        GENERIC_FILM,
        BT2020,
        XYZ,
        SMPTE431,
        SMPTE432,
        EBU3213,
        CUSTOM,
    } // ColorPrimaries

    [CCode (cname = "SDL_ColorRange", cprefix = "SDL_COLOR_RANGE_", has_type_id = false)]
    public enum ColorRange {
        UNKNOWN,
        LIMITED,
        FULL,
    } // ColorRange

    /**
     * Colorspace definitions.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Colorspace]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_Colorspace", cprefix = "SDL_COLORSPACE_", has_type_id = false)]
    public enum ColorSpace {
    /**
     * Unknown color space
     *
     */
        UNKNOWN,

        /**
         * sRGB is a gamma corrected colorspace, and the default colorspace
         * for SDL rendering and 8-bit RGB surfaces.
         *
         */
        SRGB,

        /**
         * This is a linear colorspace and the default colorspace for
         * floating point surfaces.
         *
         * On Windows this is the scRGB colorspace, and on Apple platforms
         * this is kCGColorSpaceExtendedLinearSRGB for EDR content.
         *
         */
        SRGB_LINEAR,

        /**
         * HDR10 is a non-linear HDR colorspace and the default colorspace
         * for 10-bit surfaces.
         *
         */
        HDR10,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_FULL_G22_NONE_P709_X601.
         *
         */
        JPEG,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_STUDIO_G22_LEFT_P709.
         *
         */
        BT601_LIMITED,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_STUDIO_G22_LEFT_P709.
         *
         */
        BT601_FULL,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_FULL_G22_NONE_P709_X601.
         *
         */
        BT709_LIMITED,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_STUDIO_G22_LEFT_P2020.
         *
         */
        BT709_FULL,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_FULL_G22_NONE_P709_X601.
         *
         */
        BT2020_LIMITED,

        /**
         * Equivalent to DXGI_COLOR_SPACE_YCBCR_FULL_G22_LEFT_P2020.
         *
         */
        BT2020_FULL,

        /**
         * The default colorspace for RGB surfaces if no colorspace is
         * specified.
         *
         */
        RGB_DEFAULT,

        /**
         * The default colorspace for YUV surfaces if no colorspace is
         * specified.
         *
         */
        YUV_DEFAULT,
    } // ColorSpace

    [CCode (cname = "SDL_ColorType", cprefix = "SDL_COLOR_TYPE_", has_type_id = false)]
    public enum ColorType {
        UNKNOWN,
        RGB,
        YCBCR,
    } // ColorType

    [CCode (cname = "SDL_MatrixCoefficients", cprefix = "SDL_MATRIX_COEFFICIENTS_",
    has_type_id = false)]
    public enum MatrixCoefficients {
        IDENTITY,
        BT709,
        UNSPECIFIED,
        FCC,
        BT470BG,
        BT601,
        SMPTE240,
        YCGCO,
        BT2020_NCL,
        BT2020_CL,
        SMPTE2085,
        CHROMA_DERIVED_NCL,
        CHROMA_DERIVED_CL,
        ICTCP,
        CUSTOM,
    } // MatrixCoefficients

    [CCode (cname = "SDL_PackedLayout", cprefix = "SDL_", has_type_id = false)]
    public enum PackedLayout {
        PACKEDLAYOUT_NONE,
        PACKEDLAYOUT_332,
        PACKEDLAYOUT_4444,
        PACKEDLAYOUT_1555,
        PACKEDLAYOUT_5551,
        PACKEDLAYOUT_565,
        PACKEDLAYOUT_8888,
        PACKEDLAYOUT_2101010,
        PACKEDLAYOUT_1010102,
    } // PackedLayout

    [CCode (cname = "SDL_PackedOrder", cprefix = "SDL_PACKEDORDER_", has_type_id = false)]
    public enum PackedOrder {
        NONE,
        XRGB,
        RGBX,
        ARGB,
        RGBA,
        XBGR,
        BGRX,
        ABGR,
        BGRA,
    } // PackedOrder

    /**
     * Pixel formats.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PixelFormat]]
     *
     * @since 3.2.0
     */
    [Version(since = "3.2.0")]
    [CCode (cname = "SDL_PixelFormat", cprefix = "SDL_PIXELFORMAT_", has_type_id = false)]
    public enum PixelFormat {
        UNKNOWN,
        INDEX1LSB,
        INDEX1MSB,
        INDEX2LSB,
        INDEX2MSB,
        INDEX4LSB,
        INDEX4MSB,
        INDEX8,
        RGB332,
        XRGB4444,
        XBGR4444,
        XRGB1555,
        XBGR1555,
        ARGB4444,
        RGBA4444,
        ABGR4444,
        BGRA4444,
        ARGB1555,
        RGBA5551,
        ABGR1555,
        BGRA5551,
        RGB565,
        BGR565,
        RGB24,
        BGR24,
        XRGB8888,
        RGBX8888,
        XBGR8888,
        BGRX8888,
        ARGB8888,
        RGBA8888,
        ABGR8888,
        BGRA8888,
        XRGB2101010,
        XBGR2101010,
        ARGB2101010,
        ABGR2101010,
        RGB48,
        BGR48,
        RGBA64,
        ARGB64,
        BGRA64,
        ABGR64,
        RGB48_FLOAT,
        BGR48_FLOAT,
        RGBA64_FLOAT,
        ARGB64_FLOAT,
        BGRA64_FLOAT,
        ABGR64_FLOAT,
        RGB96_FLOAT,
        BGR96_FLOAT,
        RGBA128_FLOAT,
        ARGB128_FLOAT,
        BGRA128_FLOAT,
        ABGR128_FLOAT,
        YV12,
        IYUV,
        YUY2,
        UYVY,
        YVYU,
        NV12,
        NV21,
        P010,
        EXTERNAL_OES,

        /**
         * Motion JPEG
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        MJPG;

    /**
     * Alias for {@link RGBA8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_RGBA32")]
    public const PixelFormat RGBA32;

    /**
     * Alias for {@link ARGB8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_ARGB32")]
    public const PixelFormat ARGB32;

    /**
     * Alias for {@link BGRA8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_BGRA32")]
    public const PixelFormat BGRA32;

    /**
     * Alias for {@link ABGR8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_ABGR32")]
    public const PixelFormat ABGR32;

    /**
     * Alias for {@link RGBX8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_RGBX32")]
    public const PixelFormat RGBX32;

    /**
     * Alias for {@link XRGB8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_XRGB32")]
    public const PixelFormat XRGB32;

    /**
     * Alias for {@link BGRX8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_BGRX32")]
    public const PixelFormat BGRX32;

    /**
     * Alias for {@link XBGR8888}
     *
     */
    [CCode (cname = "SDL_PIXELFORMAT_XBGR32")]
    public const PixelFormat XBGR32;
    } // PixelFormat

    [CCode (cname = "SDL_PixelType", cprefix = "SDL_PIXELTYPE_", has_type_id = false)]
    public enum PixelType {
        UNKNOWN,
        INDEX1,
        INDEX4,
        INDEX8,
        PACKED8,
        PACKED16,
        PACKED32,
        ARRAYU8,
        ARRAYU16,
        ARRAYU32,
        ARRAYF16,
        ARRAYF32,
        INDEX2,
    } // PixelType;

    [CCode (cname = "SDL_TransferCharacteristics", cprefix = "SDL_TRANSFER_CHARACTERISTICS_",
    has_type_id = false)]
    public enum TransferCharacteristics {
        UNKNOWN,
        BT709,
        UNSPECIFIED,
        GAMMA22,
        GAMMA28,
        BT601,
        SMPTE240,
        LINEAR,
        LOG100,
        LOG100_SQRT10,
        IEC61966,
        BT1361,
        SRGB,
        BT2020_10BIT,
        BT2020_12BIT,
        PQ,
        SMPTE428,
        HLG,
        CUSTOM,
    } // TransferCharacteristics;

    [CCode (cname = "SDL_ALPHA_OPAQUE")]
    public const uint8 ALPHA_OPAQUE;

    [CCode (cname = "SDL_ALPHA_OPAQUE_FLOAT")]
    public const float ALPHA_OPAQUE_FLOAT;

    [CCode (cname = "SDL_ALPHA_TRANSPARENT")]
    public const uint8 ALPHA_TRANSPARENT;

    [CCode (cname = "SDL_ALPHA_TRANSPARENT_FLOAT")]
    public const float ALPHA_TRANSPARENT_FLOAT;

    [CCode (cname = "SDL_BITSPERPIXEL")]
    public static uint8 bits_per_pixel (PixelFormat format);

    [CCode (cname = "SDL_BYTESPERPIXEL")]
    public static uint8 bytes_per_pixel (PixelFormat format);

    [CCode (cname = "SDL_COLORSPACECHROMA")]
    public static ChromaLocation color_space_chroma (ColorSpace cspace);

    [CCode (cname = "SDL_COLORSPACEMATRIX")]
    public static MatrixCoefficients color_space_matrix (ColorSpace cspace);

    [CCode (cname = "SDL_COLORSPACEPRIMARIES")]
    public static ColorPrimaries color_space_primaries (ColorSpace cspace);

    [CCode (cname = "SDL_COLORSPACERANGE")]
    public static ColorRange color_space_range (ColorSpace cspace);

    [CCode (cname = "SDL_COLORSPACETRANSFER")]
    public static TransferCharacteristics color_space_transfer (ColorSpace cspace);

    [CCode (cname = "SDL_COLORSPACETYPE")]
    public static ColorType colorsspace_type (ColorSpace cspace);

    [CCode (cname = "SDL_DEFINE_COLORSPACE")]
    public static ColorSpace define_color_space (ColorType type,
            ColorRange range,
            ColorPrimaries primaries,
            TransferCharacteristics transfer,
            MatrixCoefficients matrix,
            ChromaLocation chroma);

    [CCode (cname = "SDL_DEFINE_PIXELFORMAT")]
    public static PixelFormat define_pixelformat_bitmap_order (ColorType type,
            BitmapOrder order,
            PackedLayout layout,
            uint8 bits,
            uint8 bytes);

    [CCode (cname = "SDL_DEFINE_PIXELFORMAT")]
    public static PixelFormat define_pixelformat_packed_order (ColorType type,
            PackedOrder order,
            PackedLayout layout,
            uint8 bits,
            uint8 bytes);

    [CCode (cname = "SDL_DEFINE_PIXELFORMAT")]
    public static PixelFormat define_pixelformat_array_order (ColorType type,
            ArrayOrder order,
            PackedLayout layout,
            uint8 bits,
            uint8 bytes);

    [CCode (cname = "SDL_DEFINE_PIXELFOURCC")]
    public static uint32 define_pixel_fourcc (char a, char b, char c, char d);

    [CCode (cname = "SDL_ISCOLORSPACE_FULL_RANGE")]
    public static bool is_color_space_full_range (ColorSpace cspace);

    [CCode (cname = "SDL_ISCOLORSPACE_LIMITED_RANGE")]
    public static bool is_color_space_limited_range (ColorSpace cspace);

    [CCode (cname = "SDL_ISCOLORSPACE_MATRIX_BT2020_NCL")]
    public static bool is_color_space_matrix_bt2020_ncl (ColorSpace cspace);

    [CCode (cname = "SDL_ISCOLORSPACE_MATRIX_BT601")]
    public static bool is_color_space_matrix_bt601(ColorSpace cspace);

    [CCode (cname = "SDL_ISCOLORSPACE_MATRIX_BT709")]
    public static bool is_color_space_matrix_bt709(ColorSpace cspace);

    [CCode (cname = "SDL_ISPIXELFORMAT_10BIT")]
    public static bool is_pixelformat_10bit (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_ALPHA")]
    public static bool is_pixelformat_alpha (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_ARRAY")]
    public static bool is_pixelformat_array (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_FLOAT")]
    public static bool is_pixelformat_float (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_FOURCC")]
    public static bool is_pixelformat_fourcc (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_INDEXED")]
    public static bool is_pixelformat_indexed (PixelFormat format);

    [CCode (cname = "SDL_ISPIXELFORMAT_PACKED")]
    public static bool is_pixelformat_packed (PixelFormat format);

    [CCode (cname = "SDL_PIXELFLAG")]
    public static uint32 pixel_flag (PixelFormat format);

    [CCode (cname = "SDL_PIXELLAYOUT")]
    public static PackedLayout pixel_layout (PixelFormat format);

    [CCode (cname = "SDL_PIXELORDER")]
    public static uint pixel_order (PixelFormat format);

    [CCode (cname = "PIXELTYPE")]
    public static PixelType pixel_type (PixelFormat format);
} // SDL.Pixels

///
/// Blend modes (SDL_blendmode.h)
///
[CCode (cheader_filename = "SDL3/SDL_blendmode.h")]
namespace SDL.BlendModes {
    [CCode (cname = "SDL_ComposeCustomBlendMode")]
    public static BlendMode compose_custom_blend_mode (BlendFactor src_color_factor,
            BlendFactor dst_color_factor,
            BlendOperation color_operation,
            BlendFactor src_alpha_factor,
            BlendFactor dst_alpha_factor,
            BlendOperation alpha_operation);

    [CCode (cname = "Uint32", cprefix = "SDL_BLENDMODE_", has_type_id = false)]
    public enum BlendMode {
        NONE,
        BLEND,
        BLEND_PREMULTIPLIED,
        ADD,
        ADD_PREMULTIPLIED,
        MOD,
        MUL,
        INVALID,
    } // BlendMode

    [CCode (cname = "SDL_BlendFactor", cprefix = "SDL_BLENDFACTOR_", has_type_id = false)]
    public enum BlendFactor {
        ZERO,
        ONE,
        SRC_COLOR,
        ONE_MINUS_SRC_COLOR,
        SRC_ALPHA,
        ONE_MINUS_SRC_ALPHA,
        DST_COLOR,
        ONE_MINUS_DST_COLOR,
        DST_ALPHA,
        ONE_MINUS_DST_ALPHA,
    } // BlendFactor;

    [CCode (cname = "SDL_BlendOperation", cprefix = "SDL_BLENDOPERATION_", has_type_id = false)]
    public enum BlendOperation {
        ADD,
        SUBTRACT,
        REV_SUBTRACT,
        MINIMUM,
        MAXIMUM,
    } // BlendOperation;
} // SDL.BlendModes

///
/// Rectangle Functions (SDL_rect.h)
///
[CCode (cheader_filename = "SDL3/SDL_rect.h")]
namespace SDL.Rect {
    [CCode (cname = "SDL_GetRectAndLineIntersection")]
    public static bool get_rect_and_line_intersection (Rect rect, int x1, int y1, int x2, int y2);

    [CCode (cname = "SDL_GetRectAndLineIntersectionFloat")]
    public static bool get_rect_and_line_intersection_float (FRect rect,
            float x1,
            float y1,
            float x2,
            float y2);

    [CCode (cname = "SDL_GetRectEnclosingPoints")]
    public static bool get_rect_enclosing_points (Point[] points, Rect? clip, out Rect result);

    [CCode (cname = "SDL_GetRectEnclosingPointsFloat")]
    public static bool get_rect_enclosing_points_float (FPoint[] points,
            FRect? clip,
            out FRect result);

    [CCode (cname = "SDL_GetRectIntersection")]
    public static bool get_rect_intersection (Rect a, Rect b, out Rect result);

    [CCode (cname = "SDL_GetRectIntersectionFloat")]
    public static bool get_rect_intersection_float (FRect a, FRect b, out FRect result);

    [CCode (cname = "SDL_GetRectUnion")]
    public static bool get_rect_union (Rect a, Rect b, out Rect result);

    [CCode (cname = "SDL_GetRectUnionFloat")]
    public static bool get_rect_union_float (FRect a, FRect b, out FRect result);

    [CCode (cname = "SDL_HasRectIntersection")]
    public static bool has_rect_intersection (Rect a, Rect b);

    [CCode (cname = "SDL_HasRectIntersectionFloat")]
    public static bool has_rect_intersection_float (FRect a, FRect b);

    [CCode (cname = "SDL_PointInRect")]
    public static bool point_in_rect (Point p, Rect r);

    [CCode (cname = "SDL_PointInRectFloat")]
    public static bool point_in_rect_float (FPoint p, FRect r);

    [CCode (cname = "SDL_RectEmpty")]
    public static bool rect_empty (Rect? r);

    [CCode (cname = "SDL_RectEmptyFloat")]
    public static bool rect_empty_float (FRect? r);

    [CCode (cname = "SDL_RectsEqual")]
    public static bool rects_equal (Rect a, Rect b);

    [CCode (cname = "SDL_RectsEqualEpsilon")]
    public static bool rects_equal_epsilon (FRect a, FRect b, float epsilon);

    [CCode (cname = "SDL_RectsEqualFloat")]
    public static bool rects_equal_float (FRect a, FRect b);

    [CCode (cname = "SDL_RectToFRect")]
    public static void rect_to_frect (Rect rect, out FRect frect);

    [CCode (cname = "SDL_FPoint", has_type_id = false)]
    public struct FPoint {
        public float x;
        public float y;
    } // FPoint

    [CCode (cname = "SDL_FRect", has_type_id = false)]
    public struct FRect {
        public float x;
        public float y;
        public float w;
        public float h;
    } // FRect

    [CCode (cname = "SDL_Point", has_type_id = false)]
    public struct Point {
        public int x;
        public int y;
    } // Point

    [CCode (cname = "SDL_Rect", has_type_id = false)]
    public struct Rect {
        public int x;
        public int y;
        public int w;
        public int h;
    } // Rect
} // SDL.Rect

///
/// Surface Creation and Simple Drawing  (SDL_surface.h)
///
[CCode (cheader_filename = "SDL3/SDL_surface.h")]
namespace SDL.Surface {
    [CCode (cname = "SDL_AddSurfaceAlternateImage")]
    public static bool add_surface_alternate_image (Surface surface, Surface image);

    [CCode (cname = "SDL_BlitSurface")]
    public static bool blit_surface (Surface src,
            Rect.Rect? src_rect,
            Surface dst,
            Rect.Rect? dst_rect);

    [CCode (cname = "SDL_BlitSurface9Grid")]
    public static bool blit_surface_9grid (Surface src,
            Rect.Rect? src_rect,
            int left_width,
            int right_width,
            int top_height,
            int bottom_height,
            float scale,
            ScaleMode scale_mode,
            Surface dst,
            Rect.Rect? dst_rect);

    [CCode (cname = "SDL_BlitSurfaceScaled")]
    public static bool blit_surface_scaled (Surface src,
            Rect.Rect? src_rect,
            Surface dst,
            Rect.Rect? dst_rect,
            ScaleMode scale_mode);

    [CCode (cname = "SDL_BlitSurfaceTiled")]
    public static bool blit_surface_tiled (Surface src,
            Rect.Rect? src_rect,
            Surface dst,
            Rect.Rect? dst_rect);

    [CCode (cname = "SDL_BlitSurfaceTiledWithScale")]
    public static bool blit_surface_tiled_with_scale (Surface src,
            Rect.Rect? src_rect,
            float scale,
            ScaleMode scale_mode,
            Surface dst,
            Rect.Rect? dst_rect);

    [CCode (cname = "SDL_BlitSurfaceUnchecked")]
    public static bool blit_surface_unchecked (Surface src,
            Rect.Rect? src_rect,
            Surface dst,
            Rect.Rect? dst_rect);

    [CCode (cname = "SDL_BlitSurfaceUncheckedScaled")]
    public static bool blit_surface_unchecked_scaled (Surface src,
            Rect.Rect? src_rect,
            Surface dst,
            Rect.Rect? dst_rect,
            ScaleMode scale_mode);

    [CCode (cname = "SDL_ClearSurface")]
    public static bool clear_surface (Surface surface, float r, float g, float b, float a);

    [CCode (cname = "SDL_ConvertPixels")]
    public static bool convert_pixels (int width,
            int height,
            Pixels.PixelFormat src_format,
            void* src,
            int src_pitch,
            Pixels.PixelFormat dst_format,
            void* dst,
            int dst_pitch);

    [CCode (cname = "SDL_ConvertPixelsAndColorspace")]
    public static bool convert_pixels_and_color_space (int width,
            int height,
            Pixels.PixelFormat src_format,
            Pixels.ColorSpace src_color_space,
            SDL.Properties.PropertiesID src_properties,
            void* src,
            int src_pitch,
            Pixels.PixelFormat dst_format,
            Pixels.ColorSpace dst_color_space,
            SDL.Properties.PropertiesID dst_properties,
            void* dst,
            int dst_pitch);

    [CCode (cname = "SDL_ConvertSurface")]
    public static Surface ? convert_surface (Surface surface, Pixels.PixelFormat format);

    [CCode (cname = "SDL_ConvertSurfaceAndColorspace")]
    public static Surface ? convert_surface_and_color_space (Surface surface,
            Pixels.PixelFormat format,
            Pixels.Palette palette,
            Pixels.ColorSpace color_space,
            SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_CreateSurface")]
    public static Surface ? create_surface (int width, int height, Pixels.PixelFormat format);

    [CCode (cname = "SDL_CreateSurfaceFrom")]
    public static Surface ? create_surface_from (int width,
            int height,
            Pixels.PixelFormat format,
            void* pixels,
            int pitch);

    [CCode (cname = "SDL_CreateSurfacePalette")]
    public static Pixels.Palette ? create_surface_palette (Surface surface);

    [CCode (cname = "SDL_DestroySurface")]
    public static void destroy_surface (Surface surface);

    [CCode (cname = "SDL_DuplicateSurface")]
    public static Surface ? duplicate_surface (Surface surface);

    [CCode (cname = "SDL_FillSurfaceRect")]
    public static bool fill_surface_rect (Surface dst, Rect.Rect? rect, uint32 color);

    [CCode (cname = "SDL_FillSurfaceRects")]
    public static bool fill_surface_rects (Surface dst, Rect.Rect rects, uint32 color);

    [CCode (cname = "SDL_FlipSurface")]
    public static bool flip_surface (Surface surface, FlipMode flip);

    [CCode (cname = "SDL_GetSurfaceAlphaMod")]
    public static bool get_surface_alpha_mod (Surface surface, out uint8 alpha);

    [CCode (cname = "SDL_GetSurfaceBlendMode")]
    public static bool get_surface_blend_mode (Surface surface, BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_GetSurfaceClipRect")]
    public static bool get_surface_clip_rect (Surface surface, Rect.Rect rect);

    [CCode (cname = "SDL_GetSurfaceColorKey")]
    public static bool get_surface_color_key (Surface surface, out uint32 key);

    [CCode (cname = "SDL_GetSurfaceColorMod")]
    public static bool get_surface_color_mod (Surface surface,
            out uint8 r,
            out uint8 g,
            out uint8 b);

    [CCode (cname = "SDL_GetSurfaceColorspace")]
    public static Pixels.ColorSpace get_surface_color_space (Surface surface);

    [CCode (cname = "SDL_GetSurfaceImages")]
    public static Surface[] ? get_surface_images (Surface surface);

    [CCode (cname = "SDL_GetSurfacePalette")]
    public static Pixels.Palette ? get_surface_palette (Surface surface);

    [CCode (cname = "SDL_GetSurfaceProperties")]
    public static SDL.Properties.PropertiesID get_surface_properties (Surface surface);

    [CCode (cname = "SDL_LoadBMP")]
    public static Surface ? load_bmp (string file);

    [CCode (cname = "SDL_LoadBMP_IO")]
    public static Surface ? load_bmp_io (IOStream.IOStream src, bool close_io);

    /**
     * Load a PNG image from a file.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadPNG]]
     *
     * @param file the PNG file to load.
     *
     * @return a pointer to a new {@link Surface} structure or null on failure;
     * call {SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see destroy_surface
     * @see load_png_io
     * @see save_png
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_LoadPNG")]
    public static Surface ? load_png (string file);

    /**
     * Load a PNG image from a seekable SDL data stream.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadPNG_IO]]
     *
     * @param src the data stream for the surface.
     * @param close_io if true, calls {@link SDL.IOStream.close_io} on src
     * before returning, even in the case of an error.
     *
     * @return a pointer to a new {@link Surface} structure or null on failure;
     * call {SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see destroy_surface
     * @see load_png
     * @see save_png_io
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_LoadPNG_IO")]
    public static Surface ? load_png_io (IOStream.IOStream src, bool close_io);

    /**
     * Load a BMP or PNG image from a file.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadSurface]]
     *
     * @param file the file to load.
     *
     * @return a pointer to a new {@link Surface} structure or null on failure;
     * call {SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see destroy_surface
     * @see load_surface_io
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_LoadSurface")]
    public static Surface ? load_surface (string file);

    /**
     * Load a BMP or PNG image from a seekable SDL data stream.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadSurface_IO]]
     *
     * @param src the data stream for the surface.
     * @param close_io if true, calls {@link SDL.IOStream.close_io} on src
     * before returning, even in the case of an error.
     *
     * @return a pointer to a new {@link Surface} structure or null on failure;
     * call {SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see destroy_surface
     * @see load_surface
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_LoadSurface_IO")]
    public static Surface ? load_surface_io (IOStream.IOStream src, bool close_io);

    [CCode (cname = "SDL_LockSurface")]
    public static bool lock_surface (Surface surface);

    [CCode (cname = "SDL_MapSurfaceRGB")]
    public static uint32 map_surface_rgb (Surface surface, uint8 r, uint8 g, uint8 b);

    [CCode (cname = "SDL_MapSurfaceRGBA")]
    public static uint32 map_surface_rgba (Surface surface, uint8 r, uint8 g, uint8 b, uint8 a);

    [CCode (cname = "SDL_PremultiplyAlpha")]
    public static bool premultiply_alpha (int width,
            int height,
            Pixels.PixelFormat src_format,
            void* src,
            int src_pitch,
            Pixels.PixelFormat dst_format,
            void* dst,
            int dst_pitch,
            bool linear);

    [CCode (cname = "SDL_PremultiplySurfaceAlpha")]
    public static bool premultiply_surface_alpha (Surface surface, bool linear);

    [CCode (cname = "SDL_ReadSurfacePixel")]
    public static bool read_surface_pixel (Surface surface,
            int x,
            int y,
            out uint8 r,
            out uint8 g,
            out uint8 b,
            out uint8 a);

    [CCode (cname = "SDL_ReadSurfacePixelFloat")]
    public static bool read_surface_pixel_float (Surface surface,
            int x,
            int y,
            out float r,
            out float g,
            out float b,
            out float a);

    [CCode (cname = "SDL_RemoveSurfaceAlternateImages")]
    public static void remove_surface_alternate_images (Surface surface);

    /**
     * Return a copy of a surface rotated clockwise a number of degrees.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RotateSurface]]
     *
     * @param surface the surface to rotate.
     * @param angle the rotation angle, in degrees.
     *
     * @return a rotated copy of the surface or null on failure;
     * call {SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see destroy_surface
     * @see load_surface
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_RotateSurface")]
    public static Surface ? rotate_surface (Surface surface, float angle);

    [CCode (cname = "SDL_SaveBMP")]
    public static bool save_bmp (Surface surface, string file);

    [CCode (cname = "SDL_SaveBMP_IO")]
    public static bool save_bmp_io (Surface surface, IOStream.IOStream dst, bool close_io);

    /**
     * Save a surface to a file in PNG format.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SavePNG]]
     *
     * @param surface the {@link Surface} structure containing the image to
     * be saved.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see load_png
     * @see save_png_io
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SavePNG")]
    public static bool save_png (Surface surface, string file);

    /**
     * Save a surface to a seekable SDL data stream in PNG format.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SavePNG_IO]]
     *
     * @param surface the {@link Surface} structure containing the image to
     * be saved.
     * @param dst a data stream to save to.
     * @param close_io if true, calls {@link SDL.IOStream.close_io} on dst
     * before returning, even in the case of an error.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see load_png_io
     * @see save_png
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SavePNG_IO")]
    public static bool save_png_io (Surface surface, IOStream.IOStream dst, bool close_io);

    [CCode (cname = "SDL_ScaleSurface")]
    public static Surface ? scale_surface (Surface surface,
            int width,
            int height,
            ScaleMode scale_mode);

    [CCode (cname = "SDL_SetSurfaceAlphaMod")]
    public static bool set_surface_alpha_mod (Surface surface, uint8 alpha);

    [CCode (cname = "SDL_SetSurfaceBlendMode")]
    public static bool set_surface_blend_mode (Surface surface, BlendModes.BlendMode blend_mode);

    [CCode (cname = "SDL_SetSurfaceClipRect")]
    public static bool set_surface_clip_rect (Surface surface, Rect.Rect rect);

    [CCode (cname = "SDL_SetSurfaceColorKey")]
    public static bool set_surface_color_key (Surface surface, bool enabled, uint32 key);

    [CCode (cname = "SDL_SetSurfaceColorMod")]
    public static bool set_surface_color_mod (Surface surface, uint8 r, uint8 g, uint8 b);

    [CCode (cname = "SDL_SetSurfaceColorspace")]
    public static bool set_surface_color_space (Surface surface, Pixels.ColorSpace color_space);

    [CCode (cname = "SDL_SetSurfacePalette")]
    public static bool set_surface_palette (Surface surface, Pixels.Palette palette);

    [CCode (cname = "SDL_SetSurfaceRLE")]
    public static bool set_surface_rle (Surface surface, bool enabled);

    /**
     * Perform a stretched pixel copy from one surface to another.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_StretchSurface]]
     *
     * @param src the {@link Surface} structure to be copied from.
     * @param src_rect the {@link Rect.Rect} structure representing the
     * rectangle to be copied, or null to copy the entire surface.
     * @param dst the {@link Surface} structure that is the blit target.
     * @param dst_rect the {@link Rect.Rect} structure representing the target
     * rectangle in the destination surface, or nullto fill the entire
     * destination surface.
     * @param scale_mode the {@link ScaleMode} to be used.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see blit_surface_scaled
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_StretchSurface")]
    public static bool stretch_surface (Surface src,
            Rect.Rect src_rect,
            Surface dst,
            Rect.Rect dst_rect,
            ScaleMode scale_mode);

    [CCode (cname = "SDL_SurfaceHasAlternateImages")]
    public static bool surface_has_alternate_images (Surface surface);

    [CCode (cname = "SDL_SurfaceHasColorKey")]
    public static bool surface_has_color_key (Surface surface);

    [CCode (cname = "SDL_SurfaceHasRLE")]
    public static bool surface_has_rle (Surface surface);

    [CCode (cname = "SDL_UnlockSurface")]
    public static void unlock_surface (Surface surface);

    [CCode (cname = "SDL_WriteSurfacePixel")]
    public static bool write_surface_pixel (Surface surface,
            int x,
            int y,
            uint8 r,
            uint8 g,
            uint8 b,
            uint8 a);

    [CCode (cname = "SDL_WriteSurfacePixelFloat")]
    public static bool write_surface_pixel_float (Surface surface,
            int x,
            int y,
            float r,
            float g,
            float b,
            float a);

    [CCode (cname = "SDL_SurfaceFlags", cprefix = "SDL_SURFACE_", has_type_id = false)]
    public enum SurfaceFlags {
        PREALLOCATED,
        LOCK_NEEDED,
        LOCKED,
        SIMD_ALIGNED,
    }

    [Compact, CCode (cname = "SDL_Surface", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Surface {
        public SurfaceFlags flags;
        public Pixels.PixelFormat format;
        public int w;
        public int h;
        public int pitch;
        public void* pixels;
        public int refcount;
        public void* reserved;
    }

    /**
     * The flip mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FlipMode]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FlipMode", cprefix = "SDL_FLIP_", has_type_id = false)]
    public enum FlipMode {
    /**
     * Do not flip
     *
     */
        NONE,

        /**
         * Flip horizontally
         *
         */
        HORIZONTAL,

        /**
         * Flip vertically
         *
         */
        VERTICAL,

        /**
         * Flip horizontally and vertically (not a diagonal flip)
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        HORIZONTAL_AND_VERTICAL
    } // FlipMode

    /**
     * The scaling mode.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ScaleMode]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ScaleMode", cprefix = "SDL_SCALEMODE_", has_type_id = false)]
    public enum ScaleMode {
    /**
     * Invalid
     *
     */
        INVALID,

        /**
         * Nearest pixel sampling
         *
         */
        NEAREST,

        /**
         * Linear filtering
         *
         */
        LINEAR,

        /**
         * Nearest pixel sampling with improved scaling for pixel art.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_SCALEMODE_PIXELART")]
        PIXEL_ART,
    } // ScaleMode

    [CCode (cname = "SDL_MUSTLOCK")]
    public static bool must_lock (Surface s);

    namespace PropSurface {
        [CCode (cname = "SDL_PROP_SURFACE_SDR_WHITE_POINT_FLOAT")]
        public const string SDR_WHITE_POINT_FLOAT;

        [CCode (cname = "SDL_PROP_SURFACE_HDR_HEADROOM_FLOAT")]
        public const string HDR_HEADROOM_FLOAT;

        [CCode (cname = "SDL_PROP_SURFACE_TONEMAP_OPERATOR_STRING")]
        public const string TONEMAP_OPERATOR_STRING;

        [CCode (cname = "SDL_PROP_SURFACE_HOTSPOT_X_NUMBER")]
        public const string HOTSPOT_X_NUMBER;

        [CCode (cname = "SDL_PROP_SURFACE_HOTSPOT_Y_NUMBER")]
        public const string HOTSPOT_Y_NUMBER;

        /**
         * The number of degrees a surface's data is meant to be rotated
         * clockwise to make the image right-side up. Default 0.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetSurfaceProperties]]
         *
         * This is used by the camera API, if a mobile device is oriented
         * differently than what its camera provides (i.e. - the camera
         * always provides portrait images but the phone is being held in
         * landscape orientation).
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_SURFACE_ROTATION_FLOAT")]
        public const string ROTATION_FLOAT;
    } // PropSurface
} // SDL.Surface

///
/// Clipboard Handling  (SDL_clipboard.h)
///
[CCode (cheader_filename = "SDL3/SDL_clipboard.h")]
namespace SDL.Clipboard {
    [CCode (cname = "SDL_ClearClipboardData")]
    public static bool clear_clipboard_data ();

    [CCode (cname = "SDL_GetClipboardData")]
    public static void * get_clipboard_data (string mime_type, out size_t size);

    [CCode (cname = "SDL_GetClipboardMimeTypes")]
    public static unowned string[] get_clipboard_mime_types ();

    [CCode (cname = "SDL_GetClipboardText")]
    public static unowned string get_clipboard_text ();

    [CCode (cname = "SDL_GetPrimarySelectionText")]
    public static unowned string get_primary_selection_text ();

    [CCode (cname = "SDL_HasClipboardData")]
    public static bool has_clipboard_data (string mime_type);

    [CCode (cname = "SDL_HasClipboardText")]
    public static bool has_clipboard_text ();

    [CCode (cname = "SDL_HasPrimarySelectionText")]
    public static bool has_primary_selection_text ();

    [CCode (cname = "SDL_SetClipboardData", has_target = true, instance_pos = 2)]
    public static bool set_clipboard_data (ClipboardDataCallback callback,
            ClipboardCleanupCallback cleanup,
            string[] mime_types);

    [CCode (cname = "SDL_SetClipboardText")]
    public static bool set_clipboard_text (string text);

    [CCode (cname = "SDL_SetPrimarySelectionText")]
    public static bool set_primary_selection_text (string text);

    [CCode (cname = "SDL_ClipboardCleanupCallback", has_target = true)]
    public delegate void ClipboardCleanupCallback ();

    [CCode (cname = "SDL_ClipboardDataCallback", has_target = true, instance_pos = 0)]
    public delegate void ClipboardDataCallback (string mime_type, size_t size);
} // SDL.Clipboard

///
/// Vulkan Support (SDL_vulkan.h)
///
[CCode (cheader_filename = "SDL3/SDL_vulkan.h")]
namespace SDL.Vulkan {
    [CCode (cname = "SDL_Vulkan_CreateSurface")]
    public static bool create_surface (Video.Window window,
            VkInstance instance,
            VkAllocationCallbacks? allocator,
            out VkSurfaceKHR surface);

    [CCode (cname = "SDL_Vulkan_CreateSurface")]
    public static void destroy_surface (VkInstance instance,
            VkSurfaceKHR surface,
            VkAllocationCallbacks? allocator);

    [CCode (cname = "SDL_Vulkan_GetInstanceExtensions")]
    public static unowned string[] get_instance_extensions ();

    [CCode (cname = "SDL_Vulkan_GetPresentationSupport")]
    public static bool get_presentation_support (VkInstance instance,
            VkPhysicalDevice physical_device,
            uint32 queue_family_index);

    [CCode (cname = "SDL_Vulkan_GetVkGetInstanceProcAddr")]
    public static StdInc.FunctionPointer ? get_vk_get_instance_proc_addr ();

    [CCode (cname = "SDL_Vulkan_LoadLibrary")]
    public static bool load_library (string path);

    [CCode (cname = "SDL_Vulkan_UnloadLibrary")]
    public static void unload_library ();

    [Compact, CCode (cname = "VkInstance", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class VkInstance {}

    [SimpleType, CCode (cname = "VkSurfaceKHR", has_type_id = false)]
    public struct VkSurfaceKHR : uint64 {}

    [Compact, CCode (cname = "VkPhysicalDevice", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class VkPhysicalDevice {}

    [Compact, CCode (cname = "VkAllocationCallbacks", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class VkAllocationCallbacks {}
} // SDL.Vulkan

///
/// Metal Support (SDL_metal.h)
///
[CCode (cheader_filename = "SDL3/SDL_metal.h")]
namespace SDL.Metal {
    [CCode (cname = "SDL_Metal_CreateView")]
    public static MetalView create_view (Video.Window window);

    [CCode (cname = "SDL_Metal_DestroyView")]
    public static void destroy_view (MetalView view);

    [CCode (cname = "SDL_Metal_GetLayer")]
    public static void * get_layer (MetalView view);

    [Compact, CCode (cname = "SDL_MetalView", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class MetalView {}
} // SDL.Metal

///
/// Camera Support (SDL_camera.h)
///
[CCode (cheader_filename = "SDL3/SDL_camera.h")]
namespace SDL.Camera {
    [CCode (cname = "SDL_AcquireCameraFrame")]
    public static Surface.Surface ? aquire_camera_frame (Camera camera, out uint64 timestamp_ns);

    [CCode (cname = "SDL_CloseCamera")]
    public static void close_camera (Camera camera);

    [CCode (cname = "SDL_GetCameraDriver")]
    public static unowned string get_camera_driver (int index);

    [CCode (cname = "SDL_GetCameraFormat")]
    public static bool get_camera_format (Camera camera, out CameraSpec spec);

    [CCode (cname = "SDL_GetCameraID")]
    public static CameraID get_camera_id (Camera camera);

    [CCode (cname = "SDL_GetCameraName")]
    public static unowned string get_camera_name (CameraID instance_id);

    /**
     * Query if camera access has been approved by the user.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetCameraPermissionState]]
     *
     * @param camera the opened camera device to query.
     *
     * @return Returns an {@link CameraPermissionState} value indicating if
     * access is granted, or {@link CameraPermissionState.PENDING} if the
     * decision is still pending.
     *
     * @since 3.2.0
     *
     * @see open_camera
     * @see close_camera
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetCameraPermissionState")]
    public static CameraPermissionState get_camera_permission_state (Camera camera);

    [CCode (cname = "SDL_GetCameraPosition")]
    public static CameraPosition get_camera_position (CameraID instance_id);

    [CCode (cname = "SDL_GetCameraProperties")]
    public static SDL.Properties.PropertiesID get_camera_properties (Camera camera);

    [CCode (cname = "SDL_GetCameras")]
    public static CameraID[] ? get_cameras ();

    [CCode (cname = "SDL_GetCameraSupportedFormats")]
    public static CameraSpec[] ? get_camera_supported_formats (CameraID instance_id);

    [CCode (cname = "SDL_GetCurrentCameraDriver")]
    public static unowned string get_current_camera_driver ();

    [CCode (cname = "SDL_GetNumCameraDrivers")]
    public static int get_num_camera_dirvers ();

    [CCode (cname = "SDL_OpenCamera")]
    public static Camera open_camera (CameraID instance_id, CameraSpec? spec);

    [CCode (cname = "SDL_ReleaseCameraFrame")]
    public static void release_camera_frame (Camera camera, Surface.Surface frame);

    [Compact, CCode (cname = "SDL_Camera", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Camera {}

    [SimpleType, CCode (cname = "SDL_CameraID", has_type_id = false)]
    public struct CameraID : uint32 {}

    [CCode (cname = "SDL_CameraSpec", has_type_id = false)]
    public struct CameraSpec {
        public Pixels.PixelFormat format;
        [CCode (cname = "colorspace")] Pixels.ColorSpace color_space;
        public int width;
        public int height;
        public int framerate_numerator;
        public int framerate_denominator;
    } // CameraSpec

    /**
     * The current state of a request for camera access.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CameraPermissionState]]
     *
     * @since 3.4.0
     *
     * @see get_camera_permission_state
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_CameraPosition", cprefix = "SDL_CAMERA_POSITION_", has_type_id = false)]
    public enum CameraPermissionState {
    /**
     * The user denied access.
     *
     */
        DENIED,

        /**
         * Waiting for user response,
         *
         */
        PENDING,

        /**
         * The camera is approved for use.
         *
         */
        APPROVED,
    } // CameraPermissionState

    [CCode (cname = "SDL_CameraPosition", cprefix = "SDL_CAMERA_POSITION_", has_type_id = false)]
    public enum CameraPosition {
        UNKNOWN,
        FRONT_FACING,
        BACK_FACING,
    } // CameraPosition
} // SDL.SDL3.Camera

///
/// INPUT EVENTS
///

///
/// Event Handling (SDL_events.h)
///
[CCode (cheader_filename = "SDL3/SDL_events.h")]
namespace SDL.Events {
    [CCode (cname = "SDL_AddEventWatch")]
    public static bool add_event_watch (EventFilter filter);

    [CCode (cname = "SDL_EventEnabled")]
    public static bool event_enabled (EventType type);

    [CCode (cname = "SDL_FilterEvents")]
    public static void filter_events (EventFilter filter);

    [CCode (cname = "SDL_FlushEvent")]
    public static void flush_event (EventType type);

    [CCode (cname = "SDL_FlushEvents")]
    public static void flush_events (EventType min_type, EventType max_type);

    /**
     * Generate an English description of an event.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetEventDescription]]
     *
     * @param event an event to describe. May be null.
     * @param buf the buffer to fill with the description string. May be null.
     * @param buf_len the maximum bytes that can be written to buf.
     *
     * @return number of bytes needed for the full string, not counting the
     * null-terminator byte.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetEventDescription")]
    public unowned int get_event_description (EventType ? event, out string ? buf,
            int buf_len);

    [CCode (cname = "SDL_GetEventFilter")]
    public static bool get_event_filter (out EventFilter filter);

    [CCode (cname = "SDL_GetWindowFromEvent")]
    public static Video.Window get_window_from_event (Event event);

    [CCode (cname = "SDL_HasEvent")]
    public static bool has_event (EventType type);

    [CCode (cname = "SDL_HasEvents")]
    public static bool has_events (EventType min_type, EventType max_type);

    [CCode (cname = "SDL_PeepEvents")]
    public static int peep_events (Event[] events, EventAction action, EventType min_type,
            EventType max_type);

    [CCode (cname = "SDL_PollEvent")]
    public static bool poll_event (out Event event);

    [CCode (cname = "SDL_PumpEvents")]
    public static void pump_events ();

    [CCode (cname = "SDL_PushEvent")]
    public static bool push_event (Event event);

    [CCode (cname = "SDL_RegisterEvents")]
    public static uint32 register_events (int num_events);

    [CCode (cname = "SDL_RemoveEventWatch")]
    public static void remove_event_watch (EventFilter filter);

    [CCode (cname = "SDL_SetEventEnabled")]
    public static void set_event_enabled (EventType type, bool enabled);

    [CCode (cname = "SDL_SetEventFilter")]
    public static void set_event_filter (EventFilter filter);

    [CCode (cname = "SDL_WaitEvent")]
    public static bool wait_event (out Event event);

    [CCode (cname = "SDL_WaitEventTimeout")]
    public static bool wait_event_timeout (out Event event, int32 timeout_ms);

    [CCode (cname = "SDL_EventFilter", has_target = true, delegate_target_pos = 0)]
    public delegate int EventFilter (ref Event event);

    [CCode (cname = "SDL_AudioDeviceEvent", has_type_id = false)]
    public struct AudioDeviceEvent : CommonEvent {
        public Audio.AudioDeviceID which;
        public bool recording;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // AudioDeviceEvent

    [CCode (cname = "SDL_CameraDeviceEvent", has_type_id = false)]
    public struct CameraDeviceEvent : CommonEvent {
        public Camera.CameraID which;
    } // CameraDeviceEvent

    [CCode (cname = "SDL_ClipboardEvent", has_type_id = false)]
    public struct ClipboardEvent : CommonEvent {
        public bool owner;
        [CCode (array_length_cname = "num_mime_types", array_length_type = "Sint32")]
        public string[] mime_types;
    } // ClipboardEvent

    [CCode (cname = "SDL_CommonEvent", has_type_id = false)]
    public struct CommonEvent {
        public EventType type;
        public uint32 reserved;
        public uint64 timestamp;
    } // CommonEvent

    [CCode (cname = "SDL_DisplayEvent", has_type_id = false)]
    public struct DisplayEvent : CommonEvent {
        [CCode (cname = "displayID")]
        public Video.DisplayID display_id;
        public int32 data1;
        public int32 data2;
    } // DisplayEvent

    [CCode (cname = "SDL_DropEvent", has_type_id = false)]
    public struct DropEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public float x;
        public float y;
        public string source;
        public string data;
    } // DropEvent

    [CCode (cname = "SDL_GamepadAxisEvent", has_type_id = false)]
    public struct GamepadAxisEvent : CommonEvent {
        public Joystick.JoystickID which;
        public Gamepad.GamepadAxis axis;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
        public int16 value;
        public int16 padding4;
    } // GamepadAxisEvent

    [CCode (cname = "SDL_GamepadButtonEvent", has_type_id = false)]
    public struct GamepadButtonEvent : CommonEvent {
        public Joystick.JoystickID which;
        public Gamepad.GamepadButton button;
        public bool down;
        public uint8 padding1;
        public uint8 padding2;
    } // GamepadButtonEvent

    [CCode (cname = "SDL_GamepadDeviceEvent", has_type_id = false)]
    public struct GamepadDeviceEvent : CommonEvent {
        public Joystick.JoystickID which;
    } // GamepadDeviceEvent

    [CCode (cname = "SDL_GamepadSensorEvent", has_type_id = false)]
    public struct GamepadSensorEvent : CommonEvent {
        public Joystick.JoystickID which;
        public Sensor.SensorType sensor;
        public float data[3];
        public uint64 sensor_timestamp;
    } // GamepadSensorEvent

    [CCode (cname = "SDL_GamepadTouchpadEvent", has_type_id = false)]
    public struct GamepadTouchpadEvent : CommonEvent {
        public Joystick.JoystickID which;
        public int32 touchpad;
        public int32 finger;
        public float x;
        public float y;
        public float pressure;
    } // GamepadTouchpadEvent

    [CCode (cname = "SDL_JoyAxisEvent", has_type_id = false)]
    public struct JoyAxisEvent : CommonEvent {
        public Joystick.JoystickID which;
        public uint8 axis;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
        public int16 value;
        public uint16 padding4;
    } // JoyAxisEvent

    [CCode (cname = "SDL_JoyBallEvent", has_type_id = false)]
    public struct JoyBallEvent : CommonEvent {
        public Joystick.JoystickID which;
        public uint8 ball;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
        public int16 xrel;
        public int16 yrel;
    } // JoyBallEvent

    [CCode (cname = "SDL_JoyBatteryEvent", has_type_id = false)]
    public struct JoyBatteryEvent : CommonEvent {
        public Joystick.JoystickID which;
        public Power.PowerState state;
        public int percent;
    } // JoyBatteryEvent

    [CCode (cname = "SDL_JoyButtonEvent", has_type_id = false)]
    public struct JoyButtonEvent : CommonEvent {
        public Joystick.JoystickID which;
        public uint8 button;
        public bool down;
        public uint8 padding1;
        public uint8 padding2;
    } // JoyButtonEvent

    [CCode (cname = "SDL_JoyDeviceEvent", has_type_id = false)]
    public struct JoyDeviceEvent : CommonEvent {
        public Joystick.JoystickID which;
    } // JoyDeviceEvent;

    [CCode (cname = "SDL_JoyHatEvent", has_type_id = false)]
    public struct JoyHatEvent : CommonEvent {
        public Joystick.JoystickID which;
        public Joystick.JoystickHat hat;
        public uint8 value;
        public uint8 padding1;
        public uint8 padding2;
    } // JoyHatEvent

    [CCode (cname = "SDL_KeyboardDeviceEvent", has_type_id = false)]
    public struct KeyboardDeviceEvent : CommonEvent {
        public Keyboard.KeyboardID which;
    } // KeyboardDeviceEvent

    [CCode (cname = "SDL_KeyboardEvent", has_type_id = false)]
    public struct KeyboardEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Keyboard.KeyboardID which;
        public Keyboard.Scancode scancode;
        public Keyboard.Keycode key;
        public Keyboard.Keymod mod;
        public uint16 raw;
        public bool down;
        public bool repeat;
    } // KeyboardEvent

    [CCode (cname = "SDL_MouseButtonEvent", has_type_id = false)]
    public struct MouseButtonEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Mouse.MouseID which;
        public uint8 button;
        public bool down;
        public uint8 clicks;
        public uint8 padding;
        public float x;
        public float y;
    } // MouseButtonEvent

    [CCode (cname = "SDL_MouseDeviceEvent", has_type_id = false)]
    public struct MouseDeviceEvent : CommonEvent {
        public Mouse.MouseID which;
    } // MouseDeviceEvent

    [CCode (cname = "SDL_MouseMotionEvent", has_type_id = false)]
    public struct MouseMotionEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Mouse.MouseID which;
        public Mouse.MouseButtonFlags state;
        public float x;
        public float y;
        public float xrel;
        public float yrel;
    } // MouseMotionEvent

    [CCode (cname = "SDL_MouseWheelEvent", has_type_id = false)]
    public struct MouseWheelEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Mouse.MouseID which;
        public float x;
        public float y;
        public Mouse.MouseWheelDirection direction;
        public float mouse_x;
        public float mouse_y;
        [Version (since = "3.2.12")]
        public int32 integer_x;
        [Version (since = "3.2.12")]
        public int32 integer_y;
    } // MouseWheelEvent

    [CCode (cname = "SDL_PenAxisEvent", has_type_id = false)]
    public struct PenAxisEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Pen.PenID which;
        public Pen.PenInputFlags pen_state;
        public float x;
        public float y;
        public Pen.PenAxis axis;
        public float value;
    } // PenAxisEvent

    [CCode (cname = "SDL_PenButtonEvent", has_type_id = false)]
    public struct PenButtonEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Pen.PenID which;
        public Pen.PenInputFlags pen_state;
        public float x;
        public float y;
        public uint8 button;
        public bool down;
    } // PenButtonEvent

    [CCode (cname = "SDL_PenMotionEvent", has_type_id = false)]
    public struct PenMotionEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Pen.PenID which;
        public Pen.PenInputFlags pen_state;
        public float x;
        public float y;
    } // PenMotionEvent

    [CCode (cname = "SDL_PenProximityEvent", has_type_id = false)]
    public struct PenProximityEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Pen.PenID which;
    } // PenProximityEvent

    [CCode (cname = "SDL_PenTouchEvent", has_type_id = false)]
    public struct PenTouchEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public Pen.PenID which;
        public Pen.PenInputFlags pen_state;
        public float x;
        public float y;
        public bool eraser;
        public bool down;
    } // PenTouchEvent

    /**
     * Pinch event structure (event.pinch.*)
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PinchFingerEvent]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_PinchFingerEvent", has_type_id = false)]
    public struct PinchFingerEvent : CommonEvent {
    /**
     * The scale change since the last SDL_EVENT_PINCH_UPDATE. Scale < 1
     * is "zoom out". Scale > 1 is "zoom in".
     *
     */
        public float scale;

    /**
     * The window underneath the finger, if any
     *
     */
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
    } // PinchFingerEvent

    [CCode (cname = "SDL_QuitEvent", has_type_id = false)]
    public struct QuitEvent : CommonEvent {
    } // QuitEvent

    [CCode (cname = "SDL_RenderEvent", has_type_id = false)]
    public struct RenderEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
    } // RenderEvent

    [CCode (cname = "SDL_SensorEvent", has_type_id = false)]
    public struct SensorEvent : CommonEvent {
        public Sensor.SensorID which;
        public float data[6];
        public uint64 sensor_timestamp;
    } // SensorEvent

    [CCode (cname = "SDL_TextEditingCandidatesEvent", has_type_id = false)]
    public struct TextEditingCandidatesEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        [CCode (array_length_cname = "num_candidates", array_length_type = "Sint32")]
        public string[] candidates;
        public int32 selected_candidate;
        public bool horizontal;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // TextEditingCandidatesEvent

    [CCode (cname = "SDL_TextEditingEvent", has_type_id = false)]
    public struct TextEditingEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public string text;
        public int32 start;
        public int32 length;
    } // TextEditingEvent

    [CCode (cname = "SDL_TextInputEvent", has_type_id = false)]
    public struct TextInputEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public string text;
    } // TextInputEvent

    [CCode (cname = "SDL_TouchFingerEvent", has_type_id = false)]
    public struct TouchFingerEvent : CommonEvent {
        [CCode (cname = "touchID")]
        public Touch.TouchID touch_id;
        [CCode (cname = "fingerID")]
        public Touch.FingerID finger_id;
        public float x;
        public float y;
        public float dx;
        public float dy;
        public float pressure;
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
    } // TouchFingerEvent

    [CCode (cname = "SDL_UserEvent", has_type_id = false)]
    public struct UserEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public uint32 code;
        public void* data1;
        public void* data2;
    } // UserEvent

    [CCode (cname = "SDL_WindowEvent", has_type_id = false)]
    public struct WindowEvent : CommonEvent {
        [CCode (cname = "windowID")]
        public Video.WindowID window_id;
        public int32 data1;
        public int32 data2;
    } // WindowEvent

    [SimpleType, CCode (cname = "SDL_Event", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct Event {
        public EventType type;
        public CommonEvent common;
        public DisplayEvent display;
        public WindowEvent window;
        public KeyboardDeviceEvent kdevice;
        public KeyboardEvent key;
        public TextEditingEvent edit;
        public TextEditingCandidatesEvent edit_candidates;
        public TextInputEvent text;
        public MouseDeviceEvent mdevice;
        public MouseMotionEvent motion;
        public MouseButtonEvent button;
        public MouseWheelEvent wheel;
        public JoyDeviceEvent jdevice;
        public JoyAxisEvent jaxis;
        public JoyBallEvent jball;
        public JoyHatEvent jhat;
        public JoyButtonEvent jbutton;
        public JoyBatteryEvent jbattery;
        public GamepadDeviceEvent gdevice;
        public GamepadAxisEvent gaxis;
        public GamepadButtonEvent gbutton;
        public GamepadTouchpadEvent gtouchpad;
        public GamepadSensorEvent gsensor;
        public AudioDeviceEvent adevice;
        public CameraDeviceEvent cdevice;
        public SensorEvent sensor;
        public QuitEvent quit;
        public UserEvent user;
        public TouchFingerEvent tfinger;
        [Version (since = "3.4.0")]
        public PinchFingerEvent pinch;
        public PenProximityEvent pproximity;
        public PenTouchEvent ptouch;
        public PenMotionEvent pmotion;
        public PenButtonEvent pbutton;
        public PenAxisEvent paxis;
        public DropEvent drop;
        public RenderEvent event;
        public ClipboardEvent clipboard;
    // Necesary for ABI compatibility
        public uint8 padding[128];
    } // Event

    [CCode (cname = "SDL_EventAction", cprefix = "SDL_", has_type_id = false)]
    public enum EventAction {
        ADDEVENT,
        PEEKEVENT,
        GETEVENT
    } // EventAction

    [CCode (cname = "SDL_EventType", cprefix = "SDL_EVENT_", has_type_id = false)]
    public enum EventType {
    // Application events
        FIRST,
        QUIT,

        // Application events on ios and android
        TERMINATING,
        LOW_MEMORY,
        WILL_ENTER_BACKGROUND,
        DID_ENTER_BACKGROUND,
        WILL_ENTER_FOREGROUND,
        DID_ENTER_FOREGROUND,
        LOCALE_CHANGED,
        SYSTEM_THEME_CHANGED,

        // Display events
        DISPLAY_ORIENTATION,
        DISPLAY_ADDED,
        DISPLAY_REMOVED,
        DISPLAY_MOVED,
        DISPLAY_DESKTOP_MODE_CHANGED,
        DISPLAY_CURRENT_MODE_CHANGED,
        DISPLAY_CONTENT_SCALE_CHANGED,

        /**
         * Display has changed usable bounds.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        DISPLAY_USABLE_BOUNDS_CHANGED,

        // Window events
        WINDOW_SHOWN,
        WINDOW_HIDDEN,
        WINDOW_EXPOSED,
        WINDOW_MOVED,
        WINDOW_RESIZED,
        WINDOW_PIXEL_SIZE_CHANGED,
        WINDOW_METAL_VIEW_RESIZED,
        WINDOW_MINIMIZED,
        WINDOW_MAXIMIZED,
        WINDOW_RESTORED,
        WINDOW_MOUSE_ENTER,
        WINDOW_MOUSE_LEAVE,
        WINDOW_FOCUS_GAINED,
        WINDOW_FOCUS_LOST,
        WINDOW_CLOSE_REQUESTED,
        WINDOW_HIT_TEST,
        WINDOW_ICCPROF_CHANGED,
        WINDOW_DISPLAY_CHANGED,
        WINDOW_DISPLAY_SCALE_CHANGED,
        WINDOW_SAFE_AREA_CHANGED,
        WINDOW_OCCLUDED,
        WINDOW_ENTER_FULLSCREEN,
        WINDOW_LEAVE_FULLSCREEN,
        WINDOW_DESTROYED,
        WINDOW_HDR_STATE_CHANGED,

        // Keyboard Events
        KEY_DOWN,
        KEY_UP,
        TEXT_EDITING,
        TEXT_INPUT,
        KEYMAP_CHANGED,
        KEYBOARD_ADDED,
        KEYBOARD_REMOVED,
        TEXT_EDITING_CANDIDATES,

        /**
         * The on-screen keyboard has been shown.
         *
         */
        [Version (since = "3.4.0")]
        SCREEN_KEYBOARD_SHOWN,

        /**
         * The on-screen keyboard has been hidden.
         *
         */
        [Version (since = "3.4.0")]
        SCREEN_KEYBOARD_HIDDEN,

        // Mouse events
        MOUSE_MOTION,
        MOUSE_BUTTON_DOWN,
        MOUSE_BUTTON_UP,
        MOUSE_WHEEL,
        MOUSE_ADDED,
        MOUSE_REMOVED,

        // Joystick events
        JOYSTICK_AXIS_MOTION,
        JOYSTICK_HAT_MOTION,
        JOYSTICK_BALL_MOTION,
        JOYSTICK_BUTTON_UP,
        JOYSTICK_BUTTON_DOWN,
        JOYSTICK_REMOVED,
        JOYSTICK_ADDED,
        JOYSTICK_UPDATE_COMPLETE,
        JOYSTICK_BATTERY_UPDATED,

        // Gamepad events
        GAMEPAD_AXIS_MOTION,
        GAMEPAD_BUTTON_DOWN,
        GAMEPAD_BUTTON_UP,
        GAMEPAD_ADDED,
        GAMEPAD_REMOVED,
        GAMEPAD_REMAPPED,
        GAMEPAD_TOUCHPAD_DOWN,
        GAMEPAD_TOUCHPAD_MOTION,
        GAMEPAD_TOUCHPAD_UP,
        GAMEPAD_SENSOR_UPDATE,
        GAMEPAD_UPDATE_COMPLETE,
        GAMEPAD_STEAM_HANDLE_UPDATED,

        // Touch events
        FINGER_DOWN,
        FINGER_UP,
        FINGER_MOTION,
        FINGER_CANCELED,

        /// Pinch Events

        /**
         * Pinch gesture started.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        PINCH_BEGIN,

        /**
         * Pinch gesture updated.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        PINCH_UPDATE,

        /**
         * Pinch gesture ended.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        PINCH_END,

        // Clipboard events
        CLIPBOARD_UPDATE,

        // Drag and drop events
        DROP_FILE,
        DROP_TEXT,
        DROP_BEGIN,
        DROP_COMPLETE,
        DROP_POSITION,

        // Audio hotplug events
        AUDIO_DEVICE_ADDED,
        AUDIO_DEVICE_REMOVED,
        AUDIO_DEVICE_FORMAT_CHANGED,

        // Sensor events
        SENSOR_UPDATE,

        // Presure sensitive events
        PEN_PROXIMITY_IN,
        PEN_PROXIMITY_OUT,
        PEN_DOWN,
        PEN_UP,
        PEN_BUTTON_DOWN,
        PEN_BUTTON_UP,
        PEN_MOTION,
        PEN_AXIS,

        // Camera hotplug events
        CAMERA_DEVICE_ADDED,
        CAMERA_DEVICE_REMOVED,
        CAMERA_DEVICE_APPROVED,
        CAMERA_DEVICE_DENIED,

        // Render events
        RENDER_TARGETS_RESET,
        RENDER_DEVICE_RESET,
        RENDER_DEVICE_LOST,

        // Reserved events for private platforms
        PRIVATE0,
        PRIVATE1,
        PRIVATE2,
        PRIVATE3,

        // Internal events
        POLL_SENTINEL,

        // EVENT_USER and EVENT_LAST are for your use
        USER,
        LAST,

        // This just makes sure the enum is the size of Uint32 on C
        ENUM_PADDING;

    // This implementes aliases from the enum
    [CCode (cname = "SDL_EVENT_WINDOW_FIRST")]
    public const EventType WINDOW_FIRST;

    [CCode (cname = "SDL_EVENT_WINDOW_LAST")]
    public const EventType WINDOW_LAST;

    [CCode (cname = "SDL_EVENT_DISPLAY_FIRST")]
    public const EventType DISPLAY_FIRST;

    [CCode (cname = "SDL_EVENT_DISPLAY_LAST")]
    public const EventType DISPLAY_LAST;
    } // EventType
} // SDL.Events

///
/// Keyboard Support (SDL_keyboard.h)
///
[CCode (cheader_filename = "SDL3/SDL_keyboard.h")]
namespace SDL.Keyboard {
    [CCode (cname = "SDL_ClearComposition")]
    public static bool clear_composition (Video.Window window);

    [CCode (cname = "SDL_GetKeyboardFocus")]
    public static Video.Window get_keyboard_focus ();

    [CCode (cname = "SDL_GetKeyboardNameForID")]
    public static unowned string get_keyboard_name_for_id (KeyboardID instance_id);

    [CCode (cname = "SDL_GetKeyboards")]
    public static KeyboardID[] get_keyboards ();

    // HACK: So, bools in vala are gboolean, which are defined as ints.
    // But SDL3 uses bool in this call, which contradicts stuff thus why we
    // have to make it 'uint8' to match properly
    [CCode (cname = "SDL_GetKeyboardState")]
    public static unowned uint8[] get_keyboard_state ();

    [CCode (cname = "SDL_GetKeyFromName")]
    public static Keycode get_key_from_name (string name);

    [CCode (cname = "SDL_GetKeyFromScancode")]
    public static Keycode get_key_from_scancode (Keyboard.Scancode scancode,
            Keyboard.Keymod mod_state,
            bool key_event);

    [CCode (cname = "SDL_GetKeyName")]
    public static unowned string get_key_name (Keyboard.Keycode key);

    [CCode (cname = "SDL_GetModState")]
    public static Keymod get_mod_state ();

    [CCode (cname = "SDL_GetScancodeFromKey")]
    public static Scancode get_scancode_from_key (Keyboard.Keycode key, Keyboard.Keymod mod_state);

    [CCode (cname = "SDL_GetScancodeFromName")]
    public static Scancode get_scancode_from_name (string name);

    [CCode (cname = "SDL_GetScancodeName")]
    public static unowned string get_scancode_name (Keyboard.Scancode scancode);

    [CCode (cname = "SDL_GetTextInputArea")]
    public static bool get_text_input_area (Video.Window window, out Rect.Rect? rect, out int cursor);

    [CCode (cname = "SDL_HasKeyboard")]
    public static bool has_keyboard ();

    [CCode (cname = "SDL_HasScreenKeyboardSupport")]
    public static bool has_screen_keyboard_support ();

    [CCode (cname = "SDL_ResetKeyboard")]
    public static void reset_keyboard ();

    [CCode (cname = "SDL_ScreenKeyboardShown")]
    public static bool screen_keyboard_shown (Video.Window window);

    [CCode (cname = "SDL_SetModState")]
    public static void set_mod_state (Keyboard.Keymod mod_state);

    [CCode (cname = "SDL_SetScancodeName")]
    public static bool set_scancode_name (Keyboard.Scancode scancode, string name);

    [CCode (cname = "SDL_SetTextInputArea")]
    public static bool set_text_input_area (Video.Window window, Rect.Rect? rect, int cursor);

    [CCode (cname = "SDL_StartTextInput")]
    public static bool start_text_input (Video.Window window);

    [CCode (cname = "SDL_StartTextInputWithProperties")]
    public static bool start_text_input_with_properties (Video.Window window,
            SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_StopTextInput")]
    public static bool stop_text_input (Video.Window window);

    [CCode (cname = "SDL_TextInputActive")]
    public static bool text_input_active (Video.Window window);

    [SimpleType, CCode (cname = "SDL_KeyboardID", has_type_id = false)]
    public struct KeyboardID : uint32 {}

    [CCode (cname = "SDL_Capitalization", cprefix = "SDL_CAPITALIZE_", has_type_id = false)]
    public enum Capitalization {
        NONE,
        SENTENCES,
        WORDS,
        LETTERS,
    } // Capitalization

    [CCode (cname = "SDL_TextInputType", cprefix = "SDL_TEXTINPUT_TYPE_", has_type_id = false)]
    public enum TextInputType {
        TEXT,
        TEXT_NAME,
        TEXT_EMAIL,
        TEXT_USERNAME,
        TEXT_PASSWORD_HIDDEN,
        TEXT_PASSWORD_VISIBLE,
        NUMBER,
        NUMBER_PASSWORD_HIDDEN,
        NUMBER_PASSWORD_VISIBLE,
    } // TextInputType

    namespace PropTextinput {
        [CCode (cname = "SDL_PROP_TEXTINPUT_TYPE_NUMBER")]
        public const string TYPE_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTINPUT_CAPITALIZATION_NUMBER")]
        public const string CAPITALIZATION_NUMBER;

        [CCode (cname = "SDL_PROP_TEXTINPUT_AUTOCORRECT_BOOLEAN")]
        public const string AUTOCORRECT_BOOLEAN;

        [CCode (cname = "SDL_PROP_TEXTINPUT_MULTILINE_BOOLEAN")]
        public const string MULTILINE_BOOLEAN;

        // Android
        [CCode (cname = "SDL_PROP_TEXTINPUT_ANDROID_INPUTTYPE_NUMBER")]
        public const string ANDROID_INPUTTYPE_NUMBER;
    } // PropTextinput

    ///
    /// Keyboard Keycodes (SDL_keycode.h)
    ///
    [CCode (cheader_filename = "SDL3/SDL_keycode.h", cname = "SDLK_EXTENDED_MASK")]
    public const uint32 SDLK_EXTENDED_MASK;

    [CCode (cheader_filename = "SDL3/SDL_keycode.h", cname = "SDLK_SCANCODE_MASK")]
    public const uint32 SDLK_SCANCODE_MASK;

    [CCode (cheader_filename = "SDL3/SDL_keycode.h", cname = "SDL_SCANCODE_TO_KEYCODE")]
    public static uint32 scancode_to_keycode (uint32 x);

    [CCode (cheader_filename = "SDL3/SDL_keycode.h", cname = "SDL_Keycode", cprefix = "SDLK_",
    has_type_id = false)]
    public enum Keycode {
        UNKNOWN,
        RETURN,
        ESCAPE,
        BACKSPACE,
        TAB,
        SPACE,
        EXCLAIM,
        DBLAPOSTROPHE,
        HASH,
        DOLLAR,
        PERCENT,
        AMPERSAND,
        APOSTROPHE,
        LEFTPAREN,
        RIGHTPAREN,
        ASTERISK,
        PLUS,
        COMMA,
        MINUS,
        PERIOD,
        SLASH,
        [CCode (cname = "SDLK_0")]
        ZERO,
        [CCode (cname = "SDLK_1")]
        ONE,
        [CCode (cname = "SDLK_2")]
        TWO,
        [CCode (cname = "SDLK_3")]
        THREE,
        [CCode (cname = "SDLK_4")]
        FOUR,
        [CCode (cname = "SDLK_5")]
        FIVE,
        [CCode (cname = "SDLK_6")]
        SIX,
        [CCode (cname = "SDLK_7")]
        SEVEN,
        [CCode (cname = "SDLK_8")]
        EIGHT,
        [CCode (cname = "SDLK_9")]
        NINE,
        COLON,
        SEMICOLON,
        LESS,
        EQUALS,
        GREATER,
        QUESTION,
        AT,
        LEFTBRACKET,
        BACKSLASH,
        RIGHTBRACKET,
        CARET,
        UNDERSCORE,
        GRAVE,
        A,
        B,
        C,
        D,
        E,
        F,
        G,
        H,
        I,
        J,
        K,
        L,
        M,
        N,
        O,
        P,
        Q,
        R,
        S,
        T,
        U,
        V,
        W,
        X,
        Y,
        Z,
        LEFTBRACE,
        PIPE,
        RIGHTBRACE,
        TILDE,
        DELETE,
        PLUSMINUS,
        CAPSLOCK,
        F1,
        F2,
        F3,
        F4,
        F5,
        F6,
        F7,
        F8,
        F9,
        F10,
        F11,
        F12,
        PRINTSCREEN,
        SCROLLLOCK,
        PAUSE,
        INSERT,
        HOME,
        PAGEUP,
        END,
        PAGEDOWN,
        RIGHT,
        LEFT,
        DOWN,
        UP,
        NUMLOCKCLEAR,
        KP_DIVIDE,
        KP_MULTIPLY,
        KP_MINUS,
        KP_PLUS,
        KP_ENTER,
        KP_1,
        KP_2,
        KP_3,
        KP_4,
        KP_5,
        KP_6,
        KP_7,
        KP_8,
        KP_9,
        KP_0,
        KP_PERIOD,
        APPLICATION,
        POWER,
        KP_EQUALS,
        F13,
        F14,
        F15,
        F16,
        F17,
        F18,
        F19,
        F20,
        F21,
        F22,
        F23,
        F24,
        EXECUTE,
        HELP,
        MENU,
        SELECT,
        STOP,
        AGAIN,
        UNDO,
        CUT,
        COPY,
        PASTE,
        FIND,
        MUTE,
        VOLUMEUP,
        VOLUMEDOWN,
        KP_COMMA,
        KP_EQUALSAS400,
        ALTERASE,
        SYSREQ,
        CANCEL,
        CLEAR,
        PRIOR,
        RETURN2,
        SEPARATOR,
        OUT,
        OPER,
        CLEARAGAIN,
        CRSEL,
        EXSEL,
        KP_00,
        KP_000,
        THOUSANDSSEPARATOR,
        DECIMALSEPARATOR,
        CURRENCYUNIT,
        CURRENCYSUBUNIT,
        KP_LEFTPAREN,
        KP_RIGHTPAREN,
        KP_LEFTBRACE,
        KP_RIGHTBRACE,
        KP_TAB,
        KP_BACKSPACE,
        KP_A,
        KP_B,
        KP_C,
        KP_D,
        KP_E,
        KP_F,
        KP_XOR,
        KP_POWER,
        KP_PERCENT,
        KP_LESS,
        KP_GREATER,
        KP_AMPERSAND,
        KP_DBLAMPERSAND,
        KP_VERTICALBAR,
        KP_DBLVERTICALBAR,
        KP_COLON,
        KP_HASH,
        KP_SPACE,
        KP_AT,
        KP_EXCLAM,
        KP_MEMSTORE,
        KP_MEMRECALL,
        KP_MEMCLEAR,
        KP_MEMADD,
        KP_MEMSUBTRACT,
        KP_MEMMULTIPLY,
        KP_MEMDIVIDE,
        KP_PLUSMINUS,
        KP_CLEAR,
        KP_CLEARENTRY,
        KP_BINARY,
        KP_OCTAL,
        KP_DECIMAL,
        KP_HEXADECIMAL,
        LCTRL,
        LSHIFT,
        LALT,
        LGUI,
        RCTRL,
        RSHIFT,
        RALT,
        RGUI,
        MODE,
        SLEEP,
        WAKE,
        CHANNEL_INCREMENT,
        CHANNEL_DECREMENT,
        MEDIA_PLAY,
        MEDIA_PAUSE,
        MEDIA_RECORD,
        MEDIA_FAST_FORWARD,
        MEDIA_REWIND,
        MEDIA_NEXT_TRACK,
        MEDIA_PREVIOUS_TRACK,
        MEDIA_STOP,
        MEDIA_EJECT,
        MEDIA_PLAY_PAUSE,
        MEDIA_SELECT,
        AC_NEW,
        AC_OPEN,
        AC_CLOSE,
        AC_EXIT,
        AC_SAVE,
        AC_PRINT,
        AC_PROPERTIES,
        AC_SEARCH,
        AC_HOME,
        AC_BACK,
        AC_FORWARD,
        AC_STOP,
        AC_REFRESH,
        AC_BOOKMARKS,
        SOFTLEFT,
        SOFTRIGHT,
        CALL,
        ENDCALL,
        LEFT_TAB,
        LEVEL5_SHIFT,
        MULTI_KEY_COMPOSE,
        LMETA,
        RMETA,
        LHYPER,
        RHYPER,
    } // Keycode

    [CCode (cheader_filename = "SDL3/SDL_keycode.h", cname = "Uint16", cprefix = "SDL_KMOD_",
    has_type_id = false)]
    public enum Keymod {
        NONE,
        LSHIFT,
        RSHIFT,
        LEVEL5,
        LCTRL,
        RCTRL,
        LALT,
        RALT,
        LGUI,
        RGUI,
        NUM,
        CAPS,
        MODE,
        SCROLL,
        CTRL,
        SHIFT,
        ALT,
        GUI,
    } // Keymod

    ///
    /// Keyboard Scancodes (SDL_scancode.h)
    ///
    [CCode (cheader_filename = "SDL3/SDL_scancode.h", cname = "SDL_Scancode",
    cprefix = "SDL_SCANCODE_", has_type_id = false)]
    public enum Scancode {
        UNKNOWN,
        A,
        B,
        C,
        D,
        E,
        F,
        G,
        H,
        I,
        J,
        K,
        L,
        M,
        N,
        O,
        P,
        Q,
        R,
        S,
        T,
        U,
        V,
        W,
        X,
        Y,
        Z,
        [CCode (cname = "SDL_SCANCODE_1")]
        ONE,
        [CCode (cname = "SDL_SCANCODE_2")]
        TWO,
        [CCode (cname = "SDL_SCANCODE_3")]
        THREE,
        [CCode (cname = "SDL_SCANCODE_4")]
        FOUR,
        [CCode (cname = "SDL_SCANCODE_5")]
        FIVE,
        [CCode (cname = "SDL_SCANCODE_6")]
        SIX,
        [CCode (cname = "SDL_SCANCODE_7")]
        SEVEN,
        [CCode (cname = "SDL_SCANCODE_8")]
        EIGHT,
        [CCode (cname = "SDL_SCANCODE_9")]
        NINE,
        [CCode (cname = "SDL_SCANCODE_0")]
        ZERO,
        RETURN,
        ESCAPE,
        BACKSPACE,
        TAB,
        SPACE,
        MINUS,
        EQUALS,
        LEFTBRACKET,
        RIGHTBRACKET,
        BACKSLASH,
        NONUSHASH,
        SEMICOLON,
        APOSTROPHE,
        GRAVE,
        COMMA,
        PERIOD,
        SLASH,
        CAPSLOCK,
        F1,
        F2,
        F3,
        F4,
        F5,
        F6,
        F7,
        F8,
        F9,
        F10,
        F11,
        F12,
        PRINTSCREEN,
        SCROLLLOCK,
        PAUSE,
        INSERT,
        HOME,
        PAGEUP,
        DELETE,
        END,
        PAGEDOWN,
        RIGHT,
        LEFT,
        DOWN,
        UP,
        NUMLOCKCLEAR,
        KP_DIVIDE,
        KP_MULTIPLY,
        KP_MINUS,
        KP_PLUS,
        KP_ENTER,
        KP_1,
        KP_2,
        KP_3,
        KP_4,
        KP_5,
        KP_6,
        KP_7,
        KP_8,
        KP_9,
        KP_0,
        KP_PERIOD,
        NONUSBACKSLASH,
        APPLICATION,
        POWER,
        KP_EQUALS,
        F13,
        F14,
        F15,
        F16,
        F17,
        F18,
        F19,
        F20,
        F21,
        F22,
        F23,
        F24,
        EXECUTE,
        HELP,
        MENU,
        SELECT,
        STOP,
        AGAIN,
        UNDO,
        CUT,
        COPY,
        PASTE,
        FIND,
        MUTE,
        VOLUMEUP,
        VOLUMEDOWN,
        KP_COMMA,
        KP_EQUALSAS400,
        INTERNATIONAL1,
        INTERNATIONAL2,
        INTERNATIONAL3,
        INTERNATIONAL4,
        INTERNATIONAL5,
        INTERNATIONAL6,
        INTERNATIONAL7,
        INTERNATIONAL8,
        INTERNATIONAL9,
        LANG1,
        LANG2,
        LANG3,
        LANG4,
        LANG5,
        LANG6,
        LANG7,
        LANG8,
        LANG9,
        ALTERASE,
        SYSREQ,
        CANCEL,
        CLEAR,
        PRIOR,
        RETURN2,
        SEPARATOR,
        OUT,
        OPER,
        CLEARAGAIN,
        CRSEL,
        EXSEL,
        KP_00,
        KP_000,
        THOUSANDSSEPARATOR,
        DECIMALSEPARATOR,
        CURRENCYUNIT,
        CURRENCYSUBUNIT,
        KP_LEFTPAREN,
        KP_RIGHTPAREN,
        KP_LEFTBRACE,
        KP_RIGHTBRACE,
        KP_TAB,
        KP_BACKSPACE,
        KP_A,
        KP_B,
        KP_C,
        KP_D,
        KP_E,
        KP_F,
        KP_XOR,
        KP_POWER,
        KP_PERCENT,
        KP_LESS,
        KP_GREATER,
        KP_AMPERSAND,
        KP_DBLAMPERSAND,
        KP_VERTICALBAR,
        KP_DBLVERTICALBAR,
        KP_COLON,
        KP_HASH,
        KP_SPACE,
        KP_AT,
        KP_EXCLAM,
        KP_MEMSTORE,
        KP_MEMRECALL,
        KP_MEMCLEAR,
        KP_MEMADD,
        KP_MEMSUBTRACT,
        KP_MEMMULTIPLY,
        KP_MEMDIVIDE,
        KP_PLUSMINUS,
        KP_CLEAR,
        KP_CLEARENTRY,
        KP_BINARY,
        KP_OCTAL,
        KP_DECIMAL,
        KP_HEXADECIMAL,
        LCTRL,
        LSHIFT,
        LALT,
        LGUI,
        RCTRL,
        RSHIFT,
        RALT,
        RGUI,
        MODE,
        SLEEP,
        WAKE,
        CHANNEL_INCREMENT,
        CHANNEL_DECREMENT,
        MEDIA_PLAY,
        MEDIA_PAUSE,
        MEDIA_RECORD,
        MEDIA_FAST_FORWARD,
        MEDIA_REWIND,
        MEDIA_NEXT_TRACK,
        MEDIA_PREVIOUS_TRACK,
        MEDIA_STOP,
        MEDIA_EJECT,
        MEDIA_PLAY_PAUSE,
        MEDIA_SELECT,
        AC_NEW,
        AC_OPEN,
        AC_CLOSE,
        AC_EXIT,
        AC_SAVE,
        AC_PRINT,
        AC_PROPERTIES,
        AC_SEARCH,
        AC_HOME,
        AC_BACK,
        AC_FORWARD,
        AC_STOP,
        AC_REFRESH,
        AC_BOOKMARKS,
        SOFTLEFT,
        SOFTRIGHT,
        CALL,
        ENDCALL,
        RESERVED,
        COUNT,
    } // Scancode
} // SDL.Keyboard

///
/// Mouse Support (SDL_mouse.h)
///
[CCode (cheader_filename = "SDL3/SDL_mouse.h")]
namespace SDL.Mouse {
    [CCode (cname = "SDL_CaptureMouse")]
    public static bool capture_mouse (bool enabled);

    /**
     * Create an animated color cursor.
     *
     * * [[https://wiki.libsdl.org/SDL3/SDL_CreateAnimatedCursor]]
     *
     * @param frames an array of cursor images composing the animation.
     * @param hot_x the x position of the cursor hot spot.
     * @param hot_y the y position of the cursor hot spot.
     *
     * @return the new cursor on success or NULL on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see Surface.add_surface_alternate_image
     * @see create_cursor
     * @see create_color_cursor
     * @see create_system_cursor
     * @see destroy_cursor
     * @see set_cursor
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_CreateAnimatedCursor")]
    public static Cursor ? create_animated_cursor (CursorFrameInfo[] frames, int hot_x, int hot_y);

    [CCode (cname = "SDL_CreateColorCursor")]
    public static Cursor ? create_color_cursor (Surface.Surface ssurface, int hot_x, int hot_y);

    [CCode (cname = "SDL_CreateCursor")]
    public static Cursor ? create_cursor ([CCode (array_length = false)] uint8[] data,
            [CCode (array_length = false)] uint8[] mask,
            int w,
            int h,
            int hot_x,
            int hot_y);

    [CCode (cname = "SDL_CreateSystemCursor")]
    public static Cursor ? create_system_cursor (SystemCursor id);

    [CCode (cname = "SDL_CursorVisible")]
    public static bool cursor_visible ();

    [CCode (cname = "SDL_DestroyCursor")]
    public static void destroy_cursor (Cursor cursor);

    [CCode (cname = "SDL_GetCursor")]
    public static Cursor ? get_cursor ();

    [CCode (cname = "SDL_GetDefaultCursor")]
    public static Cursor ? get_default_cursor ();

    [CCode (cname = "SDL_GetGlobalMouseState")]
    public static MouseButtonFlags get_global_mouse_state (out float x, out float y);

    [CCode (cname = "SDL_GetMice")]
    public static MouseID[] get_mice ();

    [CCode (cname = "SDL_GetMouseFocus")]
    public static Video.Window get_mouse_focus ();

    [CCode (cname = "SDL_GetMouseNameForID")]
    public static unowned string ? get_mouse_name_for_id (MouseID instance_id);

    [CCode (cname = "SDL_GetMouseState")]
    public static MouseButtonFlags get_mouse_state (out float x, out float y);

    [CCode (cname = "SDL_GetRelativeMouseState")]
    public static MouseButtonFlags get_relative_mouse_state (out float x, out float y);

    [CCode (cname = "SDL_GetWindowMouseGrab")]
    public static bool get_window_mouse_grab (Video.Window window);

    [CCode (cname = "SDL_GetWindowMouseRect")]
    public static Rect.Rect ? get_window_mouse_rect (Video.Window window);

    [CCode (cname = "SDL_GetWindowRelativeMouseMode")]
    public static bool get_window_relative_mouse_mode (Video.Window window);

    [CCode (cname = "SDL_HasMouse")]
    public static bool has_mouse ();

    [CCode (cname = "SDL_HideCursor")]
    public static bool hide_cursor ();

    [CCode (cname = "SDL_SetCursor")]
    public static bool set_cursor (Cursor cursor);

    /**
     * Set a user-defined function by which to transform relative mouse inputs.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetRelativeMouseTransform]]
     *
     * @param callback a callback used to transform relative mouse motion,
     * or null for default behavior.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_SetRelativeMouseTransform", has_target = true)]
    public static bool set_relative_mouse_transform (MouseMotionTransformCallback ? callback);

    [CCode (cname = "SDL_SetWindowMouseGrab")]
    public static bool set_window_mouse_grab (Video.Window window, bool grabbed);

    [CCode (cname = "SDL_SetWindowMouseRect")]
    public static bool set_window_mouse_rect (Video.Window window, Rect.Rect rect);

    [CCode (cname = "SDL_SetWindowRelativeMouseMode")]
    public static bool set_window_relative_mouse_mode (Video.Window window, bool enabled);

    [CCode (cname = "SDL_ShowCursor")]
    public static bool show_cursor ();

    [CCode (cname = "SDL_WarpMouseGlobal")]
    public static bool warp_mouse_global (float x, float y);

    [CCode (cname = "SDL_WarpMouseInWindow")]
    public static void warp_mouse_in_window (Video.Window window, float x, float y);

    [Compact, CCode (cname = "SDL_Cursor", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Cursor {}

    [Flags, CCode (cname = "SDL_MouseButtonFlags", cprefix = "SDL_BUTTON_", has_type_id = false)]
    public enum MouseButtonFlags {
        LEFT,
        MIDDLE,
        RIGHT,
        X1,
        X2,
    } // MouseButtonFlags

    [Flags, CCode (cname = "SDL_BUTTON_MASK", has_type_id = false)]
    public static uint32 button_mask (uint32 x);

    [Flags, CCode (cname = "SDL_BUTTON_LMASK", has_type_id = false)]
    public const uint32 BUTTON_LMASK;

    [Flags, CCode (cname = "SDL_BUTTON_MMASK", has_type_id = false)]
    public const uint32 BUTTON_MMASK;

    [Flags, CCode (cname = "SDL_BUTTON_RMASK", has_type_id = false)]
    public const uint32 BUTTON_RMASK;

    [Flags, CCode (cname = "SDL_BUTTON_X1MASK", has_type_id = false)]
    public const uint32 BUTTON_X1MASK;

    [Flags, CCode (cname = "SDL_BUTTON_X2MASK", has_type_id = false)]
    public const uint32 BUTTON_X2MASK;

    [SimpleType, CCode (cname = "SDL_MouseID", has_type_id = false)]
    public struct MouseID : uint32 {}

    /**
     * A callback used to transform mouse motion delta from raw values.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MouseMotionTransformCallback]]
     *
     * @param timestamp the associated time at which this mouse motion event
     * was received.
     * @param window the associated window to which this mouse motion event
     * was addressed.
     * @param mouse_id the associated mouse from which this mouse motion event
     * was emitted.
     * @param x pointer to a ref parameter that will be treated as the resulting
     * x-axis motion.
     * @param y pointer to a ref parameter that will be treated as the resulting
     * y-axis motion.
     *
     * @since 3.4.0
     *
     * @see set_relative_mouse_transform
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_MouseMotionTransformCallback", has_target = true, instance_pos = 0)]
    public delegate void MouseMotionTransformCallback (uint64 timestamp, Video.Window window,
            MouseID mouse_id, ref float x, ref float y);

    /**
     * Animated cursor frame info.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CursorFrameInfo]]
     *
     * @since 3.4.0
     */
    [CCode (cname = "SDL_CursorFrameInfo", has_type_id = false)]
    public struct CursorFrameInfo {
    /**
     * The surface data for this frame
     *
     */
        public Surface.Surface surface;

    /**
     * The frame duration in milliseconds (a duration of 0 is infinite).
     *
     */
        public uint32 duration;
    } // CursorFrameInfo

    [CCode (cname = "SDL_MouseWheelDirection", cprefix = "SDL_MOUSEWHEEL_", has_type_id = false)]
    public enum MouseWheelDirection {
        NORMAL,
        FLIPPED,
    } // MouseWheelDirection

    [CCode (cname = "SDL_SystemCursor", cprefix = "SDL_SYSTEM_CURSOR_", has_type_id = false)]
    public enum SystemCursor {
        DEFAULT,
        TEXT,
        WAIT,
        CROSSHAIR,
        PROGRESS,
        NWSE_RESIZE,
        NESW_RESIZE,
        EW_RESIZE,
        NS_RESIZE,
        MOVE,
        NOT_ALLOWED,
        POINTER,
        NW_RESIZE,
        N_RESIZE,
        NE_RESIZE,
        E_RESIZE,
        SE_RESIZE,
        S_RESIZE,
        SW_RESIZE,
        W_RESIZE,
        COUNT,
    } // SystemCursor
} // SDL.Mouse

///
/// Joystick Support (SDL_joystick.h)
///
[CCode (cheader_filename = "SDL3/SDL_joystick.h")]
namespace SDL.Joystick {
    [CCode (cname = "SDL_AttachVirtualJoystick")]
    public static JoystickID attach_virtual_joystick (VirtualJoystickDesc desc);

    [CCode (cname = "SDL_CloseJoystick")]
    public static void close_joystick (Joystick joystick);

    [CCode (cname = "SDL_DetachVirtualJoystick")]
    public static bool detach_virtual_joystick (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickAxis")]
    public static int16 get_joystick_axis (Joystick joystick, int axis);

    [CCode (cname = "SDL_GetJoystickAxisInitialState")]
    public static bool get_joystick_axis_initial_state (Joystick joystick, int axis,
            out int16 state);

    [CCode (cname = "SDL_GetJoystickBall")]
    public static bool get_joystick_ball (Joystick joystick, int ball, out int dx, out int dy);

    [CCode (cname = "SDL_GetJoystickButton")]
    public static bool get_joystick_button (Joystick joystick, int button);

    [CCode (cname = "SDL_GetJoystickConnectionState")]
    public static JoystickConnectionState get_joystick_connection_state (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickFirmwareVersion")]
    public static uint16 get_joystick_firmware_version (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickFromID")]
    public static Joystick ? get_joystick_from_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickFromPlayerIndex")]
    public static Joystick ? get_joystick_from_player_index (int player_index);

    [CCode (cname = "SDL_GetJoystickGUID")]
    public static Guid.Guid get_joystick_guid (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickGUIDForID")]
    public static Guid.Guid get_joystick_guid_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickGUIDInfo")]
    public static void get_joystick_guid_info (Guid.Guid guid,
            out uint16 vendor,
            out uint16 product,
            out uint16 version,
            out uint16 crc16);

    [CCode (cname = "SDL_GetJoystickHat")]
    public static JoystickHat get_joystick_hat (Joystick joystick, int hat);

    [CCode (cname = "Uint8", cprefix = "SDL_HAT_", has_type_id = false)]
    public enum JoystickHat {
        CENTERED,
        UP,
        RIGHT,
        DOWN,
        LEFT,
        RIGHTUP,
        RIGHTDOWN,
        LEFTUP,
        LEFTDOWN,
    } // JoystickHat

    [CCode (cname = "SDL_GetJoystickID")]
    public static JoystickID get_joystick_id (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickName")]
    public static unowned string get_joystick_name (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickNameForID")]
    public static unowned string get_joystick_name_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickPath")]
    public static unowned string get_joystick_path (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickPathForID")]
    public static unowned string get_joystick_path_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickPlayerIndex")]
    public static int get_joystick_player_index (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickPlayerIndexForID")]
    public static int get_joystick_player_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickPowerInfo")]
    public static Power.PowerState get_joystick_power_info (Joystick joystick, out int percent);

    [CCode (cname = "SDL_GetJoystickProduct")]
    public static uint16 get_joystick_product (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickProductForID")]
    public static uint16 get_joystick_product_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickProductVersion")]
    public static uint16 get_joystick_product_version (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickProductVersionForID")]
    public static uint16 get_joystick_product_version_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickProperties")]
    public static SDL.Properties.PropertiesID get_joystick_properties (Joystick joystick);

    [CCode (cname = "SDL_GetJoysticks")]
    public static JoystickID[] get_joysticks ();

    [CCode (cname = "SDL_GetJoystickSerial")]
    public static unowned string get_joystick_serial (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickType")]
    public static JoystickType get_joystick_type (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickTypeForID")]
    public static JoystickType get_joystick_type_for_id (JoystickID instance_id);

    [CCode (cname = "SDL_GetJoystickVendor")]
    public static uint16 get_joystick_vendor (Joystick joystick);

    [CCode (cname = "SDL_GetJoystickVendorForID")]
    public static uint16 get_joystick_vendor_for_id (Joystick joystick);

    [CCode (cname = "SDL_GetNumJoystickAxes")]
    public static int get_num_joystick_axes (Joystick joystick);

    [CCode (cname = "SDL_GetNumJoystickBalls")]
    public static int get_num_joystick_balls (Joystick joystick);

    [CCode (cname = "SDL_GetNumJoystickButtons")]
    public static int get_num_joystick_buttons (Joystick joystick);

    [CCode (cname = "SDL_GetNumJoystickHats")]
    public static int get_num_joystick_hats (Joystick joystick);

    [CCode (cname = "SDL_HasJoystick")]
    public static bool has_joystick ();

    [CCode (cname = "SDL_IsJoystickVirtual")]
    public static bool is_joystick_virtual (JoystickID instance_id);

    [CCode (cname = "SDL_JoystickConnected")]
    public static bool joystick_connected (Joystick joystick);

    [CCode (cname = "SDL_JoystickEventsEnabled")]
    public static bool joystick_events_enabled ();

    [CCode (cname = "SDL_LockJoysticks")]
    public static void lock_joysticks ();

    [CCode (cname = "SDL_OpenJoystick")]
    public static Joystick ? open_joystick (JoystickID instance_id);

    [CCode (cname = "SDL_RumbleJoystick")]
    public static bool rumble_joystick (Joystick joystick,
            uint16 low_frequency_rumble,
            uint16 high_frequency_rumble,
            uint32 duration_ms);

    [CCode (cname = "SDL_RumbleJoystickTriggers")]
    public static bool rumble_joystick_triggers (Joystick joystick,
            uint16 left_rumble,
            uint16 right_rumble,
            uint32 duration_ms);

    [CCode (cname = "SDL_SendJoystickEffect")]
    public static bool send_joystick_effect (Joystick joystick, void* data, int size);

    [CCode (cname = "SDL_SendJoystickVirtualSensorData")]
    public static bool send_joystick_virtual_sensor_data (Joystick joystick,
            Sensor.SensorType type,
            uint64 sensor_timestamp,
            float[] data);

    [CCode (cname = "SDL_SetJoystickEventsEnabled")]
    public static void set_joystick_events_enabled (bool enabled);

    [CCode (cname = "SDL_SetJoystickLED")]
    public static bool set_joystick_led (Joystick joystick, uint8 red, uint8 green, uint8 blue);

    [CCode (cname = "SDL_SetJoystickPlayerIndex")]
    public static bool set_joystick_player_index (Joystick joystick, int player_index);

    [CCode (cname = "SDL_SetJoystickVirtualAxis")]
    public static bool set_joystick_virtual_axis (Joystick joystick, int axis, int16 value);

    [CCode (cname = "SDL_SetJoystickVirtualBall")]
    public static bool set_joystick_virtual_ball (Joystick joystick, int ball, int16 xrel,
            int16 yrel);

    [CCode (cname = "SDL_SetJoystickVirtualButton")]
    public static bool set_joystick_virtual_button (Joystick joystick, int button, bool down);

    [CCode (cname = "SDL_SetJoystickVirtualHat")]
    public static bool set_joystick_virtual_hat (Joystick joystick, int hat, JoystickHat value);

    [CCode (cname = "SDL_SetJoystickVirtualTouchpad")]
    public static bool set_joystick_virtual_touchpad (Joystick joystick,
            int touchpad,
            int finger,
            bool down,
            float x,
            float y,
            float pressure);

    [CCode (cname = "SDL_UnlockJoysticks")]
    public static void unlock_joystick ();

    [CCode (cname = "SDL_UpdateJoysticks")]
    public static void update_joystick ();

    [Compact, CCode (cname = "SDL_Joystick", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Joystick {}

    [SimpleType, CCode (cname = "SDL_JoystickID", has_type_id = false)]
    public struct JoystickID : uint32 {}

    [CCode (cname = "SDL_VirtualJoystickDesc", has_type_id = false)]
    public struct VirtualJoystickDesc {
        public uint32 version;
        public uint16 type;
        public uint16 padding;
        public uint16 vendor_id;
        public uint16 product_id;
        public uint16 naxes;
        public uint16 nbuttons;
        public uint16 nballs;
        public uint16 nhats;
        public uint16 ntouchpads;
        public uint16 nsensors;
        public uint16 padding2[2];
        public uint32 button_mask;
        public uint32 axis_mask;
        public string name;
        public VirtualJoystickTouchpadDesc touchpads;
        public VirtualJoystickSensorDesc sensors;
        public void* userdata;

        [CCode (cname = "Update", has_target = true, instance_pos = 0)]
        public void update ();

        [CCode (cname = "SetPlayerIndex", has_target = true, instance_pos = 0)]
        public void set_player_index (int player_index);

        [CCode (cname = "Rumble", has_target = true, instance_pos = 0)]
        public bool rumble (uint16 low_frequency_rumble, uint16 high_frequency_rumble);

        [CCode (cname = "RumbleTriggers", has_target = true, instance_pos = 0)]
        public bool rumble_triggers (uint16 left_rumble, uint16 right_rumble);

        [CCode (cname = "SetLED", has_target = true, instance_pos = 0)]
        public bool set_led (uint8 red, uint8 green, uint8 blue);

        [CCode (cname = "SendEffect", has_target = true, instance_pos = 0)]
        public bool send_effect (void* data, int size);

        [CCode (cname = "SetSensorsEnabled", has_target = true, instance_pos = 0)]
        public bool set_sensors_enabled (bool enabled);

        [CCode (cname = "Cleanup", has_target = true)]
        public void cleanup ();
    } // VirtualJoystickDesc

    [CCode (cname = "SDL_VirtualJoystickSensorDesc", has_type_id = false)]
    public struct VirtualJoystickSensorDesc {
        public Sensor.SensorType type;
        public float rate;
    } // VirtualJoystickSensorDesc

    [CCode (cname = "SDL_VirtualJoystickTouchpadDesc", has_type_id = false)]
    public struct VirtualJoystickTouchpadDesc {
        public uint16 nfingers;
        public uint16 padding[3];
    } // VirtualJoystickTouchpadDesc

    [CCode (cname = "SDL_JoystickConnectionState", cprefix = "SDL_JOYSTICK_CONNECTION_",
    has_type_id = false)]
    public enum JoystickConnectionState {
        INVALID,
        UNKNOWN,
        WIRED,
        WIRELESS,
    } // JoystickConnectionState

    [CCode (cname = "SDL_JoystickType", cprefix = "SDL_JOYSTICK_TYPE_", has_type_id = false)]
    public enum JoystickType {
        UNKNOWN,
        GAMEPAD,
        WHEEL,
        ARCADE_STICK,
        FLIGHT_STICK,
        DANCE_PAD,
        GUITAR,
        DRUM_KIT,
        ARCADE_PAD,
        THROTTLE,
        COUNT,
    } // JoystickType

    [CCode (cname = "SDL_JOYSTICK_AXIS_MAX")]
    public const int32 JOYSTICK_AXIS_MAX;

    [CCode (cname = "SDL_JOYSTICK_AXIS_MIN")]
    public const int32 JOYSTICK_AXIS_MIN;

    namespace PropJoystick {
        [CCode (cname = "SDL_PROP_JOYSTICK_CAP_MONO_LED_BOOLEAN")]
        public const string CAP_MONO_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_JOYSTICK_CAP_RGB_LED_BOOLEAN")]
        public const string CAP_RGB_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_JOYSTICK_CAP_PLAYER_LED_BOOLEAN")]
        public const string CAP_PLAYER_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_JOYSTICK_CAP_RUMBLE_BOOLEAN")]
        public const string CAP_RUMBLE_BOOLEAN;

        [CCode (cname = "SDL_PROP_JOYSTICK_CAP_TRIGGER_RUMBLE_BOOLEAN")]
        public const string CAP_TRIGGER_RUMBLE_BOOLEAN;
    } // PropJoystick
} // SDL.Joystick

///
/// Gamepad Support (SDL_gamepad.h)
///
[CCode (cheader_filename = "SDL3/SDL_gamepad.h")]
namespace SDL.Gamepad {
    [CCode (cname = "SDL_AddGamepadMapping")]
    public static int add_gamepad_mapping (string mapping);

    [CCode (cname = "SDL_AddGamepadMappingsFromFile")]
    public static int add_gamepad_mappings_from_file (string file);

    [CCode (cname = "SDL_AddGamepadMappingsFromIO")]
    public static int add_gamepad_mapping_from_io (IOStream.IOStream src, bool close_io);

    [CCode (cname = "SDL_CloseGamepad")]
    public static void close_gamepad (Gamepad gamepad);

    [CCode (cname = "SDL_GamepadConnected")]
    public static bool gamepad_connected (Gamepad gamepad);

    [CCode (cname = "SDL_GamepadEventsEnabled")]
    public static bool gamepad_events_enabled ();

    [CCode (cname = "SDL_GamepadHasAxis")]
    public static bool gamepad_has_axis (Gamepad gamepad, GamepadAxis axis);

    [CCode (cname = "SDL_GamepadHasButton")]
    public static bool gamepad_has_button (Gamepad gamepad, GamepadButton button);

    [CCode (cname = "SDL_GamepadHasSensor")]
    public static bool gamepad_has_sensor (Gamepad gamepad, Sensor.SensorType type);

    [CCode (cname = "SDL_GamepadSensorEnabled")]
    public static bool gamepad_sensor_enabled (Gamepad gamepad, Sensor.SensorType type);

    [CCode (cname = "SDL_GetGamepadAppleSFSymbolsNameForAxis")]
    public static unowned string get_gamepad_apple_sfs_symbol_name_for_axis (Gamepad gamepad,
            GamepadAxis axis);

    [CCode (cname = "SDL_GetGamepadAppleSFSymbolsNameForButton")]
    public static unowned string get_gamepad_apple_sfs_symbol_name_for_button (Gamepad gamepad,
            GamepadButton button);

    [CCode (cname = "SDL_GetGamepadAxis")]
    public static int16 get_gamepad_axis (Gamepad gamepad, GamepadAxis axis);

    [CCode (cname = "SDL_GetGamepadAxisFromString")]
    public static GamepadAxis get_gamepad_axis_from_string (string str);

    [CCode (cname = "SDL_GetGamepadBindings")]
    public static GamepadBinding[] ? get_gamepad_bindings (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadButton")]
    public static bool get_gamepad_button (Gamepad gamepad, GamepadButton button);

    [CCode (cname = "SDL_GetGamepadButtonFromString")]
    public static GamepadButton get_gamepad_button_from_string (string str);

    [CCode (cname = "SDL_GetGamepadButtonLabel")]
    public static GamepadButtonLabel get_gamepad_button_label (Gamepad gamepad,
            GamepadButton button);

    [CCode (cname = "SDL_GetGamepadButtonLabelForType")]
    public static GamepadButtonLabel get_gamepad_button_label_for_type (GamepadType type,
            GamepadButton button);

    [CCode (cname = "SDL_GetGamepadConnectionState")]
    public static Joystick.JoystickConnectionState get_gamepad_connection_state (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadFirmwareVersion")]
    public static uint16 get_gamepad_firmware_version (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadFromID")]
    public static Gamepad ? get_gamepad_from_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadFromPlayerIndex")]
    public static Gamepad ? get_gamepad_from_player_index (int player_index);

    [CCode (cname = "SDL_GetGamepadGUIDForID")]
    public static Guid.Guid get_gamepad_guid_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadID")]
    public static Joystick.JoystickID get_gamepad_id (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadJoystick")]
    public static Joystick.Joystick ? get_gamepad_joystick (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadMapping")]
    public static unowned string ? get_gamepad_mapping (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadMappingForGUID")]
    public static unowned string ? get_gamepad_mapping_for_guid (Guid.Guid guid);

    [CCode (cname = "SDL_GetGamepadMappingForID")]
    public static unowned string ? get_gamepad_mapping_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadMappings")]
    public static unowned string[] ? get_gamepad_mappings ();

    [CCode (cname = "SDL_GetGamepadName")]
    public static unowned string ? get_gamepad_name (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadNameForID")]
    public static unowned string ? get_gamepad_name_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadPath")]
    public static unowned string ? get_gamepad_path (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadPathForID")]
    public static unowned string ? get_gamepad_path_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadPlayerIndex")]
    public static int get_gamepad_player_index (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadPlayerIndexForID")]
    public static int get_gamepad_player_index_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadPowerInfo")]
    public static Power.PowerState get_gamepad_power_info (Gamepad gamepad, out int percent);

    [CCode (cname = "SDL_GetGamepadProduct")]
    public static uint16 get_gamepad_product (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadProductForID")]
    public static uint16 get_gamepad_product_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadProductVersion")]
    public static uint16 get_gamepad_product_version (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadProductVersionForID")]
    public static uint16 get_gamepad_product_version_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadProperties")]
    public static SDL.Properties.PropertiesID get_gamepad_properties (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepads")]
    public static Joystick.JoystickID[] get_gamepads ();

    [CCode (cname = "SDL_GetGamepadSensorData")]
    public static bool get_gamepad_sensor_data (Gamepad gamepad, Sensor.SensorType type,
            out float[] data);

    [CCode (cname = "SDL_GetGamepadSensorDataRate")]
    public static float get_gamepad_sensor_data_rate (Gamepad gamepad, Sensor.SensorType type);

    [CCode (cname = "SDL_GetGamepadSerial")]
    public static unowned string get_gamepad_serial (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadSteamHandle")]
    public static uint64 get_gamepad_steam_handle (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadStringForAxis")]
    public static unowned string ? get_gamepad_string_for_axis (GamepadAxis axis);

    [CCode (cname = "SDL_GetGamepadStringForButton")]
    public static unowned string ? get_gamepad_string_for_button (GamepadButton button);

    [CCode (cname = "SDL_GetGamepadStringForType")]
    public static unowned string ? get_gamepad_string_for_type (GamepadType type);

    [CCode (cname = "SDL_GetGamepadTouchpadFinger")]
    public static bool get_gamepad_touchpad_finger (Gamepad gamepad,
            int touchpad,
            int finger,
            out bool down,
            out float x,
            out float y,
            out float pressure);

    [CCode (cname = "SDL_GetGamepadType")]
    public static GamepadType get_gamepad_type (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadTypeForID")]
    public static GamepadType get_gamepad_type_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetGamepadTypeFromString")]
    public static GamepadType get_gamepad_type_from_string (string str);

    [CCode (cname = "SDL_GetGamepadVendor")]
    public static uint16 get_gamepad_vendor (Gamepad gamepad);

    [CCode (cname = "SDL_GetGamepadVendorForID")]
    public static uint16 get_gamepad_vendor_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_GetNumGamepadTouchpadFingers")]
    public static int get_num_gamepad_touchpad_fingers (Gamepad gamepad, int touchpad);

    [CCode (cname = "SDL_GetNumGamepadTouchpads")]
    public static int get_num_gamepad_touchpads (Gamepad gamepad);

    [CCode (cname = "SDL_GetRealGamepadType")]
    public static GamepadType get_real_gamepad_type (Gamepad gamepad);

    [CCode (cname = "SDL_GetRealGamepadTypeForID")]
    public static GamepadType get_real_gamepad_type_for_id (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_HasGamepad")]
    public static bool has_gamepad ();

    [CCode (cname = "SDL_IsGamepad")]
    public static bool is_gamepad (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_OpenGamepad")]
    public static Gamepad ? open_gamepad (Joystick.JoystickID instance_id);

    [CCode (cname = "SDL_ReloadGamepadMappings")]
    public static bool reload_gamepad_mappings ();

    [CCode (cname = "SDL_RumbleGamepad")]
    public static bool rumble_gamepad (Gamepad gamepad,
            uint16 low_frequency_rumble,
            uint16 high_frequency_rumble,
            uint32 duration_ms);

    [CCode (cname = "SDL_RumbleGamepadTriggers")]
    public static bool rumble_gamepad_triggers (Gamepad gamepad,
            uint16 left_rumble,
            uint16 right_rumble,
            uint32 duration_ms);

    [CCode (cname = "SDL_SendGamepadEffect")]
    public static bool send_gamepad_effect (Gamepad gamepad, void* data, int size);

    [CCode (cname = "SDL_SetGamepadEventsEnabled")]
    public static void set_gamepad_events_enabled (bool enabled);

    [CCode (cname = "SDL_SetGamepadLED")]
    public static bool set_gamepad_led (Gamepad gamepad, uint8 red, uint8 green, uint8 blue);

    [CCode (cname = "SDL_SetGamepadMapping")]
    public static bool set_gamepad_mapping (Joystick.JoystickID instance_id, string mapping);

    [CCode (cname = "SDL_SetGamepadPlayerIndex")]
    public static bool set_gamepad_player_index (Gamepad gamepad, int player_index);

    [CCode (cname = "SDL_SetGamepadSensorEnabled")]
    public static bool set_gamepad_sensor_enabled (Gamepad gamepad, Sensor.SensorType type,
            bool enabled);

    [CCode (cname = "SDL_UpdateGamepads")]
    public static void update_gamepads ();

    [Compact, CCode (cname = "SDL_Gamepad", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Gamepad {}

    [CCode (cname = "SDL_GamepadBinding", has_type_id = false)]
    public struct GamepadBinding {
        public GamepadBindingType input_type;

        [CCode (cname = "input.button")]
        public int input_button;
        [CCode (cname = "input.axis.axis")]
        public int input_axis;
        [CCode (cname = "inputaxis.axis_min")]
        public int input_axis_min;
        [CCode (cname = "input.axis.axis_max")]
        public int input_axis_max;
        [CCode (cname = "input.hat.hat")]
        public int input_hat;
        [CCode (cname = "input.hat.hat_mask")]
        public int input_hat_mask;

        public GamepadBindingType output_type;

        [CCode (cname = "output.button")]
        public GamepadButton output_button;
        [CCode (cname = "output.axis.axis")]
        public GamepadAxis output_axis;
        [CCode (cname = "output.axis.axis_min")]
        public GamepadAxis output_axis_min;
        [CCode (cname = "output.axis.axis_max")]
        public GamepadAxis output_axis_max;
    } // GamepadBinding;

    [CCode (cname = "SDL_GamepadAxis", cprefix = "SDL_GAMEPAD_AXIS_",
    has_type_id = false)]
    public enum GamepadAxis {
        INVALID,
        LEFTX,
        LEFTY,
        RIGHTX,
        RIGHTY,
        LEFT_TRIGGER,
        RIGHT_TRIGGER,
        COUNT,
    } // GamepadAxis

    [CCode (cname = "SDL_GamepadBindingType", cprefix = "SDL_GAMEPAD_BINDTYPE_",
    has_type_id = false)]
    public enum GamepadBindingType {
        NONE,
        BUTTON,
        AXIS,
        HAT,
    } // GamepadBindingType

    [CCode (cname = "SDL_GamepadButton", cprefix = "SDL_GAMEPAD_BUTTON_", has_type_id = false)]
    public enum GamepadButton {
        INVALID,
        SOUTH,
        EAST,
        WEST,
        NORTH,
        BACK,
        GUIDE,
        START,
        LEFT_STICK,
        RIGHT_STICK,
        LEFT_SHOULDER,
        RIGHT_SHOULDER,
        DPAD_UP,
        DPAD_DOWN,
        DPAD_LEFT,
        DPAD_RIGHT,
        MISC1,
        RIGHT_PADDLE1,
        LEFT_PADDLE1,
        RIGHT_PADDLE2,
        LEFT_PADDLE2,
        TOUCHPAD,
        MISC2,
        MISC3,
        MISC4,
        MISC5,
        MISC6,
        COUNT,
    } // GamepadButton

    [CCode (cname = "SDL_GamepadButtonLabel", cprefix = "SDL_GAMEPAD_BUTTON_LABEL_",
    has_type_id = false)]
    public enum GamepadButtonLabel {
        UNKNOWN,
        A,
        B,
        X,
        Y,
        CROSS,
        CIRCLE,
        SQUARE,
        TRIANGLE,
    } // GamepadButtonLabel

    [CCode (cname = "SDL_GamepadType", cprefix = "SDL_GAMEPAD_TYPE_", has_type_id = false)]
    public enum GamepadType {
        UNKNOWN,
        STANDARD,
        XBOX360,
        XBOXONE,
        PS3,
        PS4,
        PS5,
        NINTENDO_SWITCH_PRO,
        NINTENDO_SWITCH_JOYCON_LEFT,
        NINTENDO_SWITCH_JOYCON_RIGHT,
        NINTENDO_SWITCH_JOYCON_PAIR,
        GAMECUBE,
        COUNT,
    } // GamepadType

    namespace PropGamepad {
        [CCode (cname = "SDL_PROP_GAMEPAD_CAP_MONO_LED_BOOLEAN")]
        public const string CAP_MONO_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN")]
        public const string CAP_RGB_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_GAMEPAD_CAP_PLAYER_LED_BOOLEAN")]
        public const string CAP_PLAYER_LED_BOOLEAN;

        [CCode (cname = "SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN")]
        public const string CAP_RUMBLE_BOOLEAN;

        [CCode (cname = "SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN")]
        public const string CAP_TRIGGER_RUMBLE_BOOLEAN;
    } // PropGamepad
} // SDL.Gamepad

///
/// Touch Support (SDL_touch.h)
///
[CCode (cheader_filename = "SDL3/SDL_touch.h")]
namespace SDL.Touch {
    [CCode (cname = "SDL_GetTouchDeviceName")]
    public static unowned string get_touch_device_name (TouchID touch_id);

    [CCode (cname = "SDL_GetTouchDevices")]
    public static TouchID[] ? get_touch_devices ();

    [CCode (cname = "SDL_GetTouchDeviceType")]
    public static TouchDeviceType get_touch_device_type (TouchID touch_id);

    [CCode (cname = "SDL_GetTouchFingers")]
    public static Finger[] get_touch_fingers (TouchID touch_id);

    [SimpleType, CCode (cname = "SDL_FingerID", has_type_id = false)]
    public struct FingerID : uint64 {}

    [SimpleType, CCode (cname = "SDL_TouchID", has_type_id = false)]
    public struct TouchID : uint64 {}

    [CCode (cname = "SDL_Finger", has_type_id = false)]
    public struct Finger {
        public FingerID id;
        public float x;
        public float y;
        public float pressure;
    } // Finger

    [CCode (cname = "SDL_TouchDeviceType", cprefix = "SDL_TOUCH_DEVICE_", has_type_id = false)]
    public enum TouchDeviceType {
        INVALID,
        DIRECT,
        INDIRECT_ABSOLUTE,
        INDIRECT_RELATIVE,
    } // TouchDeviceType

    [CCode (cname = "SDL_MOUSE_TOUCHID")]
    public const uint64 MOUSE_TOUCHID;

    [CCode (cname = "SDL_TOUCH_MOUSEID")]
    public const uint32 TOUCH_MOUSEID;
} // SDL.Touch

///
/// Pen Support (SDL_pen.h)
///
[CCode (cheader_filename = "SDL3/SDL_pen.h")]
namespace SDL.Pen {
    /**
     * Get the device type of the given pen.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPenDeviceType]]
     *
     * @param instance_id the pen instance ID.
     *
     * @return the device type of the given pen, or
     * {@link PenDeviceType.INVALID} on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetPenDeviceType")]
    public static PenDeviceType get_pen_device_type (PenID instance_id);

    /**
     * SDL pen instance IDs.
     *
     * * [[https://wiki.libsdl.org/SDL3/SDL_PenID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_PenID", has_type_id = false)]
    public struct PenID : uint32 {}

    /**
     * Pen input flags, as reported by various pen events' pen_state field.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PenInputFlags]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Flags, CCode (cname = "SDL_PenInputFlags", cprefix = "SDL_PEN_INPUT_", has_type_id = false)]
    public enum PenInputFlags {
    /**
     * Pen is pressed down.
     *
     */
        DOWN,

        /**
         * Button 1 is pressed.
         *
         */
        BUTTON_1,

        /**
         * Button 2 is pressed.
         *
         */
        BUTTON_2,

        /**
         * Button 3 is pressed.
         *
         */
        BUTTON_3,

        /**
         * Button 4 is pressed.
         *
         */
        BUTTON_4,

        /**
         * Button 5 is pressed.
         *
         */
        BUTTON_5,

        /**
         * Eraser tip is used.
         *
         */
        ERASER_TIP,

        /**
         * Pen is in proximity.
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        IN_PROXIMITY,
    } // PenInputFlags

    /**
     * Pen axis indices.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_PenAxis", cprefix = "SDL_PEN_AXIS_", has_type_id = false)]
    public enum PenAxis {
    /**
     * Pen pressure.  Unidirectional: 0 to 1.0.
     *
     */
        PRESSURE,

        /**
         * Pen horizontal tilt angle. Bidirectional: -90.0 to 90.0
         * (left-to-right).
         *
         */
        XTILT,

        /**
         * Pen vertical tilt angle. Bidirectional: -90.0 to 90.0
         * (top-to-down).
         *
         */
        YTILT,

        /**
         * Pen distance to drawing surface. Unidirectional: 0.0 to 1.0.
         *
         */
        DISTANCE,

        /**
         * Pen barrel rotation. Bidirectional: -180 to 179.9 (clockwise, 0 is
         * facing up, -180.0 is facing down).
         *
         */
        ROTATION,

        /**
         * Pen finger wheel or slider (e.g., Airbrush Pen).
         * Unidirectional: 0 to 1.0
         *
         */
        SLIDER,

        /**
         * Pressure from squeezing the pen ("barrel pressure").
         *
         */
        TANGENTIAL_PRESSURE,

        /**
         * Total known pen axis types in this version of SDL. This number may
         * grow in future releases!
         *
         */
        COUNT,
    } // PenAxis

    /**
     * An enum that describes the type of a pen device.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PenAxis]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_PenDeviceType", cprefix = "SDL_PEN_DEVICE_TYPE_", has_type_id = false)]
    public enum PenDeviceType {
    /**
     *  Not a valid pen device.
     *
     */
        INVALID,

        /**
         *  Don't know specifics of this pen.
         *
         */
        UNKNOWN,

        /**
         *  Pen touches display.
         *
         */
        DIRECT,

        /**
         *  Pen touches something that isn't the display.
         *
         */
        INDIRECT,
    } // PenDeviceType

    /**
     * The {@link Mouse.MouseID} for mouse events simulated with pen input.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PEN_MOUSEID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_PEN_MOUSEID")]
    public const uint32 PEN_MOUSEID;

    /**
     * The {@link Touch.TouchID} for touch events simulated with pen input.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PEN_TOUCHID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_PEN_TOUCHID")]
    public const uint64 PEN_TOUCHID;
} // SDL.Pen

///
/// Sensors (SDL_sensor.h)
///
[CCode (cheader_filename = "SDL3/SDL_sensor.h")]
namespace SDL.Sensor {
    [CCode (cname = "SDL_CloseSensor")]
    public static void close_sensor (Sensor sensor);

    [CCode (cname = "SDL_GetSensorData")]
    public static bool get_sensor_data (Sensor sensor, out float[] data);

    [CCode (cname = "SDL_GetSensorFromID")]
    public static Sensor ? get_sensor_from_id (SensorID instance_id);

    [CCode (cname = "SDL_GetSensorID")]
    public static SensorID get_sensor_id (Sensor sensor);

    [CCode (cname = "SDL_GetSensorName")]
    public static unowned string ? get_sensor_name (Sensor sensor);

    [CCode (cname = "SDL_GetSensorNameForID")]
    public static unowned string ? get_sensor_name_for_id (SensorID instance_id);

    [CCode (cname = "SDL_GetSensorNonPortableType")]
    public static int get_sensor_non_portable_type (Sensor sensor);

    [CCode (cname = "SDL_GetSensorNonPortableTypeForID")]
    public static int get_sensor_non_portable_type_for_id (SensorID instance_id);

    [CCode (cname = "SDL_GetSensorProperties")]
    public static SDL.Properties.PropertiesID get_sensor_properties (Sensor sensor);

    [CCode (cname = "SDL_GetSensors")]
    public static SensorID[] get_sensors ();

    [CCode (cname = "SDL_GetSensorType")]
    public static SensorType get_sensor_type (Sensor sensor);

    [CCode (cname = "SDL_GetSensorTypeForID")]
    public static SensorType get_sensor_type_for_id (SensorID instance_id);

    [CCode (cname = "SDL_OpenSensor")]
    public static Sensor ? open_sensor (SensorID instance_id);

    [CCode (cname = "SDL_UpdateSensors")]
    public static void update_sensors ();

    [Compact, CCode (cname = "SDL_Sensor", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Sensor {}

    [SimpleType, CCode (cname = "SDL_SensorID", has_type_id = false)]
    public struct SensorID : uint32 {}

    [CCode (cname = "SDL_SensorType", cprefix = "SDL_SENSOR_", has_type_id = false)]
    public enum SensorType {
        INVALID,
        UNKNOWN,
        ACCEL,
        GYRO,
        ACCEL_L,
        GYRO_L,
        ACCEL_R,
        GYRO_R,
        COUNT,
    } // SensorType

    [CCode (cname = "SDL_STANDARD_GRAVITY")]
    public const float STANDARD_GRAVITY;
} // SDL.Sensor

///
/// HIDAPI (SDL_hidapi.h)
///
[CCode (cheader_filename = "SDL3/SDL_hidapi.h")]
namespace SDL.HidApi {
    [CCode (cname = "SDL_hid_ble_scan")]
    public static void hid_ble_scan (bool active);

    [CCode (cname = "SDL_hid_close")]
    public static int hid_close (HidDevice dev);

    [CCode (cname = "SDL_hid_device_change_count")]
    public static uint32 hid_device_change_count ();

    [CCode (cname = "SDL_hid_enumerate")]
    public static HidDeviceInfo[] ? hid_enumerate (ushort vendor_id, ushort product_id);

    [CCode (cname = "SDL_hid_exit")]
    public static int hid_exit ();

    [CCode (cname = "SDL_hid_free_enumeration")]
    public static void hid_free_enumeration (HidDeviceInfo[] devs);

    [CCode (cname = "SDL_hid_get_device_info")]
    public static HidDeviceInfo ? hid_get_device_info (HidDevice dev);

    [CCode (cname = "SDL_hid_get_feature_report")]
    public static int hid_get_feature_report (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t length);

    [CCode (cname = "SDL_hid_get_indexed_string")]
    public static int hid_get_indexed_string (HidDevice dev,
            int string_index,
            [CCode (array_length = false)] out char[] buffer,
            size_t max_length);

    [CCode (cname = "SDL_hid_get_input_report")]
    public static int hid_get_input_report (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t length);

    [CCode (cname = "SDL_hid_get_manufacturer_string")]
    public static int hid_get_manufacturer_string (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t max_length);

    [CCode (cname = "SDL_hid_get_product_string")]
    public static int hid_get_product_string (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t max_length);

    /**
     * Get the properties associated with an {@link HidDevice}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_hid_get_properties]]
     *
     * @param dev a device handle returned from {@link hid_open}.
     *
     * @return a valid property ID on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_hid_get_properties")]
    public static SDL.Properties.PropertiesID hid_get_properties (HidDevice dev);

    [CCode (cname = "SDL_hid_get_report_descriptor")]
    public static int hid_get_report_descriptor (HidDevice dev,
            [CCode (array_length = false)] out string buf,
            size_t buffer_size);

    [CCode (cname = "SDL_hid_get_serial_number_string")]
    public static int hid_get_serial_number_string (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t max_length);

    [CCode (cname = "SDL_hid_init")]
    public static int hid_init ();

    [CCode (cname = "SDL_hid_open")]
    public static HidDevice ? hid_open (ushort vendor_id, ushort product_id,
            string? serial_number);

    [CCode (cname = "SDL_hid_open_path")]
    public static HidDevice ? hid_open_path (string path);

    [CCode (cname = "SDL_hid_read")]
    public static int hid_read (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t length);

    [CCode (cname = "SDL_hid_read_timeout")]
    public static int hid_read_timeout (HidDevice dev,
            [CCode (array_length = false)] out char[] data,
            size_t length,
            int milliseconds);

    [CCode (cname = "SDL_hid_send_feature_report")]
    public static int hid_send_feature_report (HidDevice dev, char[] data);

    [CCode (cname = "SDL_hid_set_nonblocking")]
    public static int hid_set_nonblocking (HidDevice dev, int nonblock);

    [CCode (cname = "SDL_hid_write")]
    public static int hid_write (HidDevice dev, char[] data);

    [Compact, CCode (cname = "SDL_hid_device", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class HidDevice {}

    [CCode (cname = "SDL_hid_device_info", has_type_id = false)]
    public struct HidDeviceInfo {
        public string path;
        public ushort vendor_id;
        public ushort product_id;
        public string serial_number;
        public ushort release_number;
        public string manufacturer_string;
        public string product_string;
        public ushort usage_page;
        public ushort usage;
        public int interface_number;
        public int interface_class;
        public int interface_subclass;
        public int interface_protocol;
        public HidBusType bus_type;
        public HidDeviceInfo* next;
    } // HidDeviceInfo;

    [CCode (cname = "SDL_hid_bus_type", cprefix = "SDL_HID_API_BUS_", has_type_id = false)]
    public enum HidBusType {
        UNKNOWN,
        USB,
        BLUETOOTH,
        I2C,
        SPI,
    } // HidBusType

    /**
     * Properties associated with {@link hid_get_properties}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_hid_get_properties]]
     *
     * @since 3.4.0
     */
    namespace PropHidApi {
        /**
         * The libusb_device_handle associated with the device, if it was
         * opened using libusb.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_hid_get_properties]]
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_HIDAPI_LIBUSB_DEVICE_HANDLE_POINTER")]
        public const string LIBUSB_DEVICE_HANDLE_POINTER;
    }
} // SDL.HidApi

///
/// Force Feedback ("Haptic")
///

///
/// Force Feedback Support (SDL_haptic.h)
///
[CCode (cheader_filename = "SDL3/SDL_timer.h")]
namespace SDL.Haptic {
    [CCode (cname = "SDL_CloseHaptic")]
    public static void close_haptic (Haptic haptic);

    [CCode (cname = "SDL_CreateHapticEffect")]
    public static int create_haptic_effect (Haptic haptic, HapticEffect effect);

    [CCode (cname = "SDL_DestroyHapticEffect")]
    public static void destroy_haptic_effect (Haptic haptic, int effect);

    [CCode (cname = "SDL_GetHapticEffectStatus")]
    public static bool get_haptic_effect_status (Haptic haptic, int effect);

    [CCode (cname = "SDL_GetHapticFeatures")]
    public static uint32 get_haptic_features (Haptic haptic);

    [CCode (cname = "SDL_GetHapticFromID")]
    public static Haptic ? get_haptic_from_id (HapticID instance_id);

    [CCode (cname = "SDL_GetHapticName")]
    public static unowned string ? get_haptic_name (Haptic haptic);

    [CCode (cname = "SDL_GetHapticNameForID")]
    public static unowned string ? get_haptic_name_for_id (HapticID instance_id);

    [CCode (cname = "SDL_GetHaptics")]
    public static HapticID[] get_haptics ();

    [CCode (cname = "SDL_GetMaxHapticEffects")]
    public static int get_max_haptic_effects (Haptic haptic);

    [CCode (cname = "SDL_GetMaxHapticEffectsPlaying")]
    public static int get_max_haptic_effects_playing (Haptic haptic);

    [CCode (cname = "SDL_GetNumHapticAxes")]
    public static int get_num_haptic_axes (Haptic haptic);

    [CCode (cname = "SDL_HapticEffectSupported")]
    public static bool haptic_effect_supported (Haptic haptic, HapticEffect effect);

    [CCode (cname = "SDL_HapticRumbleSupported")]
    public static bool haptic_rumble_supported (Haptic haptic);

    [CCode (cname = "SDL_InitHapticRumble")]
    public static bool init_haptic_rumble (Haptic haptic);

    [CCode (cname = "SDL_IsJoystickHaptic")]
    public static bool is_joystick_haptic (Joystick.Joystick joystick);

    [CCode (cname = "SDL_IsMouseHaptic")]
    public static bool is_mouse_haptic ();

    [CCode (cname = "SDL_OpenHaptic")]
    public static Haptic ? open_haptic (HapticID instance_id);

    [CCode (cname = "SDL_OpenHapticFromJoystick")]
    public static Haptic ? open_haptic_from_joystick (Joystick.Joystick joystick);

    [CCode (cname = "SDL_OpenHapticFromMouse")]
    public static Haptic ? open_haptic_from_mouse ();

    [CCode (cname = "SDL_PauseHaptic")]
    public static bool pause_haptic (Haptic haptic);

    [CCode (cname = "SDL_PlayHapticRumble")]
    public static bool play_haptic_rumble (Haptic haptic, float strength, uint32 length);

    [CCode (cname = "SDL_ResumeHaptic")]
    public static bool resume_haptic (Haptic haptic);

    [CCode (cname = "SDL_RunHapticEffect")]
    public static bool run_haptic_effect (Haptic haptic, int effect, uint32 iterations);

    [CCode (cname = "SDL_SetHapticAutocenter")]
    public static bool set_haptic_auto_center (Haptic haptic, int autocenter);

    [CCode (cname = "SDL_SetHapticGain")]
    public static bool set_haptic_gain (Haptic haptic, int gain);

    [CCode (cname = "SDL_StopHapticEffect")]
    public static bool stop_haptic_effect (Haptic haptic, int effect);

    [CCode (cname = "SDL_StopHapticEffects")]
    public static bool stop_haptic_effects (Haptic haptic);

    [CCode (cname = "SDL_StopHapticRumble")]
    public static bool stop_haptic_rumble (Haptic haptic);

    [CCode (cname = "SDL_UpdateHapticEffect")]
    public static bool update_haptic_effect (Haptic haptic, int effect, HapticEffect data);

    [Compact, CCode (cname = "SDL_Haptic", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Haptic {}

    [SimpleType, CCode (cname = "SDL_HapticID", has_type_id = false)]
    public struct HapticID : uint32 {}

    [CCode (cname = "SDL_HapticCondition", has_type_id = false)]
    public struct HapticCondition {
        public HapticType type;
        public HapticDirection direction;
        public uint32 length;
        public uint16 delay;
        public uint16 button;
        public uint16 interval;
        public uint16 right_sat[3];
        public uint16 left_sat[3];
        public int16 right_coeff[3];
        public int16 left_coeff[3];
        public uint16 deadband[3];
        public int16 center[3];
    } // HapticCondition

    [CCode (cname = "SDL_HapticConstant", has_type_id = false)]
    public struct HapticConstant {
        public HapticType type;
        public HapticDirection direction;
        public uint32 length;
        public uint16 delay;
        public uint16 button;
        public uint16 interval;
        public int16 level;
        public uint16 attack_length;
        public uint16 attack_level;
        public uint16 fade_length;
        public uint16 fade_level;
    } // HapticConstant

    [CCode (cname = "SDL_HapticCustom", has_type_id = false)]
    public struct HapticCustom {
        public HapticType type;
        public HapticDirection direction;
        public uint32 length;
        public uint16 delay;
        public uint16 button;
        public uint16 interval;
        public uint8 channels;
        public uint16 period;
        public uint16 samples;
        public uint16* data;
        public uint16 attack_length;
        public uint16 attack_level;
        public uint16 fade_length;
        public uint16 fade_level;
    } // HapticCustom

    [CCode (cname = "SDL_HapticLeftRight", has_type_id = false)]
    public struct HapticLeftRight {
        public HapticType type;
        public uint32 length;
        public uint16 large_magnitude;
        public uint16 small_magnitude;
    } // HapticLeftRight

    [CCode (cname = "SDL_HapticPeriodic", has_type_id = false)]
    public struct HapticPeriodic {
        public HapticType type;
        public HapticDirection direction;
        public uint32 length;
        public uint16 delay;
        public uint16 button;
        public uint16 interval;
        public uint16 period;
        public int16 magnitude;
        public int16 offset;
        public uint16 phase;
        public uint16 attack_length;
        public uint16 attack_level;
        public uint16 fade_length;
        public uint16 fade_level;
    } // HapticPeriodic

    [CCode (cname = "SDL_HapticRamp", has_type_id = false)]
    public struct HapticRamp {
        public HapticType type;
        public HapticDirection direction;
        public uint32 length;
        public uint16 delay;
        public uint16 button;
        public uint16 interval;
        public int16 start;
        public int16 end;
        public uint16 attack_length;
        public uint16 attack_level;
        public uint16 fade_length;
        public uint16 fade_level;
    } // HapticRamp

    [CCode (cname = "Uint16", cprefix = "SDL_HAPTIC_", has_type_id = false)]
    public enum HapticType {
        SPRING,
        DAMPER,
        INERTIA,
        FRICTION,
        CONSTANT,
        CUSTOM,
        LEFTRIGHT,
        SINE,
        SQUARE,
        TRIANGLE,
        SAWTOOTHUP,
        SAWTOOTHDOWN,
        RAMP,
        RESERVED1,
        RESERVED2,
        RESERVED3,
    } // HapticType

    [CCode (cname = "SDL_HapticDirection", has_type_id = false)]
    public struct HapticDirection {
        public HapticDirectionType type;
        public int32 dir[3];
    } // HapticDirection

    [CCode (cname = "uint8", cprefix = "SDL_HAPTIC_", has_type_id = false)]
    public enum HapticDirectionType {
        POLAR,
        CARTESIAN,
        SPHERICAL,
    }

    [Compact, CCode (cname = "SDL_HapticEffect", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class HapticEffect {
        public HapticType type;
        public HapticConstant constant;
        public HapticPeriodic periodic;
        public HapticCondition condition;
        public HapticRamp ramp;
        public HapticLeftRight leftright;
        public HapticCustom custom;
    } // HapticEffect

    [CCode (cname = "SDL_HAPTIC_AUTOCENTER")]
    public const uint32 HAPTIC_AUTOCENTER;

    [CCode (cname = "SDL_HAPTIC_GAIN")]
    public const uint32 HAPTIC_GAIN;

    [CCode (cname = "SDL_HAPTIC_DAMPER")]
    public const uint32 HAPTIC_DAMPER;

    [CCode (cname = "SDL_HAPTIC_FRICTION")]
    public const uint32 HAPTIC_FRICTION;

    [CCode (cname = "SDL_HAPTIC_INERTIA")]
    public const uint32 HAPTIC_INERTIA;

    [CCode (cname = "SDL_HAPTIC_INFINITY")]
    public const uint32 HAPTIC_INFINITY;

    [CCode (cname = "SDL_HAPTIC_PAUSE")]
    public const uint32 HAPTIC_PAUSE;

    [CCode (cname = "SDL_HAPTIC_STATUS")]
    public const uint32 HAPTIC_STATUS;

    [CCode (cname = "SDL_HAPTIC_STEERING_AXIS")]
    public const int HAPTIC_STEERING_AXIS;
} // SDL.Haptic

///
/// Audio
///

///
/// Audio Playback, Recording, and Mixing (SDL_audio.h)
///
[CCode (cheader_filename = "SDL3/SDL_audio.h")]
namespace SDL.Audio {
    [CCode (cname = "SDL_AudioDevicePaused")]
    public static bool audio_device_paused (AudioDeviceID devid);

    [CCode (cname = "SDL_AudioStreamDevicePaused")]
    public static bool audio_stream_device_paused (AudioStream stream);

    [CCode (cname = "SDL_BindAudioStream")]
    public static bool bind_audio_stream (AudioDeviceID devid, AudioStream stream);

    [CCode (cname = "SDL_BindAudioStreams")]
    public static bool bind_audio_streams (AudioDeviceID devid, AudioStream[] streams);

    [CCode (cname = "SDL_ClearAudioStream")]
    public static bool clear_audio_stream (AudioStream stream);

    [CCode (cname = "SDL_CloseAudioDevice")]
    public static void close_audio_device (AudioDeviceID devid);

    [CCode (cname = "SDL_ConvertAudioSamples")]
    public static bool convert_audio_samples (AudioSpec src_spec,
            uint8[] src_data,
            AudioSpec dst_spec,
            out uint8[] dst_data);

    [CCode (cname = "SDL_CreateAudioStream")]
    public static AudioStream ? create_audio_stream (AudioSpec src_spec, AudioSpec? dst_spec);

    [CCode (cname = "SDL_DestroyAudioStream")]
    public static void destroy_audio_stream (AudioStream stream);

    [CCode (cname = "SDL_FlushAudioStream")]
    public static bool flush_audio_stream (AudioStream stream);

    [CCode (cname = "SDL_GetAudioDeviceChannelMap")]
    public static int[] ? get_audio_device_channel_map (AudioDeviceID devid);

    [CCode (cname = "SDL_GetAudioDeviceFormat")]
    public static bool get_audio_device_format (AudioDeviceID devid, out AudioSpec spec,
            out int sample_frames);

    [CCode (cname = "SDL_GetAudioDeviceGain")]
    public static float get_audio_device_gain (AudioDeviceID devid);

    [CCode (cname = "SDL_GetAudioDeviceName")]
    public static unowned string ? get_audio_device_name (AudioDeviceID devid);

    [CCode (cname = "SDL_GetAudioDriver")]
    public static unowned string ? get_audio_driver (int index);

    [CCode (cname = "SDL_GetAudioFormatName")]
    public static unowned string get_audio_format_name (AudioFormat format);

    [CCode (cname = "SDL_GetAudioPlaybackDevices")]
    public static AudioDeviceID[] ? get_audio_playback_devices ();

    [CCode (cname = "SDL_GetAudioRecordingDevices")]
    public static AudioDeviceID[] ? get_audio_recording_devices ();

    [CCode (cname = "SDL_GetAudioStreamAvailable")]
    public static int get_audio_stream_available (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamData")]
    public static int get_audio_stream_data (AudioStream stream, out void* buf, int len);

    [CCode (cname = "SDL_GetAudioStreamDevice")]
    public static AudioDeviceID get_audio_stream_device (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamFormat")]
    public static bool get_audio_stream_format (AudioStream stream, out AudioSpec src_spec,
            out AudioSpec dst_spec);

    [CCode (cname = "SDL_GetAudioStreamFrequencyRatio")]
    public static float get_audio_stream_frecuency_ratio (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamGain")]
    public static float get_audio_stream_gain (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamInputChannelMap")]
    public static int[] get_audio_stream_input_channel_map (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamOutputChannelMap")]
    public static int[] get_audio_stream_output_channel_map (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamProperties")]
    public static SDL.Properties.PropertiesID get_audio_stream_properties (AudioStream stream);

    [CCode (cname = "SDL_GetAudioStreamQueued")]
    public static int get_audio_stream_queued (AudioStream stream);

    [CCode (cname = "SDL_GetCurrentAudioDriver")]
    public static unowned string get_current_audio_dirver ();

    [CCode (cname = "SDL_GetNumAudioDrivers")]
    public static int get_num_audio_drivers ();

    [CCode (cname = "SDL_GetSilenceValueForFormat")]
    public static int get_silence_value_for_format (AudioFormat format);

    [CCode (cname = "SDL_IsAudioDevicePhysical")]
    public static bool is_audio_device_physical (AudioDeviceID devid);

    [CCode (cname = "SDL_IsAudioDevicePlayback")]
    public static bool is_audio_device_playback (AudioDeviceID devid);

    [CCode (cname = "SDL_LoadWAV")]
    public static bool load_wav (string path, out AudioSpec spec, out uint8[] audio_buf);

    [CCode (cname = "SDL_LoadWAV_IO")]
    public static bool load_wav_io (IOStream.IOStream src,
            bool close_io,
            AudioSpec spec,
            out uint8[] audio_buf);

    [CCode (cname = "SDL_LockAudioStream")]
    public static bool lock_audio_stream (AudioStream stream);

    [CCode (cname = "SDL_MixAudio")]
    public static bool mix_audio ([CCode (array_length = false)] out uint8[] dst,
            [CCode (array_length = false)] uint8[] src,
            AudioFormat format,
            uint32 len,
            float volume);

    [CCode (cname = "SDL_OpenAudioDevice")]
    public static AudioDeviceID open_audio_device (AudioDeviceID devid, AudioSpec? spec);

    [CCode (cname = "SDL_OpenAudioDeviceStream", has_target = true)]
    public static AudioStream ? open_audio_device_stream (AudioDeviceID devid,
            AudioSpec? spec,
            AudioStreamCallback? callback);

    [CCode (cname = "SDL_PauseAudioDevice")]
    public static bool pause_audio_device (AudioDeviceID devid);

    [CCode (cname = "SDL_PauseAudioStreamDevice")]
    public static bool pause_audio_stream_device (AudioStream stream);

    [CCode (cname = "SDL_PutAudioStreamData")]
    public static bool put_audio_stream_data (AudioStream stream, void* buf, int len);

    /**
     * Add external data to an audio stream without copying it.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PutAudioStreamDataNoCopy]]
     *
     * @param stream the stream the audio data is being added to.
     * @param buf a pointer to the audio data to add.
     * @param len the number of bytes to add to the stream.
     * @param callback the callback function to call when the data is no
     * longer needed by the stream. May be null.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see clear_audio_stream
     * @see flush_audio_stream
     * @see get_audio_stream_data
     * @see get_audio_stream_queued
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_PutAudioStreamDataNoCopy", has_target = true)]
    public static bool put_audio_stream_data_no_copy (AudioStream stream, void* buf, int len,
            AudioStreamDataCompleteCallback ? callback);

    /**
     * Add external data to an audio stream without copying it.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PutAudioStreamPlanarData]]
     *
     * @param stream the stream the audio data is being added to.
     * @param channel_buffers a pointer to an array of arrays, one array
     * per channel.
     * @param num_channels the number of arrays in channel_buffers or -1.
     * @param num_samples the number of samples per array to write to the
     * stream.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     *
     * @see clear_audio_stream
     * @see flush_audio_stream
     * @see get_audio_stream_data
     * @see get_audio_stream_queued
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_PutAudioStreamPlanarData", has_target = true)]
    public static bool put_audio_stream_planar_data (AudioStream stream, void* channel_buffers,
            int num_channels,
            int num_samples);

    [CCode (cname = "SDL_ResumeAudioDevice")]
    public static bool resume_audio_device (AudioDeviceID devid);

    [CCode (cname = "SDL_ResumeAudioStreamDevice")]
    public static bool resume_audio_stream_device (AudioStream stream);

    [CCode (cname = "SDL_SetAudioDeviceGain")]
    public static bool set_audio_device_gain (AudioDeviceID devid, float gain);

    [CCode (cname = "SDL_SetAudioPostmixCallback", has_target = true)]
    public static bool set_audio_postmix_callback (AudioDeviceID devid,
            AudioPostmixCallback callback);

    [CCode (cname = "SDL_SetAudioStreamFormat")]
    public static bool set_audio_stream_format (AudioStream stream, AudioSpec? src_spec,
            AudioSpec? dst_spec);

    [CCode (cname = "SDL_SetAudioStreamFrequencyRatio")]
    public static bool set_audio_stream_frecuency_ratio (AudioStream stream, float ratio);

    [CCode (cname = "SDL_SetAudioStreamGain")]
    public static bool set_audio_stream_gain (AudioStream stream, float gain);

    [CCode (cname = "SDL_SetAudioStreamGetCallback", has_target = true)]
    public static bool set_audio_stream_get_callback (AudioStream stream,
            AudioStreamCallback callback);

    [CCode (cname = "SDL_SetAudioStreamInputChannelMap")]
    public static bool set_audio_stream_input_channel_map (AudioStream stream, int? chmap,
            int count);

    [CCode (cname = "SDL_SetAudioStreamOutputChannelMap")]
    public static bool set_audio_stream_output_channel_map (AudioStream stream, int? chmap,
            int count);

    [CCode (cname = "SDL_SetAudioStreamPutCallback", has_target = true)]
    public static bool set_audio_stream_put_callback (AudioStream stream,
            AudioStreamCallback callback);

    [CCode (cname = "SDL_UnbindAudioStream")]
    public static void unbind_audio_stream (AudioStream? stream);

    [CCode (cname = "SDL_UnbindAudioStreams")]
    public static void unbind_audio_streams (AudioStream[] streams);

    [CCode (cname = "SDL_UnlockAudioStream")]
    public static bool unlock_audio_streams (AudioStream stream);

    [SimpleType, CCode (cname = "SDL_AudioDeviceID", has_type_id = false)]
    public struct AudioDeviceID : uint32 {}

    [CCode (cname = "SDL_AudioPostmixCallback", has_target = true, instance_pos = 0)]
    public delegate void AudioPostmixCallback (AudioSpec spec,
            [CCode (array_length = false)] ref float[] buffer,
            int buffer_length);

    [Compact, CCode (cname = "SDL_AudioStream", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class AudioStream {}

    [CCode (cname = "SDL_AudioStreamCallback", has_target = true, instance_pos = 0)]
    public delegate void AudioStreamCallback (AudioStream stream, int additional_amount,
            int total_amount);

    /**
     * A callback that fires for completed
     * {@link put_audio_stream_data_no_copy} data.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AudioStreamDataCompleteCallback]]
     *
     * @param buf the pointer provided to
     * {@link put_audio_stream_data_no_copy}.
     * @param buf_len the size of buffer, in bytes, provided to
     * {@link put_audio_stream_data_no_copy}.
     *
     * @since 3.4.0
     *
     * @see set_audio_stream_get_callback
     * @see set_audio_stream_put_callback
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_AudioStreamDataCompleteCallback", has_target = true, instance_pos = 0)]
    public delegate void AudioStreamDataCompleteCallback (void* buf, int buf_len);

    [CCode (cname = "SDL_AudioSpec", has_type_id = false)]
    public struct AudioSpec {
        public AudioFormat format;
        public int channels;
        public int freq;
    } // AudioSpec

    [CCode (cname = "SDL_AudioFormat", cprefix = "SDL_AUDIO_", has_type_id = false)]
    public enum AudioFormat {
        UNKNOWN,
        U8,
        S8,
        S16LE,
        S16BE,
        S32LE,
        S32BE,
        F32LE,
        F32BE,
        S16,
        S32,
        F32,
    } // AudioFormat

    [CCode (cname = "SDL_AUDIO_BITSIZE")]
    public static int audio_bit_size (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_BYTESIZE ")]
    public static int audio_byte_size (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK")]
    public const AudioDeviceID AUDIO_DEVICE_DEFAULT_PLAYBACK;

    [CCode (cname = "SDL_AUDIO_DEVICE_DEFAULT_RECORDING")]
    public const AudioDeviceID AUDIO_DEVICE_DEFAULT_RECORDING;

    [CCode (cname = "SDL_AUDIO_FRAMESIZE")]
    public static int audio_frame_size (AudioSpec x);

    [CCode (cname = "SDL_AUDIO_ISBIGENDIAN")]
    public static int audio_is_big_endian (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_ISFLOAT")]
    public static int audio_is_float (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_ISINT")]
    public static int audio_is_int (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_ISLITTLEENDIAN")]
    public static int audio_is_little_endian (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_ISSIGNED")]
    public static int audio_is_signed (AudioFormat x);

    [CCode (cname = "SDL_AUDIO_ISUNSIGNED")]
    public static int audio_is_unsigned (AudioFormat x);

    /**
     * Properties to use in get_audio_stream_properties
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAudioStreamProperties]]
     *
     * @since 3.4.0
     */
    namespace PropAudioStream {
        /**
         * if true (the default), the stream be automatically cleaned up when
         * the audio subsystem quits. If set to false, the streams will
         * persist beyond that.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAudioStreamProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_AUDIOSTREAM_AUTO_CLEANUP_BOOLEAN")]
        public const string AUTO_CLEANUP_BOOLEAN;
    }
} // SDL.Audio

///
/// GPU
///

///
/// 3D Rendering and GPU Compute (SDL_gpu.h)
///
[CCode (cheader_filename = "SDL3/SDL_gpu.h")]
namespace SDL.GPU {
    [CCode (cname = "SDL_AcquireGPUCommandBuffer")]
    public static GPUCommandBuffer ? acquire_gpu_command_buffer (GPUDevice device);

    [CCode (cname = "SDL_AcquireGPUSwapchainTexture")]
    public static bool acquire_gpu_swapchain_texture (GPUCommandBuffer command_buffer,
            Video.Window window,
            GPUTexture swapchain_texture,
            out uint32 swapchain_texture_width,
            out uint32 swapchain_texture_height);

    [CCode (cname = "SDL_BeginGPUComputePass")]
    public static GPUComputePass begin_gpu_compute_pass (GPUCommandBuffer command_buffer,
            GPUStorageTextureReadWriteBinding[] storage_texture_bindings,
            GPUStorageBufferReadWriteBinding[] storage_buffer_bindings);

    [CCode (cname = "SDL_BeginGPUCopyPass")]
    public static GPUCopyPass begin_gpu_copy_pass (GPUCommandBuffer command_buffer);

    [CCode (cname = "SDL_BeginGPURenderPass")]
    public static GPURenderPass begin_gpu_render_pass (GPUCommandBuffer command_buffer,
            GPUColorTargetInfo[] color_target_infos,
            GPUDepthStencilTargetInfo? depth_stencil_target_info);

    [CCode (cname = "SDL_BindGPUComputePipeline")]
    public static void bind_gpu_compute_pipeline (GPUComputePass compute_pass,
            GPUComputePipeline compute_pipeline);

    [CCode (cname = "SDL_BindGPUComputeSamplers")]
    public static void bind_gpu_compute_samplers (GPUComputePass compute_pass,
            uint32 first_slot,
            GPUTextureSamplerBinding[] texture_sampler_bindings);

    [CCode (cname = "SDL_BindGPUComputeStorageBuffers")]
    public static void bind_gpu_compute_storage_buffers (GPUComputePass compute_pass,
            uint32 first_slot,
            GPUBuffer[] storage_buffers);

    [CCode (cname = "SDL_BindGPUComputeStorageTextures")]
    public static void bind_gpu_compute_storage_textures (GPUComputePass compute_pass,
            uint32 first_slot,
            GPUTexture[] storage_textures);

    [CCode (cname = "SDL_BindGPUFragmentSamplers")]
    public static void bind_gpu_fragment_samplers (GPURenderPass render_pass,
            uint32 first_slot,
            GPUTextureSamplerBinding[] texture_sampler_bindings);

    [CCode (cname = "SDL_BindGPUFragmentStorageBuffers")]
    public static void bind_gpu_fragment_storage_buffers (GPURenderPass render_pass,
            uint32 first_slot,
            GPUBuffer[] storage_buffers);

    [CCode (cname = "SDL_BindGPUFragmentStorageTextures")]
    public static void bind_gpu_fragment_storage_textures (GPURenderPass render_pass,
            uint32 first_slot,
            GPUTexture[] storage_textures);

    [CCode (cname = "SDL_BindGPUGraphicsPipeline")]
    public static void bind_gpu_graphics_pipeline (GPURenderPass render_pass,
            GPUGraphicsPipeline graphics_pipeline);

    [CCode (cname = "SDL_BindGPUIndexBuffer")]
    public static void bind_gpu_index_buffer (GPURenderPass render_pass,
            GPUBufferBinding binding,
            GPUIndexElementSize index_element_size);

    [CCode (cname = "SDL_BindGPUVertexBuffers")]
    public static void bind_gpu_vertex_buffers (GPURenderPass render_pass,
            uint32 first_slot,
            GPUBufferBinding[] bindings);

    [CCode (cname = "SDL_BindGPUVertexSamplers")]
    public static void bind_gpu_vertex_samplers (GPURenderPass render_pass,
            uint32 first_slot,
            GPUTextureSamplerBinding[] texture_sampler_bindings);

    [CCode (cname = "SDL_BindGPUVertexStorageBuffers")]
    public static void bind_gpu_vertex_storage_buffers (GPURenderPass render_pass,
            uint32 first_slot,
            GPUBuffer[] storage_buffers);

    [CCode (cname = "SDL_BindGPUVertexStorageTextures")]
    public static void bind_gpu_vertex_storage_textures (GPURenderPass render_pass,
            uint32 first_slot,
            GPUTexture[] storage_textures);

    [CCode (cname = "SDL_BlitGPUTexture")]
    public static void blit_gpu_texture (GPUCommandBuffer command_buffer, GPUBlitInfo info);

    [CCode (cname = "SDL_CalculateGPUTextureFormatSize")]
    public static int32 calculate_gpu_texture_format_size (GPUTextureFormat format,
            uint32 width,
            uint32 height,
            uint32 depth_or_layer_count);

    [CCode (cname = "SDL_CancelGPUCommandBuffer")]
    public static bool cancel_gpu_command_buffer (GPUCommandBuffer command_buffer);

    [CCode (cname = "SDL_ClaimWindowForGPUDevice")]
    public static bool claim_window_for_gpu_device (GPUDevice device, Video.Window window);

    [CCode (cname = "SDL_CopyGPUBufferToBuffer")]
    public static void copy_gpu_buffer_to_buffer (GPUCopyPass copy_pass,
            GPUBufferLocation source,
            ref GPUBufferLocation destination,
            uint32 size,
            bool cycle);

    [CCode (cname = "SDL_CopyGPUTextureToTexture")]
    public static void copy_gpu_texture_to_texture (GPUCopyPass copy_pass,
            GPUTextureLocation source,
            ref GPUTextureLocation destination,
            uint32 w,
            uint32 h,
            uint32 d,
            bool cycle);

    [CCode (cname = "SDL_CreateGPUBuffer")]
    public static GPUBuffer ? create_gpu_buffer (GPUDevice device, GPUBufferCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUComputePipeline")]
    public static GPUComputePipeline ? create_compute_pipeline (GPUDevice device,
            GPUComputePipelineCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUDevice")]
    public static GPUDevice ? create_gpu_device (GPUShaderFormat format_flags, bool debug_mode,
            string? name);

    [CCode (cname = "SDL_CreateGPUDeviceWithProperties")]
    public static GPUDevice ? create_gpu_device_with_properties (SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_CreateGPUGraphicsPipeline")]
    public static GPUGraphicsPipeline ? create_gpu_graphics_pipeline (GPUDevice device,
            GPUGraphicsPipelineCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUSampler")]
    public static GPUSampler ? create_gpu_sampler (GPUDevice device,
            GPUSamplerCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUShader")]
    public static GPUShader ? create_gpu_shader (GPUDevice device,
            GPUShaderCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUTexture")]
    public static GPUTexture ? create_gpu_texture (GPUDevice device,
            GPUTextureCreateInfo create_info);

    [CCode (cname = "SDL_CreateGPUTransferBuffer")]
    public static GPUTransferBuffer ? create_gpu_transfer_buffer (GPUDevice device,
            GPUTransferBufferCreateInfo create_info);

    [CCode (cname = "SDL_DestroyGPUDevice")]
    public static void destroy_gpu_device (GPUDevice device);

    [CCode (cname = "SDL_DispatchGPUCompute")]
    public static void dispatch_gpu_compute (GPUComputePass compute_pass,
            uint32 group_count_x,
            uint32 group_count_y,
            int32 group_count_z);

    [CCode (cname = "SDL_DispatchGPUComputeIndirect")]
    public static void dispatch_gpu_compute_indirect (GPUComputePass compute_pass,
            GPUBuffer buffer,
            uint32 offset);

    [CCode (cname = "SDL_DownloadFromGPUBuffer")]
    public static void download_from_gpu_buffer (GPUCopyPass copy_pass,
            GPUBufferRegion source,
            GPUTransferBufferLocation destination);

    [CCode (cname = "SDL_DownloadFromGPUTexture")]
    public static void download_from_gpu_texture (GPUCopyPass copy_pass,
            GPUTextureRegion source,
            GPUTextureTransferInfo destination);

    [CCode (cname = "SDL_DrawGPUIndexedPrimitives")]
    public static void draw_gpu_indexed_primitives (GPURenderPass render_pass,
            uint32 num_indices,
            uint32 num_instances,
            uint32 first_index,
            int32 vertex_offset,
            uint32 first_instance);

    [CCode (cname = "SDL_DrawGPUIndexedPrimitivesIndirect")]
    public static void draw_gpu_indexed_primitives_indirect (GPURenderPass render_pass,
            GPUBuffer buffer,
            uint32 offset,
            uint32 draw_count);

    [CCode (cname = "SDL_DrawGPUPrimitives")]
    public static void draw_gpu_primitives (GPURenderPass render_pass,
            uint32 num_vertices,
            uint32 num_instances,
            uint32 first_vertex,
            uint32 first_instance);

    [CCode (cname = "SDL_DrawGPUPrimitivesIndirect")]
    public static void draw_gpu_primitives_indirect (GPURenderPass render_pass,
            GPUBuffer buffer,
            uint32 offset,
            uint32 draw_count);

    [CCode (cname = "SDL_EndGPUComputePass")]
    public static void end_gpu_compute_pass (GPUComputePass compute_pass);

    [CCode (cname = "SDL_EndGPUCopyPass")]
    public static void end_gpu_copy_pass (GPUCopyPass copy_pass);

    [CCode (cname = "SDL_EndGPURenderPass")]
    public static void end_gpu_render_pass (GPURenderPass render_pass);

    [CCode (cname = "SDL_GDKResumeGPU")]
    public static void gdk_resume_gpu (GPUDevice device);

    [CCode (cname = "SDL_GDKSuspendGPU")]
    public static void gdk_suspend_gpu (GPUDevice device);

    [CCode (cname = "SDL_GenerateMipmapsForGPUTexture")]
    public static void generate_mipmaps_for_gpu_texture (GPUCommandBuffer command_buffer,
            GPUTexture texture);

    [CCode (cname = "SDL_GetGPUDeviceDriver")]
    public static unowned string ? get_gpu_device_driver (GPUDevice device);

    /**
     * Get the properties associated with a GPU device.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
     *
     * @param device a GPU context to query.
     *
     * @return valid property ID on success or 0 on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetGPUDeviceProperties")]
    public static SDL.Properties.PropertiesID get_gpu_device_properties (GPUDevice device);

    [CCode (cname = "SDL_GetGPUDriver")]
    public static unowned string get_gpu_driver (int index);

    [CCode (cname = "SDL_GetGPUShaderFormats")]
    public static GPUShaderFormat get_gpu_shader_formats (GPUDevice device);

    [CCode (cname = "SDL_GetGPUSwapchainTextureFormat")]
    public static GPUTextureFormat get_gpu_swapchain_texture_format (GPUDevice device,
            Video.Window window);

    /**
     * Get the SDL pixel format corresponding to a GPU texture format.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUTextureFormatFromPixelFormat]]
     *
     * @param format a pixel format.
     *
     * @return the corresponding GPU texture format, or
     * {@link GPUTextureFormat.INVALID} if there is no corresponding
     * GPU texture format.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetGPUTextureFormatFromPixelFormat")]
    public static GPUTextureFormat get_gpu_texture_format_from_pixel_format (Pixels.PixelFormat format);

    /**
     * Get the number of GPU drivers compiled into SDL.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_GetNumGPUDrivers]]
     *
     * @return the number of built in GPU drivers.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetNumGPUDrivers")]
    public static int get_num_gpu_drivers ();

    /**
     * Get the SDL pixel format corresponding to a GPU texture format.
     *
     *   * [[https://wiki.libsdl.org/SDL3/SDL_GetPixelFormatFromGPUTextureFormat]]
     *
     * @param format a texture format.
     *
     * @return the corresponding pixel format, or
     * {@link Pixels.PixelFormat.UNKNOWN} if there is no corresponding
     * pixel format.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetPixelFormatFromGPUTextureFormat")]
    public static Pixels.PixelFormat get_pixel_format_from_gpu_texture_format (GPUTextureFormat format);

    [CCode (cname = "SDL_GPUSupportsProperties")]
    public static bool gpu_supports_properties (SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_GPUSupportsShaderFormats")]
    public static bool gpu_supports_shader_formats (GPUShaderFormat format_flags, string? name);

    [CCode (cname = "SDL_GPUTextureFormatTexelBlockSize")]
    public static uint32 gpu_texture_format_text_block_size (GPUTextureFormat format);

    [CCode (cname = "SDL_GPUTextureSupportsFormat")]
    public static bool gpu_texture_supports_format (GPUDevice device,
            GPUTextureFormat format,
            GPUTextureType type,
            GPUTextureUsageFlags usage);

    [CCode (cname = "SDL_GPUTextureSupportsSampleCount")]
    public static bool gpu_texture_supports_sample_count (GPUDevice device,
            GPUTextureFormat format,
            GPUSampleCount sample_count);

    [CCode (cname = "SDL_InsertGPUDebugLabel")]
    public static void insert_gpu_debug_label (GPUCommandBuffer command_buffer,
            string text);

    [CCode (cname = "SDL_MapGPUTransferBuffer")]
    public static void * map_gpu_transfer_buffer (GPUDevice device,
            GPUTransferBuffer transfer_buffer,
            bool cycle);

    [CCode (cname = "SDL_PopGPUDebugGroup")]
    public static void pop_gpu_debug_group (GPUCommandBuffer command_buffer);

    [CCode (cname = "SDL_PushGPUComputeUniformData")]
    public static void push_gpu_compute_uniform_data (GPUCommandBuffer command_buffer,
            uint32 slot_index,
            void* data,
            uint32 length);

    [CCode (cname = "SDL_PushGPUDebugGroup")]
    public static void push_gpu_debug_group (GPUCommandBuffer command_buffer, string name);

    [CCode (cname = "SDL_PushGPUFragmentUniformData")]
    public static void push_gpu_fragment_uniform_data (GPUCommandBuffer command_buffer,
            uint32 slot_index,
            void* data,
            uint32 length);

    [CCode (cname = "SDL_PushGPUVertexUniformData")]
    public static void push_gpu_vertex_uniform_data (GPUCommandBuffer command_buffer,
            uint32 slot_index,
            void* data,
            uint32 length);

    [CCode (cname = "SDL_QueryGPUFence")]
    public static bool query_gpu_fence (GPUDevice device, GPUFence fence);

    [CCode (cname = "SDL_ReleaseGPUBuffer")]
    public static void release_gpu_buffer (GPUDevice device, GPUBuffer buffer);

    [CCode (cname = "SDL_ReleaseGPUComputePipeline")]
    public static void release_gpu_computer_pipeline (GPUDevice device,
            GPUComputePipeline compute_pipeline);

    [CCode (cname = "SDL_ReleaseGPUFence")]
    public static void release_gpu_fence (GPUDevice device, GPUFence fence);

    [CCode (cname = "SDL_ReleaseGPUGraphicsPipeline")]
    public static void release_gpu_graphics_pipeline (GPUDevice device,
            GPUGraphicsPipeline graphics_pipeline);

    [CCode (cname = "SDL_ReleaseGPUSampler")]
    public static void release_gpu_sampler (GPUDevice device, GPUSampler sampler);

    [CCode (cname = "SDL_ReleaseGPUShader")]
    public static void release_gpu_shader (GPUDevice device, GPUShader shader);

    [CCode (cname = "SDL_ReleaseGPUTexture")]
    public static void release_gpu_texture (GPUDevice device, GPUTexture texture);

    [CCode (cname = "SDL_ReleaseGPUTransferBuffer")]
    public static void release_gpu_transfer_buffer (GPUDevice device,
            GPUTransferBuffer transfer_buffer);

    [CCode (cname = "SDL_ReleaseWindowFromGPUDevice")]
    public static void release_window_from_gpu_device (GPUDevice device, Video.Window window);

    [CCode (cname = "SDL_SetGPUAllowedFramesInFlight")]
    public static bool set_gpu_allowed_frame_in_flight (GPUDevice device,
            uint32 allowed_frames_in_flight);

    [CCode (cname = "SDL_SetGPUBlendConstants")]
    public static void set_gpu_blend_constants (GPURenderPass render_pass,
            Pixels.FColor blend_constants);

    [CCode (cname = "SDL_SetGPUBufferName")]
    public static void set_gpu_buffer_name (GPUDevice device, GPUBuffer buffer, string text);

    [CCode (cname = "SDL_SetGPUScissor")]
    public static void set_gpu_scissor (GPURenderPass render_pass, Rect.Rect scissor);

    [CCode (cname = "SDL_SetGPUStencilReference")]
    public static void set_gpu_stencil_reference (GPURenderPass render_pass, uint8 reference);

    [CCode (cname = "SDL_SetGPUSwapchainParameters")]
    public static bool set_gpu_swapchain_parameters (GPUDevice device,
            Video.Window window,
            GPUSwapchainComposition swapchain_composition,
            GPUPresentMode present_mode);

    [CCode (cname = "SDL_SetGPUTextureName")]
    public static void set_gpu_texture_name (GPUDevice device, GPUTexture texture, string text);

    [CCode (cname = "SDL_SetGPUViewport")]
    public static void set_gpu_viewport (GPURenderPass render_pass, GPUViewport viewport);

    [CCode (cname = "SDL_SubmitGPUCommandBuffer")]
    public static bool submit_gpu_command_buffer (GPUCommandBuffer command_buffer);

    [CCode (cname = "SDL_SubmitGPUCommandBufferAndAcquireFence")]
    public static GPUFence ? submit_gpu_command_buffer_and_acquire_fence (
            GPUCommandBuffer command_buffer);

    [CCode (cname = "SDL_UnmapGPUTransferBuffer")]
    public static void unmap_gpu_transfer_buffer (GPUDevice device,
            GPUTransferBuffer transfer_buffer);

    [CCode (cname = "SDL_UploadToGPUBuffer")]
    public static void upload_to_gpu_buffer (GPUCopyPass copy_pass,
            GPUTransferBufferLocation source,
            GPUBufferRegion destination,
            bool cycle);

    [CCode (cname = "SDL_UploadToGPUTexture")]
    public static void upload_to_gpu_texture (GPUCopyPass copy_pass,
            GPUTextureTransferInfo source,
            GPUTextureRegion destination,
            bool cycle);

    [CCode (cname = "SDL_WaitAndAcquireGPUSwapchainTexture")]
    public static bool wait_and_acquire_gpu_swapchain_texture (GPUCommandBuffer command_buffer,
            Video.Window window,
            out GPUTexture swapchain_texture,
            out uint32 swapchain_texture_width,
            out uint32 swapchain_texture_height);

    [CCode (cname = "SDL_WaitForGPUFences")]
    public static bool wait_for_gpu_fences (GPUDevice device, bool wait_all, GPUFence[] fences);

    [CCode (cname = "SDL_WaitForGPUIdle")]
    public static bool wait_for_gpu_idle (GPUDevice device);

    [CCode (cname = "SDL_WaitForGPUSwapchain")]
    public static bool wait_for_gpu_swapchain (GPUDevice device, Video.Window window);

    [CCode (cname = "SDL_WindowSupportsGPUPresentMode")]
    public static bool window_support_gpu_present_mode (GPUDevice device,
            Video.Window window,
            GPUPresentMode present_mode);

    [CCode (cname = "SDL_WindowSupportsGPUSwapchainComposition")]
    public static bool window_supports_gpu_swapchain_composition (GPUDevice device,
            Video.Window window,
            GPUSwapchainComposition swapchain_composition);

    [Compact, CCode (cname = "SDL_GPUBuffer", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUBuffer {}

    [Flags, CCode (cname = "Uint32", cprefix = "SDL_GPU_BUFFERUSAGE_", has_type_id = false)]
    public enum GPUBufferUsageFlags {
        VERTEX,
        INDEX,
        INDIRECT,
        GRAPHICS_STORAGE_READ,
        COMPUTE_STORAGE_READ,
        COMPUTE_STORAGE_WRITE,
    }

    [Flags, CCode (cname = "uint8", cprefix = "SDL_GPU_COLORCOMPONENT_", has_type_id = false)]
    public enum GPUColorComponentFlags {
        R,
        G,
        B,
        A,
    }

    [Compact, CCode (cname = "SDL_GPUCommandBuffer", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUCommandBuffer {}

    [Compact, CCode (cname = "SDL_GPUComputePass", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUComputePass {}

    [Compact, CCode (cname = "SDL_GPUComputePipeline", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUComputePipeline {}

    [Compact, CCode (cname = "SDL_GPUCopyPass", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUCopyPass {}

    [Compact, CCode (cname = "SDL_GPUDevice", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUDevice {}

    [Compact, CCode (cname = "SDL_GPUFence", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUFence {}

    [Compact, CCode (cname = "SDL_GPUGraphicsPipeline", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUGraphicsPipeline {}

    [Compact, CCode (cname = "SDL_GPURenderPass", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPURenderPass {}

    [Compact, CCode (cname = "SDL_GPUSampler", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUSampler {}

    [Compact, CCode (cname = "SDL_GPUShader", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUShader {}

    [CCode (cname = "Uint32", cprefix = "SDL_GPU_SHADERFORMAT_", has_type_id = false)]
    public enum GPUShaderFormat {
        INVALID,
        PRIVATE,
        SPIRV,
        DXBC,
        DXIL,
        MSL,
        METALLIB,
    }

    [Compact, CCode (cname = "SDL_GPUTexture", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUTexture {}

    [Flags, CCode (cname = "Uint32", cprefix = "SDL_GPU_TEXTUREUSAGE_", has_type_id = false)]
    public enum GPUTextureUsageFlags {
        SAMPLER,
        COLOR_TARGET,
        DEPTH_STENCIL_TARGET,
        GRAPHICS_STORAGE_READ,
        COMPUTE_STORAGE_READ,
        COMPUTE_STORAGE_WRITE,
        COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE,
    }

    [Compact, CCode (cname = "SDL_GPUTransferBuffer", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class GPUTransferBuffer {}

    [CCode (cname = "SDL_GPUBlitInfo", has_type_id = false)]
    public struct GPUBlitInfo {
        public GPUBlitRegion source;
        public GPUBlitRegion destination;
        public GPULoadOp load_op;
        public Pixels.FColor clear_color;
        public Surface.FlipMode flip_mode;
        public GPUFilter filter;
        public bool cycle;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // GPUBlitInfo

    [CCode (cname = "SDL_GPUBlitRegion", has_type_id = false)]
    public struct GPUBlitRegion {
        public GPUTexture texture;
        public uint32 mip_level;
        public uint32 layer_or_depth_plane;
        public uint32 x;
        public uint32 y;
        public uint32 w;
        public uint32 h;
    } // GPUBlitRegion

    [CCode (cname = "SDL_GPUBufferBinding", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUBufferBinding {
        public GPUBuffer buffer;
        public uint32 offset;
    } // GPUBufferBinding

    [CCode (cname = "SDL_GPUBufferCreateInfo", has_type_id = false)]
    public struct GPUBufferCreateInfo {
        public GPUBufferUsageFlags usage;
        public uint32 size;
        public SDL.Properties.PropertiesID props;
    } // GPUBufferCreateInfo

    [CCode (cname = "SDL_GPUBufferLocation", has_type_id = false)]
    public struct GPUBufferLocation {
        GPUBuffer buffer;
        public uint32 offset;
    } // GPUBufferLocation

    [CCode (cname = "SDL_GPUBufferRegion", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUBufferRegion {
        public GPUBuffer buffer;
        public uint32 offset;
        public uint32 size;
    } // GPUBufferRegion

    [CCode (cname = "SDL_GPUColorTargetBlendState", has_type_id = false)]
    public struct GPUColorTargetBlendState {
        public GPUBlendFactor src_color_blendfactor;
        public GPUBlendFactor dst_color_blendfactor;
        public GPUBlendOp color_blend_op;
        public GPUBlendFactor src_alpha_blendfactor;
        public GPUBlendFactor dst_alpha_blendfactor;
        public GPUBlendOp alpha_blend_op;
        public GPUColorComponentFlags color_write_mask;
        public bool enable_blend;
        public bool enable_color_write_mask;
        public uint8 padding1;
        public uint8 padding2;
    } // GPUColorTargetBlendState

    [CCode (cname = "SDL_GPUColorTargetDescription", has_destroy_function = false,
    has_type_id = false)]
    public struct GPUColorTargetDescription {
        public GPUTextureFormat format;
        public GPUColorTargetBlendState blend_state;
    } // GPUColorTargetDescription

    [CCode (cname = "SDL_GPUColorTargetInfo", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUColorTargetInfo {
        public GPUTexture texture;
        public uint32 mip_level;
        public uint32 layer_or_depth_plane;
        public Pixels.FColor clear_color;
        public GPULoadOp load_op;
        public GPUStoreOp store_op;
        public GPUTexture? resolve_texture;
        public uint32 resolve_mip_level;
        public uint32 resolve_layer;
        public bool cycle;
        public bool cycle_resolve_texture;
        public uint8 padding1;
        public uint8 padding2;
    } // GPUColorTargetInfo

    [CCode (cname = "SDL_GPUComputePipelineCreateInfo", has_type_id = false)]
    public struct GPUComputePipelineCreateInfo {
        public size_t code_size;
        public uint8[] code;
        public string entrypoint;
        public GPUShaderFormat format;
        public uint32 num_samplers;
        public uint32 num_readonly_storage_textures;
        public uint32 num_readonly_storage_buffers;
        public uint32 num_readwrite_storage_textures;
        public uint32 num_readwrite_storage_buffers;
        public uint32 num_uniform_buffers;
        public uint32 threadcount_x;
        public uint32 threadcount_y;
        public uint32 threadcount_z;
        public SDL.Properties.PropertiesID props;
    } // GPUComputePipelineCreateInfo

    [CCode (cname = "SDL_GPUDepthStencilState", has_type_id = false)]
    public struct GPUDepthStencilState {
        public GPUCompareOp compare_op;
        public GPUStencilOpState back_stencil_state;
        public GPUStencilOpState front_stencil_state;
        public uint8 compare_mask;
        public uint8 write_mask;
        public bool enable_depth_test;
        public bool enable_depth_write;
        public bool enable_stencil_test;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // GPUDepthStencilState

    /**
     * A structure specifying the parameters of a depth-stencil target used by a render pass.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPUDepthStencilTargetInfo]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GPUDepthStencilTargetInfo", has_type_id = false)]
    public struct GPUDepthStencilTargetInfo {
    /**
     * The texture that will be used as the depth stencil target by the
     * render pass.
     *
     */
        public GPUTexture texture;

    /**
     * The value to clear the depth component to at the beginning of the
     * render pass. Ignored if {@link GPULoadOp.CLEAR} is not used.
     *
     */
        public float clear_depth;

    /**
     * What is done with the depth contents at the beginning of the
     * render pass.
     *
     */
        public GPULoadOp load_op;

    /**
     * What is done with the depth results of the render pass.
     *
     */
        public GPUStoreOp store_op;

    /**
     * What is done with the stencil contents at the beginning of the
     * render pass.
     *
     */
        public GPULoadOp stencil_load_op;

    /**
     * What is done with the stencil results of the render pass.
     *
     */
        public GPUStoreOp stencil_store_op;

    /**
     * If true, cycles the texture if the texture is bound and any load
     * ops are not LOAD
     *
     */
        public bool cycle;

    /**
     * The value to clear the stencil component to at the beginning of
     * the render pass. Ignored if {@link GPULoadOp.CLEAR} is not used.
     *
     */
        public uint8 clear_stencil;

    /**
     * The mip level to use as the depth stencil target.
     *
     */
        [Version (since = "3.4.0")]
        public uint8 mip_level;

    /**
     * The layer index to use as the depth stencil target.
     *
     */
        [Version (since = "3.4.0")]
        public uint8 layer;
    } // GPUDepthStencilTargetInfo;

    [CCode (cname = "SDL_GPUGraphicsPipelineCreateInfo", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUGraphicsPipelineCreateInfo {
        public GPUShader vertex_shader;
        public GPUShader fragment_shader;
        public GPUVertexInputState vertex_input_state;
        public GPUPrimitiveType primitive_type;
        public GPURasterizerState rasterizer_state;
        public GPUMultisampleState multisample_state;
        public GPUDepthStencilState depth_stencil_state;
        public GPUGraphicsPipelineTargetInfo target_info;
        public SDL.Properties.PropertiesID props;
    } // GPUGraphicsPipelineCreateInfo

    [CCode (cname = "SDL_GPUGraphicsPipelineTargetInfo", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUGraphicsPipelineTargetInfo {
        [CCode (array_length_cname = "num_color_targets", array_length_type = "Uint32")]
        public GPUColorTargetDescription[] color_target_descriptions;
        public GPUTextureFormat depth_stencil_format;
        public bool has_depth_stencil_target;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // GPUGraphicsPipelineTargetInfo

    [CCode (cname = "SDL_GPUIndexedIndirectDrawCommand", has_type_id = false)]
    public struct GPUIndexedIndirectDrawCommand {
        public uint32 num_indices;
        public uint32 num_instances;
        public uint32 first_index;
        public int32 vertex_offset;
        public uint32 first_instance;
    } // GPUIndexedIndirectDrawCommand

    [CCode (cname = "SDL_GPUIndirectDispatchCommand", has_type_id = false)]
    public struct GPUIndirectDispatchCommand {
        public uint32 groupcount_x;
        public uint32 groupcount_y;
        public uint32 groupcount_z;
    } // GPUIndirectDispatchCommand

    [CCode (cname = "SDL_GPUIndirectDrawCommand", has_type_id = false)]
    public struct GPUIndirectDrawCommand {
        public uint32 num_vertices;
        public uint32 num_instances;
        public uint32 first_vertex;
        public uint32 first_instance;
    } // GPUIndirectDrawCommand

    /**
     * A structure specifying the parameters of the graphics pipeline multisample state.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPUMultisampleState]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GPUMultisampleState", has_type_id = false)]
    public struct GPUMultisampleState {
    /**
     * The number of samples to be used in rasterization.
     *
     */
        public GPUSampleCount sample_count;

    /**
     * Reserved for future use. Must be set to 0.
     *
     */
        public uint32 sample_mask;

    /**
     * Reserved for future use. Must be set to false.
     *
     */
        public bool enable_mask;

    /**
     * True enables the alpha-to-coverage feature.
     *
     */
        [Version (since = "3.4.0")]
        public bool enable_alpha_to_coverage;

    /**
     * Padding variable
     *
     */
        public uint8 padding2;

    /**
     * Padding variable
     *
     */
        public uint8 padding3;
    } // GPUMultisampleState

    [CCode (cname = "SDL_GPURasterizerState", has_type_id = false)]
    public struct GPURasterizerState {
        public GPUFillMode fill_mode;
        public GPUCullMode cull_mode;
        public GPUFrontFace front_face;
        public float depth_bias_constant_factor;
        public float depth_bias_clamp;
        public float depth_bias_slope_factor;
        public bool enable_depth_bias;
        public bool enable_depth_clip;
        public uint8 padding1;
        public uint8 padding2;
    } // GPURasterizerState

    [CCode (cname = "SDL_GPUSamplerCreateInfo", has_type_id = false)]
    public struct GPUSamplerCreateInfo {
        public GPUFilter min_filter;
        public GPUFilter mag_filter;
        public GPUSamplerMipmapMode mipmap_mode;
        public GPUSamplerAddressMode address_mode_u;
        public GPUSamplerAddressMode address_mode_v;
        public GPUSamplerAddressMode address_mode_w;
        public float mip_lod_bias;
        public float max_anisotropy;
        public GPUCompareOp compare_op;
        public float min_lod;
        public float max_lod;
        public bool enable_anisotropy;
        public bool enable_compare;
        public uint8 padding1;
        public uint8 padding2;
        public SDL.Properties.PropertiesID props;
    } // GPUSamplerCreateInfo

    [CCode (cname = "SDL_GPUShaderCreateInfo", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUShaderCreateInfo {
        public uint8* code;
        public size_t code_size;
        [CCode (array_null_terminated = true)]
        public string entrypoint;
        public GPUShaderFormat format;
        public GPUShaderStage stage;
        public uint32 num_samplers;
        public uint32 num_storage_textures;
        public uint32 num_storage_buffers;
        public uint32 num_uniform_buffers;
        public SDL.Properties.PropertiesID props;
    } // GPUShaderCreateInfo

    [CCode (cname = "SDL_GPUStencilOpState", has_type_id = false)]
    public struct GPUStencilOpState {
        public GPUStencilOp fail_op;
        public GPUStencilOp pass_op;
        public GPUStencilOp depth_fail_op;
        public GPUCompareOp compare_op;
    } // GPUStencilOpState

    [CCode (cname = "SDL_GPUStorageBufferReadWriteBinding", has_type_id = false)]
    public struct GPUStorageBufferReadWriteBinding {
        public GPUBuffer buffer;
        public bool cycle;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // GPUStorageBufferReadWriteBinding

    [CCode (cname = "SDL_GPUStorageTextureReadWriteBinding", has_type_id = false)]
    public struct GPUStorageTextureReadWriteBinding {
        public GPUTexture texture;
        public uint32 mip_level;
        public uint32 layer;
        public bool cycle;
        public uint8 padding1;
        public uint8 padding2;
        public uint8 padding3;
    } // GPUStorageTextureReadWriteBinding

    [CCode (cname = "SDL_GPUTextureCreateInfo", has_type_id = false)]
    public struct GPUTextureCreateInfo {
        public GPUTextureType type;
        public GPUTextureFormat format;
        public GPUTextureUsageFlags usage;
        public uint32 width;
        public uint32 height;
        public uint32 layer_count_or_depth;
        public uint32 num_levels;
        public GPUSampleCount sample_count;
        public SDL.Properties.PropertiesID props;
    } // GPUTextureCreateInfo

    [CCode (cname = "SDL_GPUTextureLocation", has_type_id = false)]
    public struct GPUTextureLocation {
        public GPUTexture texture;
        public uint32 mip_level;
        public uint32 layer;
        public uint32 x;
        public uint32 y;
        public uint32 z;
    } // GPUTextureLocation

    [CCode (cname = "SDL_GPUTextureRegion", has_type_id = false)]
    public struct GPUTextureRegion {
        public GPUTexture texture;
        public uint32 mip_level;
        public uint32 layer;
        public uint32 x;
        public uint32 y;
        public uint32 z;
        public uint32 w;
        public uint32 h;
        public uint32 d;
    } // GPUTextureRegion

    [CCode (cname = "SDL_GPUTextureSamplerBinding", destroy_function = "",
    has_copy_function = false, has_type_id = false)]
    public struct GPUTextureSamplerBinding {
        public GPUTexture texture;
        public GPUSampler sampler;
    } // GPUTextureSamplerBinding

    [CCode (cname = "SDL_GPUTextureTransferInfo", has_type_id = false)]
    public struct GPUTextureTransferInfo {
        public GPUTransferBuffer transfer_buffer;
        public uint32 offset;
        public uint32 pixels_per_row;
        public uint32 rows_per_layer;
    } // GPUTextureTransferInfo

    [CCode (cname = "SDL_GPUTransferBufferCreateInfo", has_type_id = false)]
    public struct GPUTransferBufferCreateInfo {
        public GPUTransferBufferUsage usage;
        public uint32 size;
        SDL.Properties.PropertiesID props;
    } // GPUTransferBufferCreateInfo

    [CCode (cname = "SDL_GPUTransferBufferLocation", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUTransferBufferLocation {
        public GPUTransferBuffer transfer_buffer;
        public uint32 offset;
    } // GPUTransferBufferLocation

    [CCode (cname = "SDL_GPUVertexAttribute", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUVertexAttribute {
        public uint32 location;
        public uint32 buffer_slot;
        public GPUVertexElementFormat format;
        public uint32 offset;
    } // GPUVertexAttribute

    [CCode (cname = "SDL_GPUVertexBufferDescription", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUVertexBufferDescription {
        public uint32 slot;
        public uint32 pitch;
        public GPUVertexInputRate input_rate;
        public uint32 instance_step_rate;
    } // GPUVertexBufferDescription

    [CCode (cname = "SDL_GPUVertexInputState", has_destroy_function = false,
    has_copy_function = false, has_type_id = false)]
    public struct GPUVertexInputState {
        [CCode (array_length_cname = "num_vertex_buffers", array_length_type = "Uint32")]
        public GPUVertexBufferDescription[] vertex_buffer_descriptions;
        [CCode (array_length_cname = "num_vertex_attributes", array_length_type = "Uint32")]
        public GPUVertexAttribute[] vertex_attributes;
    } // GPUVertexInputState

    [CCode (cname = "SDL_GPUViewport", has_type_id = false)]
    public struct GPUViewport {
        public float x;
        public float y;
        public float w;
        public float h;
        public float min_depth;
        public float max_depth;
    } // GPUViewport


    /**
     * A structure specifying additional options when using Vulkan.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GPUVulkanOptions]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GPUVulkanOptions", has_type_id = false)]
    public struct GPUVulkanOptions {
    /**
     *The Vulkan API version to request for the instance. Use Vulkan's
     * VK_MAKE_VERSION or VK_MAKE_API_VERSION.
     *
     */
        public uint32 vulkan_api_version;

    /**
     * Pointer to the first element of a chain of Vulkan feature structs.
     * (Requires API version 1.1 or higher.)
     *
     */
        public void* feature_list;

    /**
     * Pointer to a VkPhysicalDeviceFeatures struct to enable additional
     * Vulkan 1.0 features.
     *
     */
        public void* vulkan_10_physical_device_features;

    /**
     * A list of additional device extensions to require.
     *
     */
        [CCode (array_length_cname = "device_extension_count", array_length_type = "Uint32")]
        public string[] device_extension_names;

    /**
     * A list of additional instance extensions to require.
     *
     */
        [CCode (array_length_cname = "instance_extension_count", array_length_type = "Uint32")]
        public string[] instance_extension_names;
    } // GPUVulkanOptions

    [CCode (cname = "SDL_GPUBlendFactor", cprefix = "SDL_GPU_BLENDFACTOR_", has_type_id = false)]
    public enum GPUBlendFactor {
        INVALID,
        ZERO,
        ONE,
        SRC_COLOR,
        ONE_MINUS_SRC_COLOR,
        DST_COLOR,
        ONE_MINUS_DST_COLOR,
        SRC_ALPHA,
        ONE_MINUS_SRC_ALPHA,
        DST_ALPHA,
        ONE_MINUS_DST_ALPHA,
        CONSTANT_COLOR,
        ONE_MINUS_CONSTANT_COLOR,
        SRC_ALPHA_SATURATE,
    } // GPUBlendFactor

    [CCode (cname = "SDL_GPUBlendOp", cprefix = "SDL_GPU_BLENDOP_", has_type_id = false)]
    public enum GPUBlendOp {
        INVALID,
        ADD,
        SUBTRACT,
        REVERSE_SUBTRACT,
        MIN,
        MAX,
    } // GPUBlendOp

    [CCode (cname = "SDL_GPUCompareOp", cprefix = "SDL_GPU_COMPAREOP_", has_type_id = false)]
    public enum GPUCompareOp {
        INVALID,
        NEVER,
        LESS,
        EQUAL,
        LESS_OR_EQUAL,
        GREATER,
        NOT_EQUAL,
        GREATER_OR_EQUAL,
        ALWAYS,
    } // GPUCompareOp

    [CCode (cname = "SDL_GPUCubeMapFace", cprefix = "SDL_GPU_CUBEMAPFACE_", has_type_id = false)]
    public enum GPUCubeMapFace {
        POSITIVEX,
        NEGATIVEX,
        POSITIVEY,
        NEGATIVEY,
        POSITIVEZ,
        NEGATIVEZ,
    } // GPUCubeMapFace

    [CCode (cname = "SDL_GPUCullMode", cprefix = "SDL_GPU_CULLMODE_", has_type_id = false)]
    public enum GPUCullMode {
        NONE,
        FRONT,
        BACK,
    } // GPUCullMode

    [CCode (cname = "SDL_GPUFillMode", cprefix = "SDL_GPU_FILLMODE_", has_type_id = false)]
    public enum GPUFillMode {
        FILL,
        LINE,
    } // GPUFillMode

    [CCode (cname = "SDL_GPUFilter", cprefix = "SDL_GPU_FILTER_", has_type_id = false)]
    public enum GPUFilter {
        NEAREST,
        LINEAR,
    } // GPUFilter

    [CCode (cname = "SDL_GPUFrontFace", cprefix = "SDL_GSDL_GPU_FRONTFACE_PU_FILTER_",
    has_type_id = false)]
    public enum GPUFrontFace {
        COUNTER_CLOCKWISE,
        CLOCKWISE,
    } // GPUFrontFace

    [CCode (cname = "SDL_GPUIndexElementSize", has_type_id = false)]
    public enum GPUIndexElementSize {
        [CCode (cname = "SDL_GPU_INDEXELEMENTSIZE_16BIT")]
        SIZE_16BIT,
        [CCode (cname = "SDL_GPU_INDEXELEMENTSIZE_32BIT")]
        SIZE_32BIT,
    } // GPUIndexElementSize

    [CCode (cname = "SDL_GPULoadOp", cprefix = "SDL_GPU_LOADOP_", has_type_id = false)]
    public enum GPULoadOp {
        LOAD,
        CLEAR,
        DONT_CARE,
    } // GPULoadOp

    [CCode (cname = "SDL_GPUPresentMode", cprefix = "SDL_GPU_PRESENTMODE_", has_type_id = false)]
    public enum GPUPresentMode {
        VSYNC,
        IMMEDIATE,
        MAILBOX,
    } // GPUPresentMode

    [CCode (cname = "SDL_GPUPrimitiveType", cprefix = "SDL_GPU_PRIMITIVETYPE_",
    has_type_id = false)]
    public enum GPUPrimitiveType {
        TRIANGLELIST,
        TRIANGLESTRIP,
        LINELIST,
        LINESTRIP,
        POINTLIST,
    } // GPUPrimitiveType

    [CCode (cname = "SDL_GPUSampleCount", has_type_id = false)]
    public enum GPUSampleCount {
        [CCode (cname = "SDL_GPU_SAMPLECOUNT_1")]
        ONE,
        [CCode (cname = "SDL_GPU_SAMPLECOUNT_2")]
        TWO,
        [CCode (cname = "SDL_GPU_SAMPLECOUNT_4")]
        FOUR,
        [CCode (cname = "SDL_GPU_SAMPLECOUNT_8")]
        EIGHT,
    } // GPUSampleCount

    [CCode (cname = "SDL_GPUSamplerAddressMode", cprefix = "SDL_GPU_SAMPLERADDRESSMODE_",
    has_type_id = false)]
    public enum GPUSamplerAddressMode {
        REPEAT,
        MIRRORED_REPEAT,
        CLAMP_TO_EDGE,
    } // GPUSamplerAddressMode

    [CCode (cname = "SDL_GPUSamplerMipmapMode", cprefix = "SDL_GPU_SAMPLERMIPMAPMODE_",
    has_type_id = false)]
    public enum GPUSamplerMipmapMode {
        NEAREST,
        LINEAR,
    } // GPUSamplerMipmapMode

    [CCode (cname = "SDL_GPUShaderStage", cprefix = "SDL_GPU_SHADERSTAGE_", has_type_id = false)]
    public enum GPUShaderStage {
        VERTEX,
        FRAGMENT,
    } // GPUShaderStage

    [CCode (cname = "SDL_GPUStencilOp", cprefix = "SDL_GPU_STENCILOP_", has_type_id = false)]
    public enum GPUStencilOp {
        INVALID,
        KEEP,
        ZERO,
        REPLACE,
        INCREMENT_AND_CLAMP,
        DECREMENT_AND_CLAMP,
        INVERT,
        INCREMENT_AND_WRAP,
        DECREMENT_AND_WRAP,
    } // GPUStencilOp

    [CCode (cname = "SDL_GPUStoreOp", cprefix = "SDL_GPU_STOREOP_", has_type_id = false)]
    public enum GPUStoreOp {
        STORE,
        DONT_CARE,
        RESOLVE,
        RESOLVE_AND_STORE,
    } // GPUStoreOp

    [CCode (cname = "SDL_GPUSwapchainComposition", cprefix = "SDL_GPU_SWAPCHAINCOMPOSITION_",
    has_type_id = false)]
    public enum GPUSwapchainComposition {
        SDR,
        SDR_LINEAR,
        HDR_EXTENDED_LINEAR,
        HDR10_ST2084,
    } // GPUSwapchainComposition

    [CCode (cname = "SDL_GPUTextureFormat", cprefix = "SDL_GPU_TEXTUREFORMAT_", has_type_id = false)]
    public enum GPUTextureFormat {
        INVALID,
        A8_UNORM,
        R8_UNORM,
        R8G8_UNORM,
        R8G8B8A8_UNORM,
        R16_UNORM,
        R16G16_UNORM,
        R16G16B16A16_UNORM,
        R10G10B10A2_UNORM,
        B5G6R5_UNORM,
        B5G5R5A1_UNORM,
        B4G4R4A4_UNORM,
        B8G8R8A8_UNORM,
        BC1_RGBA_UNORM,
        BC2_RGBA_UNORM,
        BC3_RGBA_UNORM,
        BC4_R_UNORM,
        BC5_RG_UNORM,
        BC7_RGBA_UNORM,
        BC6H_RGB_FLOAT,
        BC6H_RGB_UFLOAT,
        R8_SNORM,
        R8G8_SNORM,
        R8G8B8A8_SNORM,
        R16_SNORM,
        R16G16_SNORM,
        R16G16B16A16_SNORM,
        R16_FLOAT,
        R16G16_FLOAT,
        R16G16B16A16_FLOAT,
        R32_FLOAT,
        R32G32_FLOAT,
        R32G32B32A32_FLOAT,
        R11G11B10_UFLOAT,
        R8_UINT,
        R8G8_UINT,
        R8G8B8A8_UINT,
        R16_UINT,
        R16G16_UINT,
        R16G16B16A16_UINT,
        R32_UINT,
        R32G32_UINT,
        R32G32B32A32_UINT,
        R8_INT,
        R8G8_INT,
        R8G8B8A8_INT,
        R16_INT,
        R16G16_INT,
        R16G16B16A16_INT,
        R32_INT,
        R32G32_INT,
        R32G32B32A32_INT,
        R8G8B8A8_UNORM_SRGB,
        B8G8R8A8_UNORM_SRGB,
        BC1_RGBA_UNORM_SRGB,
        BC2_RGBA_UNORM_SRGB,
        BC3_RGBA_UNORM_SRGB,
        BC7_RGBA_UNORM_SRGB,
        D16_UNORM,
        D24_UNORM,
        D32_FLOAT,
        D24_UNORM_S8_UINT,
        D32_FLOAT_S8_UINT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM")]
        ASTC_4X4_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM")]
        ASTC_5X4_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM")]
        ASTC_5X5_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM")]
        ASTC_6X5_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM")]
        ASTC_6X6_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM")]
        ASTC_8X5_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM")]
        ASTC_8X6_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM")]
        ASTC_8X8_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM")]
        ASTC_10X5_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM")]
        ASTC_10X6_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM")]
        ASTC_10X8_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM")]
        ASTC_10X10_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM")]
        ASTC_12X10_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM")]
        ASTC_12X12_UNORM,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM_SRGB")]
        ASTC_4X4_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM_SRGB")]
        ASTC_5X4_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM_SRGB")]
        ASTC_5X5_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM_SRGB")]
        ASTC_6X5_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM_SRGB")]
        ASTC_6X6_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM_SRGB")]
        ASTC_8X5_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM_SRGB")]
        ASTC_8X6_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM_SRGB")]
        ASTC_8X8_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM_SRGB")]
        ASTC_10X5_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM_SRGB")]
        ASTC_10X6_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM_SRGB")]
        ASTC_10X8_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM_SRGB")]
        ASTC_10X10_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM_SRGB")]
        ASTC_12X10_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM_SRGB")]
        ASTC_12X12_UNORM_SRGB,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_4x4_FLOAT")]
        ASTC_4X4_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x4_FLOAT")]
        ASTC_5X4_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_5x5_FLOAT")]
        ASTC_5X5_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x5_FLOAT")]
        ASTC_6X5_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_6x6_FLOAT")]
        ASTC_6X6_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x5_FLOAT")]
        ASTC_8X5_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x6_FLOAT")]
        ASTC_8X6_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_8x8_FLOAT")]
        ASTC_8X8_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x5_FLOAT")]
        ASTC_10X5_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x6_FLOAT")]
        ASTC_10X6_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x8_FLOAT")]
        ASTC_10X8_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_10x10_FLOAT")]
        ASTC_10X10_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x10_FLOAT")]
        ASTC_12X10_FLOAT,
        [CCode (cname = "SDL_GPU_TEXTUREFORMAT_ASTC_12x12_FLOAT")]
        ASTC_12X12_FLOAT,
    } // GPUTextureFormat

    [CCode (cname = "SDL_GPUTextureType", cprefix = "SDL_GPU_", has_type_id = false)]
    public enum GPUTextureType {
        TEXTURETYPE_2D,
        TEXTURETYPE_2D_ARRAY,
        TEXTURETYPE_3D,
        TEXTURETYPE_CUBE,
        TEXTURETYPE_CUBE_ARRAY,
    } // GPUTextureType

    [CCode (cname = "SDL_GPUTransferBufferUsage", cprefix = "SDL_GPU_TRANSFERBUFFERUSAGE_",
    has_type_id = false)]
    public enum GPUTransferBufferUsage {
        UPLOAD,
        DOWNLOAD,
    } // GPUTransferBufferUsage

    [CCode (cname = "SDL_GPUVertexElementFormat", cprefix = "SDL_GPU_VERTEXELEMENTFORMAT_",
    has_type_id = false)]
    public enum GPUVertexElementFormat {
        INVALID,
        INT,
        INT2,
        INT3,
        INT4,
        UINT,
        UINT2,
        UINT3,
        UINT4,
        FLOAT,
        FLOAT2,
        FLOAT3,
        FLOAT4,
        BYTE2,
        BYTE4,
        UBYTE2,
        UBYTE4,
        BYTE2_NORM,
        BYTE4_NORM,
        UBYTE2_NORM,
        UBYTE4_NORM,
        SHORT2,
        SHORT4,
        USHORT2,
        USHORT4,
        SHORT2_NORM,
        SHORT4_NORM,
        USHORT2_NORM,
        USHORT4_NORM,
        HALF2,
        HALF4,
    } // GPUVertexElementFormat

    [CCode (cname = "SDL_GPUVertexInputRate", cprefix = "SDL_GPU_VERTEXINPUTRATE_", has_type_id = false)]
    public enum GPUVertexInputRate {
        VERTEX,
        INSTANCE,
    } // GPUVertexInputRate

    namespace PropGPUBufferCreate {
        [CCode (cname = "SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUBufferCreate

    namespace PropGPUComputePipelineCreate {
        [CCode (cname = "SDL_PROP_GPU_COMPUTEPIPELINE_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUComputePipelineCreate

    namespace PropGPUDeviceCreate {
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN")]
        public const string DEBUGMODE_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_PREFERLOWPOWER_BOOLEAN")]
        public const string PREFERLOWPOWER_BOOLEAN;

        /**
         * Enable to automatically log useful debug information on device
         * creation, defaults to true.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_VERBOSE_BOOLEAN")]
        public const string VERBOSE_BOOLEAN;

        /**
         * Enable Vulkan device feature shaderClipDistance.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_FEATURE_CLIP_DISTANCE_BOOLEAN")]
        public const string FEATURE_CLIP_DISTANCE_BOOLEAN;

        /**
         * Enable Vulkan device feature depthClamp.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_FEATURE_DEPTH_CLAMPING_BOOLEAN")]
        public const string FEATURE_DEPTH_CLAMPING_BOOLEAN;

        /**
         * Enable Vulkan device feature drawIndirectFirstInstance
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_FEATURE_INDIRECT_DRAW_FIRST_INSTANCE_BOOLEAN")]
        public const string FEATURE_INDIRECT_DRAW_FIRST_INSTANCE_BOOLEAN;

        /**
         * Enable Vulkan device feature samplerAnisotropy.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_FEATURE_ANISOTROPY_BOOLEAN")]
        public const string FEATURE_ANISOTROPY_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING")]
        public const string NAME_STRING;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_PRIVATE_BOOLEAN")]
        public const string SHADERS_PRIVATE_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_SPIRV_BOOLEAN")]
        public const string SHADERS_SPIRV_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXBC_BOOLEAN")]
        public const string SHADERS_DXBC_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN")]
        public const string SHADERS_DXIL_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_MSL_BOOLEAN")]
        public const string SHADERS_MSL_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_SHADERS_METALLIB_BOOLEAN")]
        public const string SHADERS_METALLIB_BOOLEAN;

        /// D3D12

        /**
         * By default, Resourcing Binding Tier 2 is required for D3D12 support.
         * However, an application can set this property to true to enable
         * Tier 1 support, if (and only if) the application uses 8 or fewer
         * storage resources across all shader stages.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_D3D12_ALLOW_FEWER_RESOURCE_SLOTS_BOOLEAN")]
        public const string D3D12_ALLOW_FEWER_RESOURCE_SLOTS_BOOLEAN;

        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_D3D12_SEMANTIC_NAME_STRING")]
        public const string D3D12_SEMANTIC_NAME_STRING;

        /**
         * Certain feature checks are only possible on Windows 11 by default.
         * By setting this alongside {@link D3D12_AGILITY_SDK_PATH_STRING}
         * and vendoring D3D12Core.dll from the D3D12 Agility SDK, you can make
         * those feature checks possible on older platforms. The version you
         * provide must match the one given in the DLL.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.2
         */
        [Version (since = "3.4.2")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_D3D12_AGILITY_SDK_VERSION_NUMBER")]
        public const string D3D12_AGILITY_SDK_VERSION_NUMBER;

        /**
         * Certain feature checks are only possible on Windows 11 by default.
         * By setting this alongside {@link D3D12_AGILITY_SDK_VERSION_NUMBER}
         * and vendoring D3D12Core.dll from the D3D12 Agility SDK, you can make
         * those feature checks possible on older platforms. The version you
         * provide must match the one given in the DLL.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.2
         */
        [Version (since = "3.4.2")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_D3D12_AGILITY_SDK_PATH_STRING")]
        public const string D3D12_AGILITY_SDK_PATH_STRING;

        /// Vulkan

        /**
         * By default, V*ulkan device enumeration includes drivers of all
         * types, including software renderers (for example, the Lavapipe
         * Mesa driver)
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_VULKAN_REQUIRE_HARDWARE_ACCELERATION_BOOLEAN")]
        public const string VULKAN_REQUIRE_HARDWARE_ACCELERATION_BOOLEAN;

        /**
         * A pointer to an {@link GPU.GPUVulkanOptions} structure to be
         * processed during device creation.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_VULKAN_OPTIONS_POINTER")]
        public const string VULKAN_OPTIONS_POINTER;

        /// Metal

        /**
         * By default, macOS support requires what Apple calls
         * "MTLGPUFamilyMac2" hardware or newer. However, an application can
         * set this property to true to enable support for "MTLGPUFamilyMac1"
         * hardware, if (and only if) the application does not write to sRGB
         * textures. (For history's sake: MacFamily1 also does not support
         * indirect command buffers, MSAA depth resolve, and stencil
         * resolve/feedback, but these are not exposed features in
         * {@link SDL.GPU}.)
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateGPUDeviceWithProperties]]
         *
         * @since 3.4.2
         */
        [Version (since = "3.4.2")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_CREATE_METAL_ALLOW_MACFAMILY1_BOOLEAN")]
        public const string METAL_ALLOW_MACFAMILY1_BOOLEAN;

    } // PropGPUDeviceCreate

    /**
     * Properties used in {@link get_gpu_device_properties}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    namespace PropGPUDevice {
        /**
         * Contains the name of the underlying device as reported by the
         * system driver.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_NAME_STRING")]
        public const string DEVICE_NAME_STRING;

        /**
         * Contains the self-reported name of the underlying system
         * driver.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_DRIVER_NAME_STRING")]
        public const string DRIVER_NAME_STRING;

        /**
         * Contains the self-reported version of the underlying system driver.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_DRIVER_VERSION_STRING")]
        public const string DRIVER_VERSION_STRING;

        /**
         * Contains the detailed version information of the underlying
         * system driver as reported by the driver.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGPUDeviceProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_GPU_DEVICE_DRIVER_INFO_STRING")]
        public const string DRIVER_INFO_STRING;
    }

    namespace PropGPUGraphicsPipelineCreate {
        [CCode (cname = "SDL_PROP_GPU_GRAPHICSPIPELINE_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUGraphicsPipelineCreate

    namespace PropGPUSamplerCreate {
        [CCode (cname = "SDL_PROP_GPU_SAMPLER_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUSamplerCreate

    namespace PropGPUShaderCreate {
        [CCode (cname = "SDL_PROP_GPU_SHADER_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUShaderCreate

    namespace PropGPUTextureCreate {
        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_R_FLOAT")]
        public const string D3D12_CLEAR_R_FLOAT;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_G_FLOAT")]
        public const string D3D12_CLEAR_G_FLOAT;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_B_FLOAT")]
        public const string D3D12_CLEAR_B_FLOAT;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_A_FLOAT")]
        public const string D3D12_CLEAR_A_FLOAT;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_DEPTH_FLOAT")]
        public const string D3D12_CLEAR_DEPTH_FLOAT;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_STENCIL_NUMBER")]
        public const string D3D12_CLEAR_STENCIL_NUMBER;

        [CCode (cname = "SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUTextureCreate

    namespace PropGPUTransferBufferCreate {
        [CCode (cname = "SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING")]
        public const string NAME_STRING;
    } // PropGPUTransferBufferCreate
} // SDL.GPU

///
/// Threads
///

///
/// Thread Management (SDL_thread.h)
///
[CCode (cheader_filename = "SDL3/SDL_thread.h")]
namespace SDL.Threads {
    [CCode (cname = "SDL_CleanupTLS")]
    public static void cleanup_tls ();

    [CCode (cname = "SDL_CreateThread", has_target = true)]
    public static Thread ? create_thread (ThreadFunction fn, string name);

    [CCode (cname = "SDL_CreateThreadWithProperties")]
    public static Thread ? create_thread_with_properties (SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_DetachThread")]
    public static void detahc_thread (Thread thread);

    [CCode (cname = "SDL_GetCurrentThreadID")]
    public static ThreadID get_current_thread_id ();

    [CCode (cname = "SDL_GetThreadID")]
    public static ThreadID get_thread_id (Thread thread);

    [CCode (cname = "SDL_GetThreadName")]
    public static unowned string get_thread_name (Thread thread);

    [CCode (cname = "SDL_GetThreadState")]
    public static ThreadState get_thread_state (Thread thread);

    [CCode (cname = "SDL_GetTLS")]
    public static void * get_tls (TLSId id);

    [CCode (cname = "SDL_SetCurrentThreadPriority")]
    public static bool set_current_thread_priority (ThreadPriority priority);

    [CCode (cname = "SDL_SetTLS")]
    public static bool set_tls (TLSId id, void* value, TLSDestructorCallback? destructor);

    [CCode (cname = "SDL_WaitThread")]
    public static void wait_thread (Thread thread, out int status);

    [Compact, CCode (cname = "SDL_Thread", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Thread {}

    [CCode (cname = "SDL_ThreadFunction", has_target = true)]
    public delegate int ThreadFunction ();

    [SimpleType, CCode (cname = "SDL_ThreadID", has_type_id = false)]
    public struct ThreadID : uint64 {}

    [CCode (cname = "SDL_TLSDestructorCallback")]
    public delegate void TLSDestructorCallback (void* value);

    [CCode (cname = "SDL_TLSDestructorCallback", has_type_id = false)]
    public struct TLSId : Atomic.AtomicInt {}

    [CCode (cname = "SDL_ThreadPriority", cprefix = "SDL_THREAD_PRIORITY_", has_type_id = false)]
    public enum ThreadPriority {
        LOW,
        NORMAL,
        HIGH,
        TIME_CRITICAL,
    } // ThreadPriority

    [CCode (cname = "SDL_ThreadState", cprefix = "SDL_THREAD_", has_type_id = false)]
    public enum ThreadState {
        UNKNOWN,
        ALIVE,
        DETACHED,
        COMPLETE,
    } // ThreadState

    namespace PropThreadCreate {
        [CCode (cname = "SDL_PROP_THREAD_CREATE_ENTRY_FUNCTION_POINTER")]
        public const string ENTRY_FUNCTION_POINTER;

        [CCode (cname = "SDL_PROP_THREAD_CREATE_NAME_STRING")]
        public const string NAME_STRING;

        [CCode (cname = "SDL_PROP_THREAD_CREATE_USERDATA_POINTER")]
        public const string USERDATA_POINTER;

        [CCode (cname = "SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER")]
        public const string STACKSIZE_NUMBER;
    } // PropThreadCreate
} // SDL.Threads

///
/// Thread Synchronization Primitives (SDL_mutex.h)
///
[CCode (cheader_filename = "SDL3/SDL_mutex.h")]
namespace SDL.Mutex {
    [CCode (cname = "SDL_BroadcastCondition")]
    public static void broadcast_condition (Condition cond);

    [CCode (cname = "SDL_CreateCondition")]
    public static Condition ? create_condition ();

    [CCode (cname = "SDL_CreateMutex")]
    public static Mutex ? create_mutex ();

    [CCode (cname = "SDL_CreateRWLock")]
    public static RWLock ? create_rw_lock ();

    [CCode (cname = "SDL_CreateSemaphore")]
    public static Semaphore ? create_semaphore (uint32 initial_value);

    [CCode (cname = "SDL_DestroyCondition")]
    public static void destroy_condition (Condition cond);

    [CCode (cname = "SDL_DestroyMutex")]
    public static void destroy_mutex (Mutex mutex);

    [CCode (cname = "SDL_DestroyRWLock")]
    public static void destroy_rw_lock (RWLock rwlock);

    [CCode (cname = "SDL_DestroySemaphore")]
    public static void destroy_semaphore (Semaphore sem);

    [CCode (cname = "SDL_GetSemaphoreValue")]
    public static uint32 get_semaphore_value (Semaphore sem);

    [CCode (cname = "SDL_LockMutex")]
    public static void lock_mutex (Mutex mutex);

    [CCode (cname = "SDL_LockRWLockForReading")]
    public static void lock_rw_lock_for_reading (RWLock rwlock);

    [CCode (cname = "SDL_LockRWLockForWriting")]
    public static void lock_rw_lock_for_writing (RWLock rwlock);

    [CCode (cname = "SDL_SetInitialized")]
    public static void set_initialized (InitState state, bool initialized);

    [CCode (cname = "SDL_ShouldInit")]
    public static bool should_init (InitState state);

    [CCode (cname = "SDL_ShouldQuit")]
    public static bool should_quit (InitState state);

    [CCode (cname = "SDL_SignalCondition")]
    public static void signal_condition (Condition cond);

    [CCode (cname = "SDL_SignalSemaphore")]
    public static void signal_semaphore (Semaphore sem);

    [CCode (cname = "SDL_TryLockMutex")]
    public static bool try_lock_mutex (Mutex mutex);

    [CCode (cname = "SDL_TryLockRWLockForReading")]
    public static bool try_lock_rw_for_reading (RWLock rwlock);

    [CCode (cname = "SDL_TryLockRWLockForWriting")]
    public static bool try_lock_rw_for_writing (RWLock rwlock);

    [CCode (cname = "SDL_TryWaitSemaphore")]
    public static bool try_wait_semaphore (Semaphore sem);

    [CCode (cname = "SDL_UnlockMutex")]
    public static void unlock_mutex (Mutex mutex);

    [CCode (cname = "SDL_UnlockRWLock")]
    public static void unlock_rw_lock (RWLock rwlock);

    [CCode (cname = "SDL_WaitCondition")]
    public static void wait_condition (Condition cond, Mutex mutex);

    [CCode (cname = "SDL_WaitConditionTimeout")]
    public static bool wait_condition_timeout (Condition cond, Mutex mutex, int32 timeout_ms);

    [CCode (cname = "SDL_WaitSemaphore")]
    public static void wait_semaphore (Semaphore sem);

    [CCode (cname = "SDL_WaitSemaphoreTimeout")]
    public static bool wait_semaphore_timeout (Semaphore sem, int32 timeout_ms);

    [Compact, CCode (cname = "SDL_Condition", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Condition {}

    [Compact, CCode (cname = "SDL_Mutex", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Mutex {}

    [Compact, CCode (cname = "SDL_RWLock", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class RWLock {}

    [Compact, CCode (cname = "SDL_Semaphore", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Semaphore {}

    [CCode (cname = "SDL_InitState", has_type_id = false)]
    public struct InitState {
        public Atomic.AtomicInt status;
        public Threads.ThreadID thread;
        public void* reserved;
    } // InitState

    [CCode (cname = "SDL_InitStatus", cprefix = "SDL_INIT_STATUS_", has_type_id = false)]
    public enum InitStatus {
        UNINITIALIZED,
        INITIALIZING,
        INITIALIZED,
        UNINITIALIZING,
    } // InitStatus
} // SDL.Mutex

///
/// Atomic Operations (SDL_atomic.h)
///
[CCode (cheader_filename = "SDL3/SDL_atomic.h")]
namespace SDL.Atomic {
    [CCode (cname = "SDL_AddAtomicInt")]
    public static int add_atomic_int (AtomicInt a, int v);

    /**
     * Add to an atomic variable.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_AddAtomicU32]]
     *
     * @param a a pointer to an {@link AtomicU32} variable to be modified.
     * @param v the desired value to add or subtract.
     *
     * @return the previous value of the atomic variable.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_AddAtomicU32")]
    public static int add_atomic_u32 (AtomicU32 a, int v);

    [CCode (cname = "SDL_CompareAndSwapAtomicInt")]
    public static bool compare_and_swap_atomic_int (AtomicInt a, int oldval, int newval);

    [CCode (cname = "SDL_CompareAndSwapAtomicPointer")]
    public static bool compare_and_swap_atomic_pointer (void* * a, void* oldval, void* newval);

    [CCode (cname = "SDL_CompareAndSwapAtomicU32")]
    public static bool compare_and_swap_atomic_u32(AtomicU32 a, uint32 oldval, uint32 newval);

    [CCode (cname = "SDL_GetAtomicInt")]
    public static int get_atomic_int (AtomicInt a);

    [CCode (cname = "SDL_GetAtomicPointer")]
    public static void * get_atomic_pointer (void* * a);

    [CCode (cname = "SDL_GetAtomicU32")]
    public static uint32 get_atomic_u32(AtomicU32 a);

    [CCode (cname = "SDL_LockSpinlock")]
    public static void lock_spin_lock (SpinLock spin_lock);

    [CCode (cname = "SDL_MemoryBarrierAcquireFunction")]
    public static void memory_barrier_acquire_function ();

    [CCode (cname = "SDL_MemoryBarrierReleaseFunction")]
    public static void memory_barrier_release_function ();

    [CCode (cname = "SDL_SetAtomicInt")]
    public static int set_atomic_int (AtomicInt a, int v);

    [CCode (cname = "SDL_SetAtomicPointer")]
    public static void * set_atomic_pointer (void* * a, void* v);

    [CCode (cname = "SDL_SetAtomicU32")]
    public static uint32 set_atomic_u32(AtomicU32 a, uint32 v);

    [CCode (cname = "SDL_TryLockSpinlock")]
    public static bool try_to_spin_lock (SpinLock spin_lock);

    [CCode (cname = "SDL_UnlockSpinlock")]
    public static void unlock_spin_lock (SpinLock spin_lock);

    [SimpleType, CCode (cname = "SDL_SpinLock", has_type_id = false)]
    public struct SpinLock : int {}

    [CCode (cname = "SDL_AtomicInt", has_type_id = false)]
    public struct AtomicInt {
        public int value;
    } // AtomicInt

    [CCode (cname = "SDL_AtomicU32", has_type_id = false)]
    public struct AtomicU32 {
        public uint32 value;
    } // AtomicU32

    [CCode (cname = "SDL_AtomicDecRef")]
    public static bool atomic_dec_ref (AtomicInt a);

    [CCode (cname = "SDL_AtomicIncRef")]
    public static bool atomic_inc_ref (AtomicInt a);

    [CCode (cname = "SDL_CompilerBarrier")]
    public static void compiler_barrier ();

    [CCode (cname = "SDL_CPUPauseInstruction")]
    public static void cpu_pause_instruction ();

    [CCode (cname = "SDL_MemoryBarrierAcquire")]
    public static void memory_barrier_acquire ();

    [CCode (cname = "SDL_MemoryBarrierRelease")]
    public static void memory_barrier_release ();
} // SDL.Atomic

///
/// TIME
///

///
/// Timer Support (SDL_timer.h)
///
[CCode (cheader_filename = "SDL3/SDL_timer.h")]
namespace SDL.Timer {
    [CCode (cname = "SDL_AddTimer", has_target = true)]
    public static TimerID add_timer (uint32 interval, TimerCallback callback);

    [CCode (cname = "SDL_AddTimerNS", has_target = true)]
    public static TimerID add_timer_ns (uint64 interval, NSTimerCallback callback);

    [CCode (cname = "SDL_Delay")]
    public static void delay (uint32 ms);

    [CCode (cname = "SDL_DelayNS")]
    public static void delay_ns (uint64 ns);

    [CCode (cname = "SDL_DelayPrecise")]
    public static void delay_precise (uint64 ns);

    [CCode (cname = "SDL_GetPerformanceCounter")]
    public static uint64 get_performance_counter ();

    [CCode (cname = "SDL_GetPerformanceFrequency")]
    public static uint64 get_performance_frequency ();

    [CCode (cname = "SDL_GetTicks")]
    public static uint64 get_ticks ();

    [CCode (cname = "SDL_GetTicksNS")]
    public static uint64 get_ticks_ns ();

    [CCode (cname = "SDL_RemoveTimer")]
    public static bool remove_timer (TimerID id);

    [CCode (cname = "SDL_NSTimerCallback", instance_pos = 0)]
    public delegate uint64 NSTimerCallback (TimerID timer_id, uint64 interval);

    [CCode (cname = "SDL_TimerCallback", instance_pos = 0)]
    public delegate uint32 TimerCallback (TimerID timer_id, uint32 interval);

    [SimpleType, CCode (cname = "SDL_TimerID", has_type_id = false)]
    public struct TimerID : uint32 {}

    [CCode (cname = "SDL_MS_PER_SECOND")]
    public const double MS_PER_SECOND;

    [CCode (cname = "SDL_MS_TO_NS")]
    public static double ms_to_ns (double ms);

    [CCode (cname = "SDL_NS_PER_MS")]
    public const double NS_PER_MS;

    [CCode (cname = "SDL_NS_PER_SECOND")]
    public const double NS_PER_SECOND;

    [CCode (cname = "SDL_NS_PER_US")]
    public const double NS_PER_US;

    [CCode (cname = "SDL_NS_TO_MS")]
    public static double ns_to_ms (double ns);

    [CCode (cname = "SDL_NS_TO_SECONDS")]
    public static double ns_to_seconds (double ns);

    [CCode (cname = "SDL_NS_TO_US")]
    public static double ns_to_us (double ns);

    [CCode (cname = "SDL_SECONDS_TO_NS")]
    public static double seconds_to_ns (double s);

    [CCode (cname = "SDL_US_PER_SECOND")]
    public const double US_PER_SECOND;

    [CCode (cname = "SDL_US_TO_NS")]
    public static double us_to_ns (double us);
} // SDL.Timer

///
/// Date and Time (SDL_time.h)
///
[CCode (cheader_filename = "SDL3/SDL_time.h")]
namespace SDL.Time {
    [CCode (cname = "SDL_DateTimeToTime")]
    public static bool datetime_to_time (Time.DateTime dt, out StdInc.Time ticks);

    [CCode (cname = "SDL_GetCurrentTime")]
    public static bool get_current_time (out StdInc.Time ticks);

    [CCode (cname = "SDL_GetDateTimeLocalePreferences")]
    public static bool get_date_time_locale_preferences (out DateFormat? date_format,
            out TimeFormat? time_format);

    [CCode (cname = "SDL_GetDayOfWeek")]
    public static int get_day_of_week (int year, int month, int day);

    [CCode (cname = "SDL_GetDayOfYear")]
    public static int get_day_of_year (int year, int month, int day);

    [CCode (cname = "SDL_GetDaysInMonth")]
    public static int get_days_in_month (int year, int month);

    [CCode (cname = "SDL_TimeFromWindows")]
    public static StdInc.Time time_from_windows (uint32 dw_low_date_time, uint32 dw_high_date_time);

    [CCode (cname = "SDL_TimeToDateTime")]
    public static bool time_to_datetime (StdInc.Time ticks, out DateTime dt, bool local_time);

    [CCode (cname = "SDL_TimeToWindows")]
    public static void time_to_windows (StdInc.Time ticks, out uint32 dw_low_date_time,
            out uint32 dw_high_date_time);

    [CCode (cname = "SDL_DateTime", has_type_id = false)]
    public struct DateTime {
        public int year;
        public int month;
        public int day;
        public int hour;
        public int minute;
        public int second;
        public int nanosecond;
        public int day_of_week;
        public int utc_offset;
    } // DateTime

    [CCode (cname = "SDL_DateFormat", cprefix = "SDL_DATE_FORMAT_", has_type_id = false)]
    public enum DateFormat {
        YYYYMMDD,
        DDMMYYYY,
        MMDDYYYY,
    } // DateFormat

    [CCode (cname = "SDL_TimeFormat", cprefix = "SDL_TIME_", has_type_id = false)]
    public enum TimeFormat {
        FORMAT_24HR,
        FORMAT_12HR,
    } // TimeFormat
} // SDL.Time

///
/// File and I/O Abstractions
///

///
/// Filesystem Access (SDL_filesystem.h)
///
[CCode (cheader_filename = "SDL3/SDL_filesystem.h")]
namespace SDL.FileSystem {
    [CCode (cname = "SDL_CopyFile")]
    public static bool copy_file (string oldpath, string newpath);

    [CCode (cname = "SDL_CreateDirectory")]
    public static bool create_directory (string path);

    [CCode (cname = "SDL_EnumerateDirectory", has_target = true)]
    public static bool enumerate_directory (string path, EnumerateDirectoryCallback callback);

    [CCode (cname = "SDL_GetBasePath")]
    public static unowned string ? get_base_path ();

    [CCode (cname = "SDL_GetCurrentDirectory")]
    public static unowned string ? get_current_directory ();

    [CCode (cname = "SDL_GetPathInfo")]
    public static bool get_path_info (string path, out PathInfo? info);

    [CCode (cname = "SDL_GetPrefPath")]
    public static unowned string ? get_pref_path (string org, string app);

    [CCode (cname = "SDL_GetUserFolder")]
    public static unowned string ? get_user_folder (Folder folder);

    [CCode (cname = "SDL_GlobDirectory")]
    public static unowned string[] ? glob_directory (string path, string? pattern, GlobFlags flags);

    [CCode (cname = "SDL_RemovePath")]
    public static bool remove_path (string path);

    [CCode (cname = "SDL_RenamePath")]
    public static bool rename_path (string oldpath, string newpath);

    [CCode (cname = "SDL_EnumerateDirectoryCallback", has_target = true, instance_pos = 0)]
    public delegate EnumerationResult EnumerateDirectoryCallback (string dirname, string fname);

    [CCode (cname = "Uint32", cprefix = "SDL_GLOB_", has_type_id = false)]
    public enum GlobFlags {
        CASEINSENSITIVE,
    }

    [Flags, CCode (cname = "Uint32", cprefix = "SDL_GPU_TEXTUREUSAGE_", has_type_id = false)]
    public enum GPUTextureUsageFlags {
        SAMPLER,
        COLOR_TARGET,
        DEPTH_STENCIL_TARGET,
        GRAPHICS_STORAGE_READ,
        COMPUTE_STORAGE_READ,
        COMPUTE_STORAGE_WRITE,
        COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE,
    }

    [CCode (cname = "SDL_PathInfo", has_type_id = false)]
    public struct PathInfo {
        public PathType type;
        public uint64 size;
        public StdInc.Time create_time;
        public StdInc.Time modify_time;
        public StdInc.Time access_time;
    } // PathInfo;

    [CCode (cname = "SDL_EnumerationResult", cprefix = "SDL_ENUM_", has_type_id = false)]
    public enum EnumerationResult {
        CONTINUE,
        SUCCESS,
        FAILURE,
    } // EnumerationResult

    [CCode (cname = "SDL_Folder", cprefix = "SDL_FOLDER_", has_type_id = false)]
    public enum Folder {
        HOME,
        DESKTOP,
        DOCUMENTS,
        DOWNLOADS,
        MUSIC,
        PICTURES,
        PUBLICSHARE,
        SAVEDGAMES,
        SCREENSHOTS,
        TEMPLATES,
        VIDEOS,
        COUNT,
    } // Folder

    [CCode (cname = "SDL_PathType", cprefix = "SDL_PATHTYPE_", has_type_id = false)]
    public enum PathType {
        NONE,
        FILE,
        DIRECTORY,
        OTHER,
    } // PathType
} // SDL.FileSystem

///
/// Storage Abstraction (SDL_storage.h)
///
[CCode (cheader_filename = "SDL3/SDL_storage.h")]
namespace SDL.Storage {
    [CCode (cname = "SDL_CloseStorage")]
    public static bool close_storage (Storage storage);

    [CCode (cname = "SDL_CopyStorageFile")]
    public static bool copy_storage_file (Storage storage, string oldpath, string newpath);

    [CCode (cname = "SDL_CreateStorageDirectory")]
    public static bool create_storage_directory (Storage storage, string path);

    [CCode (cname = "SDL_EnumerateStorageDirectory", has_target = true)]
    public static bool enumerate_storage_directory (Storage storage,
            string path,
            FileSystem.EnumerateDirectoryCallback callback);

    [CCode (cname = "SDL_GetStorageFileSize")]
    public static bool get_storage_file_size (Storage storage, string path, out uint64 length);

    [CCode (cname = "SDL_GetStoragePathInfo")]
    public static bool get_storage_path_info (Storage storage, string path,
            out FileSystem.PathInfo? info);

    [CCode (cname = "SDL_GetStorageSpaceRemaining")]
    public static uint64 get_storage_space_remaining (Storage storage);

    [CCode (cname = "SDL_GlobStorageDirectory")]
    public static unowned string[] ? glob_storage_directory (Storage storage,
            string path,
            string? pattern,
            FileSystem.GlobFlags flags);

    [CCode (cname = "SDL_OpenFileStorage")]
    public static Storage ? open_file_storage (string path);

    [CCode (cname = "SDL_OpenStorage", has_target = true)]
    public static Storage ? open_storage (StorageInterface iface);

    [CCode (cname = "SDL_OpenTitleStorage")]
    public static Storage ? open_title_storage (string override_path,
            SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_OpenUserStorage")]
    public static Storage ? open_user_storage (string org, string app,
            SDL.Properties.PropertiesID props);

    [CCode (cname = "SDL_ReadStorageFile")]
    public static bool read_storage_file (Storage storage, string path, void* destination,
            uint64 length);

    [CCode (cname = "SDL_RemoveStoragePath")]
    public static bool remove_storage_path (Storage storage, string path);

    [CCode (cname = "SDL_RenameStoragePath")]
    public static bool rename_storage_path (Storage storage, string oldpath, string newpath);

    [CCode (cname = "SDL_StorageReady")]
    public static bool storage_ready (Storage storage);

    [CCode (cname = "SDL_WriteStorageFile")]
    public static bool write_storage_file (Storage storage, string path, void* source,
            uint64 length);

    [Compact, CCode (cname = "SDL_Storage", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Storage {}

    [CCode (cname = "SDL_StorageInterface", has_type_id = false)]
    public struct StorageInterface {
        public uint32 version;

        [CCode (cname = "close", has_target = true)]
        public bool close ();

        [CCode (cname = "ready", has_target = true)]
        public bool ready ();

        [CCode (cname = "enumerate", has_target = true, instance_pos = 0, delegate_target_pos = 2)]
        public bool enumerate (string path, FileSystem.EnumerateDirectoryCallback callback);

        [CCode (cname = "info", has_target = true, instance_pos = 0)]
        public bool info (string path, out FileSystem.PathInfo info);

        [CCode (cname = "read_file", has_target = true, instance_pos = 0)]
        public bool read_file (string path, void* destination, uint64 length);

        [CCode (cname = "write_file", has_target = true, instance_pos = 0)]
        public bool write_file (string path, void* source, uint64 length);

        [CCode (cname = "mkdir", has_target = true, instance_pos = 0)]
        public bool mkdir (string path);

        [CCode (cname = "remove", has_target = true, instance_pos = 0)]
        public bool remove (string path);

        [CCode (cname = "rename", has_target = true, instance_pos = 0)]
        public bool rename (string oldpath, string newpath);

        [CCode (cname = "copy", has_target = true, instance_pos = 0)]
        public bool copy (string oldpath, string newpath);

        [CCode (cname = "space_remaining", has_target = true, instance_pos = 0)]
        public uint64 space_remaining ();
    } // StorageInterface;
} // SDL.Storage

///
/// I/O Streams (SDL_iostream.h)
///
[CCode (cheader_filename = "SDL3/SDL_iostream.h")]
namespace SDL.IOStream {
    [CCode (cname = "SDL_CloseIO")]
    public static bool close_io (IOStream context);

    [CCode (cname = "SDL_FlushIO")]
    public static bool flush_io (IOStream context);

    [CCode (cname = "SDL_GetIOProperties")]
    public static SDL.Properties.PropertiesID get_io_properties (IOStream context);

    [CCode (cname = "SDL_GetIOSize")]
    public static int64 get_io_size (IOStream context);

    [CCode (cname = "SDL_GetIOStatus")]
    public static IOStatus get_io_status (IOStream context);

    [CCode (cname = "SDL_IOFromConstMem")]
    public static IOStream ? io_from_const_mem (void* mem, size_t size);

    [CCode (cname = "SDL_IOFromDynamicMem")]
    public static IOStream ? io_from_dynamic_mem ();

    [CCode (cname = "SDL_IOFromFile")]
    public static IOStream ? io_from_file (string file, string mode);

    [CCode (cname = "SDL_IOFromMem")]
    public static IOStream ? io_from_mem (void* mem, size_t size);

    [PrintfFormat]
    [CCode (cname = "SDL_IOprintf", sentinel = "")]
    public static size_t io_printf (IOStream context, string format, ...);

    [CCode (cname = "SDL_LoadFile")]
    public static void * load_file (string file, out size_t datasize);

    [CCode (cname = "SDL_LoadFile")]
    public static void * load_file_io (IOStream src, out size_t? datasize, bool close_io);

    [CCode (cname = "SDL_OpenIO", has_target = true)]
    public static IOStream ? open_io (IOStreamInterface iface);

    [CCode (cname = "SDL_ReadIO")]
    public static size_t read_io (IOStream context, void* ptr, size_t size);

    [CCode (cname = "SDL_ReadS16BE")]
    public static bool read_s16_be (IOStream src, out int16 value);

    [CCode (cname = "SDL_ReadS16LE")]
    public static bool read_s16_le (IOStream src, out int16 value);

    [CCode (cname = "SDL_ReadS32BE")]
    public static bool read_s32_be (IOStream src, out int32 value);

    [CCode (cname = "SDL_ReadS32LE")]
    public static bool read_s32_le (IOStream src, out int32 value);

    [CCode (cname = "SDL_ReadS64BE")]
    public static bool read_s64_be (IOStream src, out int64 value);

    [CCode (cname = "SDL_ReadS64LE")]
    public static bool read_s64_le (IOStream src, out int64 value);

    [CCode (cname = "SDL_ReadS8")]
    public static bool read_s8(IOStream src, out int8 value);

    [CCode (cname = "SDL_ReadU16BE")]
    public static bool read_u16_be (IOStream src, out uint16 value);

    [CCode (cname = "SDL_ReadU16LE")]
    public static bool read_u16_le (IOStream src, out uint16 value);

    [CCode (cname = "SDL_ReadU32BE")]
    public static bool read_u32_be (IOStream src, out uint32 value);

    [CCode (cname = "SDL_ReadU32LE")]
    public static bool read_u32_le (IOStream src, out uint32 value);

    [CCode (cname = "SDL_ReadU64BE")]
    public static bool read_u64_be (IOStream src, out uint64 value);

    [CCode (cname = "SDL_ReadU64LE")]
    public static bool read_u64_le (IOStream src, out uint64 value);

    [CCode (cname = "SDL_ReadU8")]
    public static bool read_u8(IOStream src, out uint8 value);

    [CCode (cname = "SDL_SaveFile")]
    public static bool save_file (string file, void* data, size_t datasize);

    [CCode (cname = "SDL_SaveFile_IO")]
    public static bool save_file_io (IOStream src, void* data, size_t datasize, bool close_io);

    [CCode (cname = "SDL_SeekIO")]
    public static int64 seek_io (IOStream context, int64 offset, IOWhence whence);

    [CCode (cname = "SDL_TellIO")]
    public static int64 tell_io (IOStream context);

    [CCode (cname = "SDL_WriteIO")]
    public static size_t write_io (IOStream context, void* ptr, size_t size);

    [CCode (cname = "SDL_WriteS16BE")]
    public static bool write_s16_be (IOStream dst, int16 value);

    [CCode (cname = "SDL_WriteS16LE")]
    public static bool write_s16_le (IOStream dst, int16 value);

    [CCode (cname = "SDL_WriteS32BE")]
    public static bool write_s32_be (IOStream dst, int32 value);

    [CCode (cname = "SDL_WriteS32LE")]
    public static bool write_s32_le (IOStream dst, int32 value);

    [CCode (cname = "SDL_WriteS64BE")]
    public static bool write_s64_be (IOStream dst, int64 value);

    [CCode (cname = "SDL_WriteS64LE")]
    public static bool write_s64_le (IOStream dst, int64 value);

    [CCode (cname = "SDL_WriteS8")]
    public static bool write_s8(IOStream dst, int8 value);

    [CCode (cname = "SDL_WriteU16BE")]
    public static bool write_u16_be (IOStream dst, uint16 value);

    [CCode (cname = "SDL_WriteU16LE")]
    public static bool write_u16_le (IOStream dst, uint16 value);

    [CCode (cname = "SDL_WriteU32BE")]
    public static bool write_u32_be (IOStream dst, uint32 value);

    [CCode (cname = "SDL_WriteU32LE")]
    public static bool write_u32_le (IOStream dst, uint32 value);

    [CCode (cname = "SDL_WriteU64BE")]
    public static bool write_u64_be (IOStream dst, uint64 value);

    [CCode (cname = "SDL_WriteU64LE")]
    public static bool write_u64_le (IOStream dst, uint64 value);

    [CCode (cname = "SDL_WriteU8")]
    public static bool write_u8(IOStream dst, uint8 value);

    [Compact, CCode (cname = "SDL_IOStream", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class IOStream {}

    [CCode (cname = "SDL_IOStreamInterface", has_type_id = false)]
    public struct IOStreamInterface {
        public uint32 version;

        [CCode (cname = "size", has_target = true)]
        public int64 size ();

        [CCode (cname = "seek", has_target = true, instance_pos = 0)]
        public int64 seek (int64 offset, IOWhence whence);

        [CCode (cname = "read", has_target = true, instance_pos = 0)]
        public size_t read (void* ptr, size_t size, IOStatus status);

        [CCode (cname = "write", has_target = true, instance_pos = 0)]
        public size_t write (void* ptr, size_t size, IOStatus status);

        [CCode (cname = "flush", has_target = true, instance_pos = 0)]
        public bool flush (IOStatus status);

        [CCode (cname = "close", has_target = true)]
        public bool close ();
    } // IOStreamInterface

    [CCode (cname = "SDL_IOStatus", cprefix = "SDL_IO_STATUS_", has_type_id = false)]
    public enum IOStatus {
        READY,
        ERROR,
        EOF,
        NOT_READY,
        READONLY,
        WRITEONLY,
    } // IOStatus

    [CCode (cname = "SDL_IOWhence", cprefix = "SDL_IO_", has_type_id = false)]
    public enum IOWhence {
        SEEK_SET,
        SEEK_CUR,
        SEEK_END,
    } // IOWhence

    /**
     * Properties used by {@link io_from_mem} and {@link io_from_const_mem}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IOFromMem]]
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IOFromConstMem]]
     */
    namespace PropIOStream {
        /**
         * The mem parameter that was passed to {@link io_from_mem}
         * or {@link io_from_const_mem}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_IOFromMem]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_IOSTREAM_MEMORY_POINTER")]
        public const string MEMORY_POINTER;

        /**
         * The size parameter that was passed to {@link io_from_mem}
         * or {@link io_from_const_mem}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_IOFromMem]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_IOSTREAM_MEMORY_SIZE_NUMBER")]
        public const string MEMORY_SIZE_NUMBER;

        /**
         * If this property is set to a non-null value it will be interpreted
         * as a function of {@link StdInc.FreeFunc} type and called with the
         * passed mem pointer when closing the stream. By default it is unset,
         * i.e., the memory will not be freed.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_IOFromMem]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_IOSTREAM_MEMORY_FREE_FUNC_POINTER")]
        public const string MEMORY_FREE_FUNC_POINTER;
    }
} // SDL.IOStream

///
/// Async I/O (SDL_asyncio.h)
///
[CCode (cheader_filename = "SDL3/SDL_asyncio.h")]
namespace SDL.AsyncIO {
    [CCode (cname = "SDL_AsyncIOFromFile")]
    public static AsyncIO async_io_from_file (string file, string mode);

    [CCode (cname = "SDL_CloseAsyncIO", has_target = true)]
    public static bool close_async_io (AsyncIO asyncio, bool flush, AsyncIOQueue queue);

    [CCode (cname = "SDL_CreateAsyncIOQueue")]
    public static AsyncIOQueue create_async_io_queue ();

    [CCode (cname = "SDL_DestroyAsyncIOQueue")]
    public static void destroy_async_io_queue (AsyncIOQueue queue);

    [CCode (cname = "SDL_GetAsyncIOResult")]
    public static bool get_async_io_result (AsyncIOQueue queue, out AsyncIOOutcome outcome);

    [CCode (cname = "SDL_GetAsyncIOSize")]
    public static int64 get_async_io_size (AsyncIO asyncio);

    [CCode (cname = "SDL_LoadFileAsync")]
    public static bool load_file_async (string file, AsyncIOQueue queue, void* userdata);

    [CCode (cname = "SDL_ReadAsyncIO", has_target = true)]
    public static bool red_async_io (AsyncIO asyncio, void* ptr, uint64 offset, uint64 size,
            AsyncIOQueue queue);

    [CCode (cname = "SDL_SignalAsyncIOQueue")]
    public static void signal_async_io_queue (AsyncIOQueue queue);

    [CCode (cname = "SDL_WaitAsyncIOResult")]
    public static bool wait_async_io_result (AsyncIOQueue queue, out AsyncIOOutcome outcome,
            int32 timeout_ms);

    [CCode (cname = "SDL_WriteAsyncIO", has_target = true)]
    public static bool write_async_io (AsyncIO asyncio, void* ptr, uint64 offset, uint64 size,
            AsyncIOQueue queue);

    [Compact, CCode (cname = "SDL_AsyncIO", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class AsyncIO {}

    [Compact, CCode (cname = "SDL_AsyncIOQueue", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class AsyncIOQueue {}

    [CCode (cname = "SDL_AsyncIOOutcome", has_destroy_function = false, has_type_id = false)]
    public struct AsyncIOOutcome {
        public AsyncIO asyncio;
        public AsyncIOTaskType type;
        public AsyncIOResult result;
        public void* buffer;
        public uint64 offset;
        public uint64 bytes_requested;
        public uint64 bytes_transferred;
        public void* userdata;
    } // AsyncIOOutcome

    [CCode (cname = "SDL_AsyncIOResult", cprefix = "SDL_ASYNCIO_", has_type_id = false)]
    public enum AsyncIOResult {
        COMPLETE,
        FAILURE,
        CANCELED,
    } // AsyncIOResult

    [CCode (cname = "SDL_AsyncIOTaskType", cprefix = "SDL_ASYNCIO_TASK_", has_type_id = false)]
    public enum AsyncIOTaskType {
        READ,
        WRITE,
        CLOSE,
    } // AsyncIOTaskType
} // SDL.AsyncIO

///
/// PLATFORM AND CPU INFORMATION
///

///
/// Platform Detection (SDL_platform.h)
///
[CCode (cheader_filename = "SDL3/SDL_platform.h")]
namespace SDL.Platform {
    [CCode (cname = "SDL_GetPlatform")]
    public static string get_platform ();

    /* There are defines that only exists if enabled in SDL
     * What you need to do is aks for them in Vala code, nothing more
       // SDL_PLATFORM_3DS
       // SDL_PLATFORM_AIX
       // SDL_PLATFORM_ANDROID
       // SDL_PLATFORM_APPLE
       // SDL_PLATFORM_BSDI
       // SDL_PLATFORM_CYGWIN
       // SDL_PLATFORM_EMSCRIPTEN
       // SDL_PLATFORM_FREEBSD
       // SDL_PLATFORM_GDK
       // SDL_PLATFORM_HAIKU
       // SDL_PLATFORM_HPUX
       // SDL_PLATFORM_IOS
       // SDL_PLATFORM_IRIX
       // SDL_PLATFORM_LINUX
       // SDL_PLATFORM_MACOS
       // SDL_PLATFORM_NETBSD
       // SDL_PLATFORM_OPENBSD
       // SDL_PLATFORM_OS2
       // SDL_PLATFORM_OSF
       // SDL_PLATFORM_PS2
       // SDL_PLATFORM_PSP
       // SDL_PLATFORM_QNXNTO
       // SDL_PLATFORM_RISCOS
       // SDL_PLATFORM_SOLARIS
       // SDL_PLATFORM_TVOS
       // SDL_PLATFORM_UNIX
       // SDL_PLATFORM_VISIONOS
       // SDL_PLATFORM_VITA
       // SDL_PLATFORM_WIN32
       // SDL_PLATFORM_WINDOWS
       // SDL_PLATFORM_WINGDK
       // SDL_PLATFORM_XBOXONE
       // SDL_PLATFORM_XBOXSERIES
       // SDL_WINAPI_FAMILY_PHONE */
} // SDL.Platform

///
/// CPU Feature Detection (SDL_cpuinfo.h)
///
[CCode (cheader_filename = "SDL3/SDL_cpuinfo.h")]
namespace SDL.CPUInfo {
    [CCode (cname = "SDL_GetCPUCacheLineSize")]
    public static int get_cpu_cache_line_size ();

    [CCode (cname = "SDL_GetNumLogicalCPUCores")]
    public static int get_num_logical_cpu_cores ();

    [CCode (cname = "SDL_GetSIMDAlignment")]
    public static size_t get_simd_alignment ();

    /**
     * Report the size of a page of memory.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetSystemPageSize]]
     *
     * @return the size of a single page of memory, in bytes, or 0 if SDL
     * can't determine this information.
     *
     * @since 3.4.0
     */
    [Version (since = "3.4.0")]
    [CCode (cname = "SDL_GetSystemPageSize")]
    public static int get_system_page_size ();

    [CCode (cname = "SDL_GetSystemRAM")]
    public static int get_system_ram ();

    [CCode (cname = "SDL_HasAltiVec")]
    public static bool has_alti_vec ();

    [CCode (cname = "SDL_HasARMSIMD")]
    public static bool has_arm_simd ();

    [CCode (cname = "SDL_HasAVX")]
    public static bool has_avx ();

    [CCode (cname = "SDL_HasAVX2")]
    public static bool has_avx2();

    [CCode (cname = "SDL_HasAVX512F")]
    public static bool has_avx_512f ();

    [CCode (cname = "SDL_HasLASX")]
    public static bool has_lasx ();

    [CCode (cname = "SDL_HasLSX")]
    public static bool has_lsx ();

    [CCode (cname = "SDL_HasMMX")]
    public static bool has_mmx ();

    [CCode (cname = "SDL_HasNEON")]
    public static bool has_neon ();

    [CCode (cname = "SDL_HasSSE")]
    public static bool has_sse ();

    [CCode (cname = "SDL_HasSSE2")]
    public static bool has_sse2();

    [CCode (cname = "SDL_HasSSE3")]
    public static bool has_sse3();

    [CCode (cname = "SDL_HasSSE41")]
    public static bool has_sse41();

    [CCode (cname = "SDL_HasSSE42")]
    public static bool has_sse42();

    [CCode (cname = "SDL_CACHELINE_SIZE")]
    public const int CACHELINE_SIZE;
} // SDL.CPUInfo

///
/// Compiler Intrinsics Detection (SDL_intrin.h)
///
/* There are defines that only exists if enabled in SDL
 * What you need to do is aks for them in Vala code, nothing more
    [CCode (cheader_filename = "SDL3/SDL_intrin.h")]
    namespace SDL.Intrinsics {
        // SDL_ALTIVEC_INTRINSICS
        // SDL_AVX2_INTRINSICS
        // SDL_AVX512F_INTRINSICS
        // SDL_AVX_INTRINSICS
        // SDL_LASX_INTRINSICS
        // SDL_LSX_INTRINSICS
        // SDL_MMX_INTRINSICS
        // SDL_NEON_INTRINSICS
        // SDL_SSE2_INTRINSICS
        // SDL_SSE3_INTRINSICS
        // SDL_SSE4_1_INTRINSICS
        // SDL_SSE4_2_INTRINSICS
        // SDL_SSE_INTRINSICS

        // This is a very specific GCC thing that might not make sens ein Vala
        // SDL_TARGETING
    }*/

///
/// Byte Order and Byte Swapping (SDL_endian.h)
///
[CCode (cheader_filename = "SDL3/SDL_endian.h")]
namespace SDL.Endian {
    [CCode (cname = "SDL_Swap16")]
    public static uint16 swap_16(uint16 x);

    [CCode (cname = "SDL_Swap32")]
    public static uint32 swap_32(uint32 x);

    [CCode (cname = "SDL_Swap64")]
    public static uint64 swap_64(uint64 x);

    [CCode (cname = "SDL_SwapFloat")]
    public static float swap_float (float x);

    [CCode (cname = "SDL_BIG_ENDIAN")]
    public const int BIG_ENDIAN;

    [CCode (cname = "SDL_BYTEORDER")]
    public const int BYTEORDER;

    [CCode (cname = "SDL_FLOATWORDORDER")]
    public const int FLOATWORDORDER;

    [CCode (cname = "SDL_LIL_ENDIAN")]
    public const int LIL_ENDIAN;

    [CCode (cname = "SDL_Swap16BE")]
    public static uint16 swap_16_be (uint16 x);

    [CCode (cname = "SDL_Swap16LE")]
    public static uint16 swap_16_le (uint16 x);

    [CCode (cname = "SDL_Swap32BE")]
    public static uint32 swap_32_be (uint32 x);

    [CCode (cname = "SDL_Swap32LE")]
    public static uint32 swap_32_le (uint32 x);

    [CCode (cname = "SDL_Swap64BE")]
    public static uint64 swap_64_be (uint64 x);

    [CCode (cname = "SDL_Swap64LE")]
    public static uint64 swap_64_le (uint64 x);

    [CCode (cname = "SDL_SwapFloatBE")]
    public static float swap_float_be (float x);

    [CCode (cname = "SDL_SwapFloatLE")]
    public static float swap_float_le (float x);
} // SDL.Endian

/**
 * Bit Manipulation
 *
 * SDL power management routines.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryBits]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_bits.h")]
namespace SDL.Bits {
    /**
     * Determine if a unsigned 32-bit value has exactly one bit set.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_HasExactlyOneBitSet32]]
     *
     * @param x the 32-bit value to examine.
     *
     * @return true if exactly one bit is set in x, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_HasExactlyOneBitSet32")]
    public static bool has_exactly_one_bit_set_32 (uint32 x);

    /**
     *Get the index of the most significant (set) bit in a 32-bit number.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MostSignificantBitIndex32]]
     *
     * @param x the 32-bit value to examine.
     *
     * @return the index of the most significant bit, or -1 if the value is 0.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MostSignificantBitIndex32")]
    public static int most_significant_bit_index_32 (uint32 x);
} // SDL.Bits

///
/// ADDITIONAL FUNCTIONALITY
///

/**
 * Power Management Status
 *
 * SDL power management routines.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryPower]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_power.h")]
namespace SDL.Power {
    /**
     * Look up the address of the named function in a shared object.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPowerInfo]]
     *
     * @param seconds a pointer filled in with the seconds of battery life
     * left, or null to ignore. This will be filled in with -1 if we can't
     * determine a value or there is no battery.
     * @param percent a pointer filled in with the percentage of battery
     * life left, between 0 and 100, or null to ignore. This will be filled
     * in with -1 when we can't determine a value or there is no battery.
     *
     * @return the current battery state or {@link PowerState.ERROR} on
     * failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetPowerInfo")]
    public static PowerState get_power_info (out int? seconds, out int? percent);

    /**
     * The basic state for the system's power supply.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_PowerState]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_PowerState", cprefix = "SDL_POWERSTATE_", has_type_id = false)]
    public enum PowerState {
    /**
     * Error determining power status
     *
     */
        ERROR,

        /**
         * Cannot determine power status
         *
         */
        UNKNOWN,

        /**
         * Not plugged in, running on the battery
         *
         */
        ON_BATTERY,

        /**
         * Plugged in, no battery available
         *
         */
        NO_BATTERY,

        /**
         * Plugged in, charging battery
         *
         */
        CHARGING,

        /**
         * Plugged in, battery charged
         *
         */
        CHARGED,
    } // PowerState
} // SDL.Power

/**
 * Shared Object/DLL Management
 *
 * System-dependent library loading routines. Shared objects are code that
 * is programmatically loadable at runtime. Windows calls these "DLLs", Linux
 * calls them "shared libraries", etc.*
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategorySharedObject]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_loadso.h")]
namespace SDL.LoadSO {
    /**
     * Look up the address of the named function in a shared object.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadFunction]]
     *
     * @param handle a valid shared object handle returned by
     * {@link load_object}.
     * @param name the name of the function to look up.
     *
     * @return a pointer to the function or NULL on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see load_object
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LoadFunction")]
    public static StdInc.FunctionPointer load_function (SharedObject handle, string name);

    /**
     * Dynamically load a shared object.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_LoadObject]]
     *
     * @param so_file a system-dependent name of the object file.
     *
     * @return an opaque pointer to the object handle or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see load_function
     * @see unload_object
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_LoadObject")]
    public static SharedObject ? load_object (string so_file);

    /**
     * Unload a shared object from memory.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_UnloadObject]]
     *
     * @param handle  a valid shared object handle returned by
     * {@link load_object}.
     *
     * @since 3.2.0
     *
     * @see load_object
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_UnloadObject")]
    public static void unload_object (SharedObject handle);

    /**
     * An opaque datatype that represents a loaded shared object.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SharedObject]]
     *
     * @since 3.2.0
     *
     * @see load_object
     * @see load_function
     * @see unload_object
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_SharedObject", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class SharedObject {}
} // SDL.LoadSO

/**
 * Process Control
 *
 * Process control support. These functions provide a cross-platform way to
 * spawn and manage OS-level processes.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryProcess]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_process.h")]
namespace SDL.Process {
    /**
     * Create a new process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcess]]
     *
     * @param args args the path and arguments for the new process.
     * @param pipe_stdio true to create pipes to the process's standard input
     * and from the process's standard output, false for the process to have
     * no input and inherit the application's standard output.
     *
     * @return the newly created and running process, or null if the process
     * couldn't be created.
     *
     * @since 3.2.0
     *
     * @see create_process_with_properties
     * @see get_process_properties
     * @see read_process
     * @see get_process_input
     * @see get_process_output
     * @see kill_process
     * @see wait_process
     * @see destroy_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreateProcess")]
    public static Process? create_process ([CCode (array_length = false)] string[] args,
            bool pipe_stdio);

    /**
     * Create a new process with the specified properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
     *
     * @param props the properties to use.
     *
     * @return the newly created and running process, or null if the process
     * couldn't be created.
     *
     * @since 3.2.0
     *
     * @see create_process_with_properties
     * @see get_process_properties
     * @see read_process
     * @see get_process_input
     * @see get_process_output
     * @see kill_process
     * @see wait_process
     * @see destroy_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_CreateProcessWithProperties")]
    public static Process? create_process_with_properties (SDL.Properties.PropertiesID props);

    /**
     * Destroy a previously created process object.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DestroyProcess]]
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see kill_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DestroyProcess")]
    public static void destroy_process (Process process);

    /**
     * Get the {@link SDL.IOStream.IOStream} associated with process
     * standard input.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessInput]]
     *
     * @param process The process to get the input stream for.
     *
     * @return the input stream or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see get_process_output
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetProcessInput")]
    public static IOStream.IOStream get_process_input (Process process);

    /**
     * Get the {@link SDL.IOStream.IOStream} associated with process
     * standard output.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessInput]]
     *
     * @param process The process to get the output stream for.
     *
     * @return the output stream or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see get_process_input
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetProcessOutput")]
    public static IOStream.IOStream get_process_output (Process process);

    /**
     * Get the properties associated with a process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessInput]]
     *
     * @param process The process to get the output stream for.
     *
     * @return a valid property ID on success or 0 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetProcessProperties")]
    public static SDL.Properties.PropertiesID get_process_properties (Process process);

    /**
     * Stop a process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_KillProcess]]
     *
     * @param process The process to stop.
     * @param force True to terminate the process immediately, false to try
     * to stop the process gracefully. In general you should try to stop the
     * process gracefully first as terminating a process may leave it with
     * half-written data or in some other unstable state.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see wait_process
     * @see destroy_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_KillProcess")]
    public static bool kill_process (Process process, bool force);

    /**
     * Read all the output from a process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ReadProcess]]
     *
     * @param process The process to read.
     * @param data_size A pointer filled in with the number of bytes read,
     * may be null.
     * @param exit_code A pointer filled in with the process exit code if
     * the process has exited, may be null.
     *
     * @return the data or null on failure;  call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see destroy_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ReadProcess")]
    public static void* read_process (Process process, out size_t? data_size, out int? exit_code);

    /**
     * Wait for a process to finish.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ReadProcess]]
     *
     * @param process The process to wait.
     * @param block If true, block until the process finishes; otherwise,
     * report on the process' status.
     * @param exit_code A pointer filled in with the process exit code if
     * the process has exited, may be null.
     *
     * @return true if the process exited, false otherwise.
     *
     * @since 3.2.0
     *
     * @see create_process
     * @see create_process_with_properties
     * @see kill_process
     * @see destroy_process
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WaitProcess")]
    public static bool wait_process (Process process, bool block, out int? exit_code);

    /**
     * An opaque handle representing a system process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Process]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Compact, CCode (cname = "SDL_Process", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Process {}

    /**
     * Description of where standard I/O should be directed when creating
     * a process.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ProcessIO]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ProcessIO", cprefix = "SDL_PROCESS_", has_type_id = false)]
    public enum ProcessIO {
    /**
     * The I/O stream is inherited from the application.
     *
     */
        STDIO_INHERITED,

        /**
         * The I/O stream is ignored.
         *
         */
        STDIO_NULL,

        /**
         * The I/O stream is connected to a new {@link SDL.IOStream.IOStream}
         * that the application can read or write
         *
         */
        STDIO_APP,

        /**
         * The I/O stream is redirected to an existing
         * {@link SDL.IOStream.IOStream}.
         *
         */
        STDIO_REDIRECT,
    } // ProcessIO

    /**
     * Properties used in {@link create_process_with_properties}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
     */
    namespace PropProcessCreate {
        /**
         * An array of strings containing the program to run, any arguments,
         * and a null pointer, e.g. const char *args[] = { "myprogram",
         * "argument", null }. This is a required property.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_ARGS_POINTER")]
        public const string ARGS_POINTER;

        /**
         * An {@link SDL.StdInc.SDLEnvironment}. If this property is set, it
         * will be the entire environment for the process, otherwise the
         * current environment is used.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_ENVIRONMENT_POINTER")]
        public const string ENVIRONMENT_POINTER;

        /**
         * A UTF-8 encoded string representing the working directory for the
         * process, defaults to the current working directory.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_WORKING_DIRECTORY_STRING")]
        public const string WORKING_DIRECTORY_STRING;

        /**
         * An {@link ProcessIO} value describing where standard input for the
         * process comes from, defaults to {@link ProcessIO.STDIO_NULL}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDIN_NUMBER")]
        public const string STDIN_NUMBER;

        /**
         * An {@link SDL.IOStream.IOStream} pointer used for standard input when
         * {@link STDIN_NUMBER} is set to {@link ProcessIO.STDIO_REDIRECT}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDIN_POINTER")]
        public const string STDIN_POINTER;

        /**
         * An {@link ProcessIO} value describing where standard output for the
         * process comes from, defaults to {@link ProcessIO.STDIO_NULL}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER")]
        public const string STDOUT_NUMBER;

        /**
         * An {@link SDL.IOStream.IOStream} pointer used for standard output when
         * {@link STDIN_NUMBER} is set to {@link ProcessIO.STDIO_REDIRECT}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDOUT_POINTER")]
        public const string STDOUT_POINTER;

        /**
         * An {@link SDL.IOStream.IOStream} pointer used for standard error when
         * {@link STDIN_NUMBER} is set to {@link ProcessIO.STDIO_REDIRECT}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDERR_NUMBER")]
        public const string STDERR_NUMBER;

        /**
         * An {@link SDL.IOStream.IOStream} pointer used for standard error when
         * {@link STDIN_NUMBER} is set to {@link ProcessIO.STDIO_REDIRECT}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDERR_POINTER")]
        public const string STDERR_POINTER;

        /**
         * True if the error output of the process should be redirected into the
         * standard output of the process.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_STDERR_TO_STDOUT_BOOLEAN")]
        public const string STDERR_TO_STDOUT_BOOLEAN;

        /**
         * True if the process should run in the background. In this case the
         * default input and output is {@link ProcessIO.STDIO_NULL} and the exitcode
         * of the process is not available, and will always be 0.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_BACKGROUND_BOOLEAN")]
        public const string BACKGROUND_BOOLEAN;

        /**
         * A string containing the program to run and any parameters. This
         * string is passed directly to CreateProcess on Windows, and does
         * nothing on other platforms.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_CreateProcessWithProperties]]
         *
         * @since 3.4.0
         */
        [Version (since = "3.4.0")]
        [CCode (cname = "SDL_PROP_PROCESS_CREATE_CMDLINE_STRING")]
        public const string CMDLINE_STRING;
    } // PropProcessCreate

    /**
     * Properties used in {@link get_process_properties}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
     */
    namespace PropProcess {
        /**
         * The process ID of the process.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_PID_NUMBER")]
        public const string PID_NUMBER;

        /**
         * An {@link SDL.IOStream.IOStream} that can be used to write input
         * to the process, if it was created with
         * {@link Process.PropProcessCreate.STDIN_NUMBER} set to
         * {@link ProcessIO.STDIO_APP}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_STDIN_POINTER")]
        public const string STDIN_POINTER;

        /**
         * A non-blocking {@link SDL.IOStream.IOStream} that can be used to
         * read output from the process, if it was created with
         * {@link Process.PropProcessCreate.STDOUT_NUMBER} set to
         * {@link ProcessIO.STDIO_APP}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_STDOUT_POINTER")]
        public const string STDOUT_POINTER;

        /**
         * A non-blocking {@link SDL.IOStream.IOStream} that can be used to
         * read error output from the process, if it was created with
         * {@link Process.PropProcessCreate.STDERR_NUMBER} set to
         * {@link ProcessIO.STDIO_APP}.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_STDERR_POINTER")]
        public const string STDERR_POINTER;

        /**
         * True if the process is running in the background.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_GetProcessProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_PROCESS_BACKGROUND_BOOLEAN")]
        public const string BACKGROUND_BOOLEAN;
    } // PropProcess
} // SDL.Process

/**
 * Message Boxes
 *
 * SDL offers a simple message box API, which is useful for simple alerts,
 * such as informing the user when something fatal happens at startup without
 * the need to build a UI for it (or informing the user before your UI is
 * ready).
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryMessagebox]]
 */
[CCode (cheader_filename = "SDL3/SDL_messagebox.h")]
namespace SDL.MessageBox {
    /**
     * Create a modal message box.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowMessageBox]]
     *
     * @param message_box_data the {@link MessageBoxData} structure with
     * title, text and other options.
     * @param button_id the pointer to which user id of hit button should
     * be copied.
     *
     * @since 3.2.0
     *
     * @see show_simple_message_box
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowMessageBox")]
    public static bool show_message_box (MessageBoxData message_box_data, out int button_id);

    /**
     * Display a simple modal message box.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowSimpleMessageBox]]
     *
     * @param flags an {@link MessageBoxFlags} value.
     * @param title UTF-8 title text.
     * @param message UTF-8 message text.
     * @param window the parent window, or null for no parent.
     *
     * @since 3.2.0
     *
     * @see show_message_box
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowSimpleMessageBox")]
    public static bool show_simple_message_box (MessageBoxFlags flags,
            string title,
            string message,
            Video.Window? window);

    /**
     * {@link MessageBoxButtonData} flags.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxButtonFlags]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Flags, CCode (cname = "Uint32", cprefix = "SDL_MESSAGEBOX_BUTTON_", has_type_id = false)]
    public enum MessageBoxButtonFlags {
    /**
     * Marks the default button when return is hit
     *
     */
        RETURNKEY_DEFAULT,

        /**
         * Marks the default button when escape is hit
         *
         */
        ESCAPEKEY_DEFAULT,
    } // MessageBoxButtonFlags

    /**
     * Message box flags.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxFlags]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [Flags, CCode (cname = "Uint32", cprefix = "SDL_MESSAGEBOX_", has_type_id = false)]
    public enum MessageBoxFlags {
    /**
     * Error dialog
     *
     */
        ERROR,

        /**
         * Warning dialog
         *
         */
        WARNING,

        /**
         * Informational dialog
         *
         */
        INFORMATION,

        /**
         * Buttons placed left to right
         *
         */
        BUTTONS_LEFT_TO_RIGHT,

        /**
         * Buttons placed roght to left
         *
         */
        BUTTONS_RIGHT_TO_LEFT,
    } // MessageBoxFlags

    /**
     * Individual button data.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxButtonData]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MessageBoxButtonData", has_type_id = false)]
    public struct MessageBoxButtonData {
    /**
     * Flags of type {@link MessageBoxButtonFlags}
     *
     */
        public MessageBoxButtonFlags flags;

    /**
     * User defined button id (value returned via
     * {@link show_message_box})
     *
     */
        [CCode (cname = "buttonID")]
        public int button_id;

    /**
     * The UTF-8 button text
     *
     */
        public string text;
    } // MessageBoxButtonData;

    /**
     * RGB value used in a message box color scheme
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxColor]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MessageBoxColor", has_type_id = false)]
    public struct MessageBoxColor {
    /**
     * Red component
     *
     */
        public uint8 r;

    /**
     * Green component
     *
     */
        public uint8 g;

    /**
     * Blue component
     *
     */
        public uint8 b;
    } // MessageBoxColor;

    /**
     * A set of colors to use for message box dialogs
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxColorScheme]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MessageBoxColorScheme", has_type_id = false)]
    public struct MessageBoxColorScheme {
    /**
     * An array of Message Box colors.
     * Limited in size by {@link MessageBoxColorType.COLOR_COUNT}
     *
     */
        public MessageBoxColor colors[MessageBoxColorType.COLOR_COUNT];
    } // MessageBoxColorScheme;

    /**
     * MessageBox structure containing title, text, window, etc.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxData]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MessageBoxData", has_type_id = false)]
    public struct MessageBoxData {
    /**
     * Flags of type {@link MessageBoxFlags}
     *
     */
        public MessageBoxFlags flags;

    /**
     * Parent window, can be null
     *
     */
        public Video.Window? window;

    /**
     * UTF-8 title
     *
     */
        public string title;

    /**
     * UTF-8 message text
     *
     */
        public string message;

    /**
     * An array of avaliable buttons in the message box
     *
     */
        [CCode (array_length_cname = "numbuttons", array_length_type = "int")]
        public MessageBoxButtonData buttons;

    /**
     * The message color scheme, can be null to use system settings
     *
     */
        [CCode (cname = "colorScheme")]
        public MessageBoxColorScheme? color_scheme;
    } // MessageBoxData

    /**
     * An enumeration of indices inside the colors array of
     * {@link MessageBoxColorScheme}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_MessageBoxColorType]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_MessageBoxColorType", cprefix = "SDL_MESSAGEBOX_COLOR_",
    has_type_id = false)]
    public enum MessageBoxColorType {
    /**
     * Color of the message box button background
     *
     */
        COLOR_BACKGROUND,

        /**
         * Color of the message box text
         *
         */
        COLOR_TEXT,

        /**
         * Color of a button border
         *
         */
        COLOR_BUTTON_BORDER,

        /**
         * Color when a button is in the background
         *
         */
        COLOR_BUTTON_BACKGROUND,

        /**
         * Color when a button is selected
         *
         */
        COLOR_BUTTON_SELECTED,

        /**
         * Total color count
         *
         */
        COLOR_COUNT,
    } // MessageBoxColorType
} // SDL.MessageBox

/**
 * File Dialogs
 *
 * File dialog support.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryDialog]]
 */
[CCode (cheader_filename = "SDL3/SDL_dialog.h")]
namespace SDL.Dialog {
    /**
     * Create and launch a file dialog with the specified properties.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
     *
     * @param type the type of file dialog.
     * @param callback a function pointer to be invoked when the user selects
     * a file and accepts, or cancels the dialog, or an error occurs.
     * @param props the properties to use.
     *
     * @since 3.2.0
     *
     * @see FileDialogType
     * @see DialogFileCallback
     * @see DialogFileFilter
     * @see show_open_file_dialog
     * @see show_save_file_dialog
     * @see show_open_folder_dialog
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowFileDialogWithProperties", has_target = true, instance_pos = 1.1)]
    public static void show_file_dialog_with_properties (FileDialogType type,
            DialogFileCallback callback,
            SDL.Properties.PropertiesID props);

    /**
     * Displays a dialog that lets the user select a file on their filesystem.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowOpenFileDialog]]
     *
     * @param callback a function pointer to be invoked when the user selects
     * a file and accepts, or cancels the dialog, or an error occurs.
     * @param window the window that the dialog should be modal for, may be
     * null. Not all platforms support this option.
     * @param filters a list of filters, may be null. Not all platforms support
     * this option, and platforms that do support it may allow the user to
     * ignore the filters. If non-null, it must remain valid at least until
     * the callback is invoked.
     * @param default_location the default folder or file to start the dialog
     * at, may be null. Not all platforms support this option.
     * @param allow_many if non-zero, the user will be allowed to select
     * multiple entries. Not all platforms support this option.
     *
     * @since 3.2.0
     *
     * @see DialogFileCallback
     * @see DialogFileFilter
     * @see show_save_file_dialog
     * @see show_open_file_dialog
     * @see show_file_dialog_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowOpenFileDialog")]
    public static void show_open_file_dialog (DialogFileCallback callback,
            Video.Window? window,
            DialogFileFilter[]? filters,
            string default_location,
            bool allow_many);

    /**
     * Displays a dialog that lets the user select a folder on their filesystem.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowOpenFolderDialog]]
     *
     * @param callback a function pointer to be invoked when the user selects
     * a file and accepts, or cancels the dialog, or an error occurs.
     * @param window the window that the dialog should be modal for, may be
     * null. Not all platforms support this option.
     * @param default_location the default folder or file to start the dialog
     * at, may be null. Not all platforms support this option.
     * @param allow_many if non-zero, the user will be allowed to select
     * multiple entries. Not all platforms support this option.
     *
     * @since 3.2.0
     *
     * @see DialogFileCallback
     * @see show_open_file_dialog
     * @see show_save_file_dialog
     * @see show_file_dialog_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowOpenFolderDialog")]
    public static void show_open_folder_dialog (DialogFileCallback callback,
            Video.Window window,
            string default_location,
            bool allow_many);

    /**
     * Displays a dialog that lets the user choose a new or existing file on
     * their filesystem.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowSaveFileDialog]]
     *
     * @param callback a function pointer to be invoked when the user selects
     * a file and accepts, or cancels the dialog, or an error occurs.
     * @param window the window that the dialog should be modal for, may be
     * null. Not all platforms support this option.
     * @param filters a list of filters, may be null. Not all platforms support
     * this option, and platforms that do support it may allow the user to
     * ignore the filters. If non-null, it must remain valid at least until
     * the callback is invoked.
     * @param default_location the default folder or file to start the dialog
     * at, may be null. Not all platforms support this option.
     *
     * @since 3.2.0
     *
     * @see DialogFileCallback
     * @see DialogFileFilter
     * @see show_open_file_dialog
     * @see show_open_folder_dialog
     * @see show_file_dialog_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowSaveFileDialog")]
    public static void show_save_file_dialog (DialogFileCallback callback,
            Video.Window window,
            DialogFileFilter[]? filters,
            string default_location);

    /**
     * Displays a dialog that lets the user select a folder on their filesystem.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DialogFileCallback]]
     *
     * @param filelist the file(s) chosen by the user.
     * @param filter index of the selected filter.
     *
     * @since 3.2.0
     *
     * @see DialogFileFilter
     * @see show_open_file_dialog
     * @see show_save_file_dialog
     * @see show_open_folder_dialog
     * @see show_file_dialog_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DialogFileCallback", has_target = true, instance_pos = 0)]
    public delegate void DialogFileCallback (
            [CCode (array_length = false, array_null_terminated = true)] string[] filelist,
            int filter);

    /**
     * An entry for filters for file dialogs.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_DialogFileFilter]]
     *
     * @since 3.2.0
     *
     * @see DialogFileCallback
     * @see show_open_file_dialog
     * @see show_save_file_dialog
     * @see show_open_folder_dialog
     * @see show_file_dialog_with_properties
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_DialogFileFilter", has_type_id = false)]
    public struct DialogFileFilter {
        public string name;
        public string pattern;
    } // DialogFileFilter

    /**
     * Various types of file dialogs.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_FileDialogType]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_FileDialogType", cprefix = "SDL_FILEDIALOG_", has_type_id = false)]
    public enum FileDialogType {
    /**
     * Open file
     *
     */
        OPENFILE,

        /**
         * Save file
         *
         */
        SAVEFILE,

        /**
         * Open folder
         *
         */
        OPENFOLDER,
    } // FileDialogType

    /**
     * Properties used for {@link show_file_dialog_with_properties}
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
     */
    namespace PropFileDialog {
        /**
         * A pointer to a list of SDL_DialogFileFilter structs, which will
         * be used as filters for file-based selections.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_FILTERS_POINTER")]
        public const string FILTERS_POINTER;

        /**
         * The number of filters in the array of filters, if it exists.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER")]
        public const string NFILTERS_NUMBER;

        /**
         * The window that the dialog should be modal for.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_WINDOW_POINTER")]
        public const string WINDOW_POINTER;

        /**
         * The default folder or file to start the dialog at.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_LOCATION_STRING")]
        public const string LOCATION_STRING;

        /**
         * True to allow the user to select more than one entry.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_MANY_BOOLEAN")]
        public const string MANY_BOOLEAN;

        /**
         * The title for the dialog.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_TITLE_STRING")]
        public const string TITLE_STRING;

        /**
         * The label that the accept button should have.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_ACCEPT_STRING")]
        public const string ACCEPT_STRING;

        /**
         * The label that the cancel button should have.
         *
         *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowFileDialogWithProperties]]
         *
         * @since 3.2.0
         */
        [Version (since = "3.2.0")]
        [CCode (cname = "SDL_PROP_FILE_DIALOG_CANCEL_STRING")]
        public const string CANCEL_STRING;
    } // PropFileDialog
} // SDL.Dialog

///
/// System Tray (SDL_tray.h)
///
[CCode (cheader_filename = "SDL3/SDL_tray.h")]
namespace SDL.Tray {
    [CCode (cname = "SDL_ClickTrayEntry")]
    public static void click_tray_entry (TrayEntry entry);

    [CCode (cname = "SDL_CreateTray")]
    public static Tray create_tray (Surface.Surface icon, string tooltip);

    [CCode (cname = "SDL_CreateTrayMenu")]
    public static TrayMenu create_tray_menu (Tray tray);

    [CCode (cname = "SDL_CreateTraySubmenu")]
    public static TrayMenu create_tray_submenu (TrayEntry entry);

    [CCode (cname = "SDL_DestroyTray")]
    public static void destroy_tray (Tray tray);

    [CCode (cname = "SDL_GetTrayEntries")]
    public static TrayEntry[] get_tray_entries (TrayMenu menu);

    [CCode (cname = "SDL_GetTrayEntryChecked")]
    public static bool get_tray_entry_checked (TrayEntry entry);

    [CCode (cname = "SDL_GetTrayEntryEnabled")]
    public static bool get_tray_entry_enabled (TrayEntry entry);

    [CCode (cname = "SDL_GetTrayEntryLabel")]
    public static unowned string get_tray_entry_label (TrayEntry entry);

    [CCode (cname = "SDL_GetTrayEntryParent")]
    public static TrayMenu * get_tray_entry_parent (TrayEntry entry);

    [CCode (cname = "SDL_GetTrayMenu")]
    public static TrayMenu get_tray_menu (Tray tray);

    [CCode (cname = "SDL_GetTrayMenuParentEntry")]
    public static TrayEntry get_tray_menu_parent_entry (TrayMenu menu);

    [CCode (cname = "SDL_GetTrayMenuParentTray")]
    public static Tray get_tray_menu_parent_tray (TrayMenu menu);

    [CCode (cname = "SDL_GetTraySubmenu")]
    public static TrayMenu get_tray_submenu (TrayEntry entry);

    [CCode (cname = "SDL_InsertTrayEntryAt")]
    public static TrayEntry insert_tray_entry_at (TrayMenu menu, int pos, string label,
            TrayEntryFlags flags);

    [CCode (cname = "SDL_RemoveTrayEntry")]
    public static void remove_tray_entry (TrayEntry entry);

    [CCode (cname = "SDL_SetTrayEntryCallback", has_target = true)]
    public static void set_tray_entry_callback (TrayEntry entry, TrayCallback callback);

    [CCode (cname = "SDL_SetTrayEntryChecked")]
    public static void set_tray_entry_checked (TrayEntry entry, bool checked);

    [CCode (cname = "SDL_SetTrayEntryEnabled")]
    public static void set_tray_entry_enabled (TrayEntry entry, bool enabled);

    [CCode (cname = "SDL_SetTrayEntryLabel")]
    public static void set_entry_label (TrayEntry entry, string label);

    [CCode (cname = "SDL_SetTrayIcon")]
    public static void set_tray_icon (Tray tray, Surface.Surface icon);

    [CCode (cname = "SDL_SetTrayTooltip")]
    public static void set_tray_tooltip (Tray tray, string tooltip);

    [CCode (cname = "SDL_UpdateTrays")]
    public static void update_trays ();

    [Compact, CCode (cname = "SDL_Tray", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Tray {}

    [CCode (cname = "SDL_TrayCallback", has_target = true, instance_pos = 0)]
    public delegate void TrayCallback (TrayEntry entry);

    [Compact, CCode (cname = "SDL_TrayEntry", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class TrayEntry {}

    [Flags, CCode (cname = "Uint32", cprefix = "SDL_TRAYENTRY_", has_type_id = false)]
    public enum TrayEntryFlags {
        BUTTON,
        CHECKBOX,
        SUBMENU,
        DISABLED,
        CHECKED,
    } // SDL_TrayEntryFlags;

    [Compact, CCode (cname = "SDL_TrayMenu", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class TrayMenu {}
} // SDL.Tray

/**
 * Locale Info
 *
 * SDL locale services.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryLocale]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_locale.h")]
namespace SDL.Locale {
    /**
     *  Report the user's preferred locale.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetPreferredLocales]]
     *
     * @return a null terminated array of locale pointers, or null on failure;
     * call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [CCode (cname = "SDL_GetPreferredLocales")]
    public static Locale[]? get_preferred_locales ();

    /**
     * A struct to provide locale data.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Locale]]
     *
     * @since 3.2.0
     *
     * @see get_preferred_locales
     */
    [CCode (cname = "SDL_Locale", free_function = "SDL_free", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Locale {
        /**
         * A language name, like "en" for English.
         *
         */
        public string language;

        /**
         * A country, like "US" for America. Can be null.
         *
         */
        public string ? country;
    } // Locale
} // SDL.Locale

/**
 * Platform-specific Functionality
 *
 * Platform-specific SDL API functions. These are functions that deal with
 * needs of specific operating systems, that didn't make sense to offer as
 * platform-independent, generic APIs.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategorySystem]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_system.h")]
namespace SDL.System {
    /**
     * Retrieve the Java instance of the Android activity class.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidActivity]]
     *
     * @return the jobject representing the instance of the Activity class of
     * the Android application, or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_android_jni_env
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidActivity")]
    public static void * get_android_activity ();

    /**
     * Get the path used for caching data for this Android application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidCachePath]]
     *
     * @return the path used for caches for this application on success or
     * null on failure; call {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_android_external_storage_path
     * @see get_android_internal_storage_path
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidCachePath")]
    public static unowned string get_android_cache_path ();

    /**
     * Get the path used for external storage for this Android application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidExternalStoragePath]]
     *
     * @return the path used for external storage for this application on
     * success or null on failure; call {@link SDL.Error.get_error} for
     * more information.
     *
     * @since 3.2.0
     *
     * @see get_android_external_storage_state
     * @see get_android_internal_storage_path
     * @see get_android_cache_path
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidExternalStoragePath")]
    public static unowned string get_android_external_storage_path ();

    /**
     * Get the current state of external storage for this Android application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidExternalStorageState]]
     *
     * @return the current state of external storage, or 0 if external storage
     * is currently unavailable.
     *
     * @since 3.2.0
     *
     * @see get_android_external_storage_path
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidExternalStorageState")]
    public static uint32 get_android_external_storage_state ();

    /**
     * Get the path used for internal storage for this Android application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidInternalStoragePath]]
     *
     * @return the path used for internal storage for this application on
     * success or null on failure; call {@link SDL.Error.get_error} for
     * more information.
     *
     * @since 3.2.0
     *
     * @see get_android_external_storage_path
     * @see get_android_cache_path
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidExternalStorageState")]
    public static unowned string get_android_internal_storage_path ();

    /**
     * Get the Android Java Native Interface Environment of the current thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidJNIEnv]]
     *
     * @return a pointer to Java native interface object (JNIEnv) to which the
     * current thread is attached, or null on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     *
     * @see get_android_activity
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidJNIEnv")]
    public static void * get_android_jni_env ();

    /**
     * Query Android API level of the current device.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetAndroidSDKVersion]]
     *
     * @return the Android API level.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetAndroidSDKVersion")]
    public static int get_android_sdk_version ();

    /**
     * Get the D3D9 adapter index that matches the specified display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDirect3D9AdapterIndex]]
     *
     * @param display_id the instance of the display to query.
     *
     * @return  the D3D9 adapter index on success or -1 on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDirect3D9AdapterIndex")]
    public static int get_direct3d9_adapter_index (Video.DisplayID display_id);

    /**
     * Get the DXGI Adapter and Output indices for the specified display.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetDXGIOutputInfo]]
     *
     * @param display_id the instance of the display to query.
     * @param adapter_index an out parameter to be filled in with the adapter
     * index.
     * @param output_index an out parameter to be filled in with the output
     * index.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetDXGIOutputInfo")]
    public static bool get_dxgi_output_info (Video.DisplayID display_id, out int adapter_index,
            out int output_index);

    /**
     *  Gets a reference to the default user handle for GDK.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGDKDefaultUser]]
     *
     * @param out_user_handle an out parameter to be filled in with the
     * default user handle.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetGDKDefaultUser")]
    public static bool get_gdk_default_user (void* out_user_handle);

    /**
     * Gets a reference to the global async task queue handle for GDK,
     * initializing if needed.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetGDKTaskQueue]]
     *
     * @param out_task_queue an out parameter to be filled in with the
     * task queue handle.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetGDKTaskQueue")]
    public static bool get_gdk_task_queue (void* out_task_queue);

    /**
     * Get the application sandbox environment, if any.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GetSandbox]]
     *
     * @return the application sandbox environment or {@link Sandbox.NONE}
     * if the application is not running in a sandbox environment.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GetSandbox")]
    public static Sandbox get_sandbox ();

    /**
     * Query if the application is running on a Chromebook.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IsChromebook]]
     *
     * @return true if this is a Chromebook, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_IsChromebook")]
    public static bool is_chromebook ();

    /**
     * Query if the application is running on a Samsung DeX docking station.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IsDeXMode]]
     *
     * @return true if this is a DeX docking station, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_IsDeXMode")]
    public static bool is_dex_mode ();

    /**
     * Query if the current device is a tablet.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IsTablet]]
     *
     * @return true if the device is a tablet, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_IsTablet")]
    public static bool is_tablet ();

    /**
     * Query if the current device is a TV.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_IsTV]]
     *
     * @return true if the device is a TV, false otherwise.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_IsTV")]
    public static bool is_tv ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationDidChangeStatusBarOrientation.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationDidChangeStatusBarOrientation]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationDidChangeStatusBarOrientation")]
    public static void on_application_did_change_status_bar_orientation ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationDidEnterBackground.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationDidEnterBackground]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationDidEnterBackground")]
    public static void on_application_did_enter_background ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationDidBecomeActive.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationDidEnterForeground]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationDidEnterForeground")]
    public static void on_application_did_enter_foreground ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationDidReceiveMemoryWarning.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationDidReceiveMemoryWarning]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationDidReceiveMemoryWarning")]
    public static void on_application_did_receive_memory_warning ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationWillResignActive.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationWillEnterBackground]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationWillEnterBackground")]
    public static void on_application_will_enter_background ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationWillEnterForeground.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationWillEnterForeground]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationWillEnterForeground")]
    public static void on_application_will_enter_foreground ();

    /**
     * Let iOS apps with external event handling report
     * onApplicationWillTerminate.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OnApplicationWillTerminate]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OnApplicationWillTerminate")]
    public static void on_application_will_terminate ();

    /**
     * Request permissions at runtime, asynchronously.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RequestAndroidPermission]]
     *
     * @param permission the permission to request.
     * @param callback the callback to trigger when the request has
     * a response.
     *
     * @return true if the request was submitted, false if there was an error
     * submitting. The result of the request is only ever reported through the
     * callback, not this return value.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RequestAndroidPermission", has_target = true)]
    public static bool request_android_permission (string permission,
            RequestAndroidPermissionCallback callback);

    /**
     * Trigger the Android system back button behavior.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SendAndroidBackButton]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SendAndroidBackButton")]
    public static void send_android_back_button ();

    /**
     * Send a user command to SDLActivity.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SendAndroidMessage]]
     *
     * @param command user command that must be greater or equal to 0x8000.
     * @param param user parameter.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SendAndroidMessage")]
    public static bool send_android_message (uint32 command, int param);

    /**
     * Use this function to set the animation callback on Apple iOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetiOSAnimationCallback]]
     *
     * @param window the window for which the animation callback should
     * be set.
     * @param interval the number of frames after which callback will be
     * called.
     * @param callback the function to call for every frame.
     *
     * @since 3.2.0
     *
     * @see set_ios_event_pump
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetiOSAnimationCallback", has_target = true)]
    public static bool set_ios_animation_callback (Video.Window window, int interval,
            IOSAnimationCallback callback);

    /**
     * Use this function to enable or disable the SDL event pump on Apple iOS.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetiOSEventPump]]
     *
     * @param enabled true to enable the event pump, false to disable it.
     *
     * @since 3.2.0
     *
     * @see set_ios_animation_callback
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetiOSEventPump")]
    public static void set_ios_event_pump (bool enabled);

    /**
     * Sets the UNIX nice value for a thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLinuxThreadPriority]]
     *
     * @param thread_id the Unix thread ID to change priority of.
     * @param priority the new, Unix-specific, priority value.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLinuxThreadPriority")]
    public static bool set_linux_thread_priority (int64 thread_id, int priority);

    /**
     * Sets the priority (not nice level) and scheduling policy for a thread.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetLinuxThreadPriorityAndPolicy]]
     *
     * @param thread_id the Unix thread ID to change priority of.
     * @param sdl_priority the new {@link SDL.Threads.ThreadPriority} value.
     * @param sched_policy the new scheduling policy (SCHED_FIFO, SCHED_RR,
     * SCHED_OTHER, etc...).
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetLinuxThreadPriorityAndPolicy")]
    public static bool set_linux_thread_priority_and_policy (int64 thread_id, int sdl_priority,
            int sched_policy);

    /**
     * Set a callback for every Windows message, run before
     * TranslateMessage().
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowsMessageHook]]
     *
     * @param callback the {@link WindowsMessageHook} function to call.
     *
     * @since 3.2.0
     *
     * @see WindowsMessageHook
     * @see SDL.Hints.WINDOWS_ENABLE_MESSAGE_LOOP
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetWindowsMessageHook", has_target = true)]
    public static void set_windows_message_hook (WindowsMessageHook callback);

    /**
     * Set a callback for every X11 event.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_SetWindowsMessageHook]]
     *
     * @param callback the {@link X11EventHook} function to call.
     *
     * @since 3.2.0
     *
     * @see X11EventHook
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_SetX11EventHook", has_target = true)]
    public static void set_x11_event_hook (X11EventHook callback);

    /**
     * Shows an Android toast notification.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ShowAndroidToast]]
     *
     * @param message text message to be shown.
     * @param duration 0=short, 1=long.
     * @param gravity where the notification should appear on the screen.
     * @param x_offset set this parameter only when gravity >=0.
     * @param y_offset set this parameter only when gravity >=0.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ShowAndroidToast")]
    public static bool show_android_toast (string message, int duration, int gravity, int x_offset,
            int y_offset);

    /**
     * The prototype for an Apple iOS animation callback.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_iOSAnimationCallback]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_iOSAnimationCallback", has_target = true)]
    public delegate void IOSAnimationCallback ();

    /**
     * Callback that presents a response from a
     * {@link request_android_permission} call.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_RequestAndroidPermissionCallback]]
     *
     * @param permission the Android-specific permission name that was
     * requested.
     * @param granted true if permission is granted, false if denied.
     *
     * @since 3.2.0
     *
     * @see request_android_permission
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_RequestAndroidPermissionCallback", has_target = true, instance_pos = 0)]
    public delegate void RequestAndroidPermissionCallback (string permission, bool granted);

    /**
     * A callback to be used with {@link set_windows_message_hook}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_WindowsMessageHook]]
     *
     * @param msg a pointer to a Win32 event structure to process.
     *
     * @since 3.2.0
     *
     * @see set_windows_message_hook
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_WindowsMessageHook", has_target = true, instance_pos = 0)]
    public delegate void WindowsMessageHook (void* msg);

    /**
     * A callback to be used with {@link set_x11_event_hook}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_X11EventHook]]
     *
     * @param x_event a pointer to an Xlib XEvent union to process.
     *
     * @return true to let event continue on, false to drop it.
     *
     * @since 3.2.0
     *
     * @see set_x11_event_hook
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_X11EventHook", has_target = true, instance_pos = 0)]
    public delegate bool X11EventHook (void* x_event);

    /**
     * Application sandbox environment.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_Sandbox]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_Sandbox", cprefix = "SDL_SANDBOX_", has_type_id = false)]
    public enum Sandbox {
    /**
     * No sandbox environment
     *
     */
        NONE,

        /**
         * Unknown sanbox environment
         *
         */
        UNKNOWN_CONTAINER,

        /**
         * Flatpak sandbox environment
         *
         */
        FLATPAK,

        /**
         * Snap sandbox environment
         *
         */
        SNAP,

        /**
         * MacOs sandbox environment
         *
         */
        MACOS,
    } // SDL_Sandbox

    /**
     * See the official Android developer guide for more information:
     * [[http://developer.android.com/guide/topics/data/data-storage.html]]
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ANDROID_EXTERNAL_STORAGE_READ]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ANDROID_EXTERNAL_STORAGE_READ")]
    public const uint8 ANDROID_EXTERNAL_STORAGE_READ;

    /**
     * See the official Android developer guide for more information:
     * [[http://developer.android.com/guide/topics/data/data-storage.html]]
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_ANDROID_EXTERNAL_STORAGE_WRITE]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_ANDROID_EXTERNAL_STORAGE_WRITE")]
    public const uint8 ANDROID_EXTERNAL_STORAGE_WRITE;
} // SDL.System

///
/// Standard Library Functionality (SDL_stdinc.h)
///
[CCode (cheader_filename = "SDL3/SDL_stdinc.h")]
namespace SDL.StdInc {
    [CCode (cname = "SDL_abs")]
    public static int abs (int x);

    [CCode (cname = "SDL_acos")]
    public static double acos (double x);

    [CCode (cname = "SDL_acosf")]
    public static float acosf (float x);

    [CCode (cname = "SDL_aligned_alloc")]
    public static void * aligned_alloc (size_t alignment, size_t size);

    [CCode (cname = "SDL_aligned_free")]
    public static void aligned_free (void* mem);

    [CCode (cname = "SDL_asin")]
    public static double asin (double x);

    [CCode (cname = "SDL_asinf")]
    public static float asinf (float x);

    [PrintfFormat]
    [CCode (cname = "SDL_asprintf", sentinel = "")]
    public static int asprintf (out string strp, string format, ...);

    [CCode (cname = "SDL_atan")]
    public static double atan (double x);

    [CCode (cname = "SDL_atan2")]
    public static double atan2 (double y, double x);

    [CCode (cname = "SDL_atan2f")]
    public static float atan2f (float y, float x);

    [CCode (cname = "SDL_atanf")]
    public static float atanf (float x);

    [CCode (cname = "SDL_atof")]
    public static double atof (string str);

    [CCode (cname = "SDL_atoi")]
    public static int atoi (string str);

    [CCode (cname = "SDL_bsearch")]
    public static void * bsearch (void* key, void* search_base, size_t nmemb, size_t size,
            CompareCallback compare);

    [CCode (cname = "SDL_bsearch_r", has_target = true)]
    public static void * bsearch_r (void* key, void* search_base, size_t nmemb, size_t size,
            CompareCallbackR compare);

    [CCode (cname = "SDL_calloc")]
    public static void * calloc (size_t nmemb, size_t size);

    [CCode (cname = "SDL_ceil")]
    public static double ceil (double x);

    [CCode (cname = "SDL_ceil")]
    public static float ceilf (float x);

    [CCode (cname = "SDL_copysign")]
    public static double copysign (double x, double y);

    [CCode (cname = "SDL_copysignf")]
    public static float copysignf (float x, float y);

    [CCode (cname = "SDL_cos")]
    public static double cos (double x);

    [CCode (cname = "SDL_cosf")]
    public static float cosf (float x);

    [CCode (cname = "SDL_crc16")]
    public static uint16 crc16 (uint16 crc, void* data, size_t len);

    [CCode (cname = "SDL_crc32")]
    public static uint32 crc32 (uint32 crc, void* data, size_t len);

    [CCode (cname = "SDL_CreateEnvironment")]
    public static SDLEnvironment create_environment (bool populated);

    [CCode (cname = "SDL_DestroyEnvironment")]
    public static void destroy_environment (SDLEnvironment env);

    [CCode (cname = "SDL_exp")]
    public static double exp (double x);

    [CCode (cname = "SDL_expf")]
    public static float expf (float x);

    [CCode (cname = "SDL_fabs")]
    public static double fabs (double x);

    [CCode (cname = "SDL_fabsf")]
    public static float fabsf (float x);

    [CCode (cname = "SDL_floor")]
    public static double floor (double x);

    [CCode (cname = "SDL_floorf")]
    public static float floorf (float x);

    [CCode (cname = "SDL_fmod")]
    public static double fmod (double x, double y);

    [CCode (cname = "SDL_fmodf")]
    public static float fmodf (float x, float y);

    [CCode (cname = "SDL_free")]
    public static void free (void* mem);

    [CCode (cname = "SDL_getenv")]
    public static unowned string getenv (string name);

    [CCode (cname = "SDL_getenv_unsafe")]
    public static unowned string getenv_unsafe (string name);

    [CCode (cname = "SDL_GetEnvironment")]
    public static SDLEnvironment get_environment ();

    [CCode (cname = "SDL_GetEnvironmentVariable")]
    public static unowned string get_environment_variable (SDLEnvironment env, string name);

    [CCode (cname = "SDL_GetEnvironmentVariables", array_null_terminated = true)]
    public static unowned string[] ? get_environment_variables (SDLEnvironment env);

    [CCode (cname = "SDL_GetMemoryFunctions")]
    public static void get_memory_functions (MallocFunc malloc_func,
            CallocFunc calloc_func,
            ReallocFunc realloc_func,
            FreeFunc free_func);

    [CCode (cname = "SDL_GetNumAllocations")]
    public static int get_num_allocations ();

    [CCode (cname = "SDL_GetOriginalMemoryFunctions")]
    public static void get_original_memory_functions (MallocFunc malloc_func,
            CallocFunc calloc_func,
            ReallocFunc realloc_func,
            FreeFunc free_func);

    [CCode (cname = "SDL_iconv")]
    public static size_t iconv (Iconv cd,
            string in_buffer,
            size_t in_bytes_left,
            out string out_buffer,
            out size_t out_bytes_left);

    [CCode (cname = "int", cprefix = "SDL_ICONV_")]
    public enum IconvError {
        ERROR,
        E2BIG,
        EILSEQ,
        EINVAL,
    } // IconvError

    [CCode (cname = "SDL_iconv_close")]
    public static int iconv_close (Iconv cd);

    [CCode (cname = "SDL_iconv_open")]
    public static Iconv iconv_open (string tocode, string fromcode);

    [CCode (cname = "SDL_iconv_string")]
    public static unowned string iconv_string (string tocode,
            string from_code,
            string in_buffer,
            size_t in_bytes_left);

    [CCode (cname = "SDL_isalnum")]
    public static int is_a_lnum (int x);

    [CCode (cname = "SDL_isalpha")]
    public static int is_alpha (int x);

    [CCode (cname = "SDL_isblank")]
    public static int is_blank (int x);

    [CCode (cname = "SDL_iscntrl")]
    public static int is_cntrl (int x);

    [CCode (cname = "SDL_isdigit")]
    public static int is_digit (int x);

    [CCode (cname = "SDL_isgraph")]
    public static int is_graph (int x);

    [CCode (cname = "SDL_isinf")]
    public static int is_inf (double x);

    [CCode (cname = "SDL_isinff")]
    public static int is_inff (float x);

    [CCode (cname = "SDL_islower")]
    public static int is_lower (int x);

    [CCode (cname = "SDL_isnan")]
    public static int is_nan (double x);

    [CCode (cname = "SDL_isnanf")]
    public static int is_nanf (float x);

    [CCode (cname = "SDL_isprint")]
    public static int is_print (int x);

    [CCode (cname = "SDL_ispunct")]
    public static int is_punct (int x);

    [CCode (cname = "SDL_isspace")]
    public static int is_space (int x);

    [CCode (cname = "SDL_isupper")]
    public static int is_upper (int x);

    [CCode (cname = "SDL_isxdigit")]
    public static int is_x_digit (int x);

    [CCode (cname = "SDL_itoa")]
    public static unowned string itoa (int value, ref string str, int radix);

    [CCode (cname = "SDL_lltoa")]
    public static unowned string lltoa (long value, string str, int radix);

    [CCode (cname = "SDL_log")]
    public static double log (double x);

    [CCode (cname = "SDL_log10")]
    public static double log10 (double x);

    [CCode (cname = "SDL_log10f")]
    public static float log10f (float x);

    [CCode (cname = "SDL_logf")]
    public static float logf (double x);

    [CCode (cname = "SDL_lround")]
    public static long lround (double x);

    [CCode (cname = "SDL_lroundf")]
    public static long lroundf (float x);

    [CCode (cname = "SDL_ltoa")]
    public static unowned string ltoa (long value, string str, int radix);

    [CCode (cname = "SDL_malloc")]
    public static void * malloc (size_t size);

    [CCode (cname = "SDL_memcmp")]
    public static int memcpm (void* s1, void* s2, size_t len);

    [CCode (cname = "SDL_memcpy")]
    public static void * memcpy (void* dst, void* src, size_t len);

    [CCode (cname = "SDL_memmove")]
    public static void * memmove (void* dst, void* src, size_t len);

    [CCode (cname = "SDL_memset")]
    public static void * memset (void* dst, int c, size_t len);

    [CCode (cname = "SDL_memset4")]
    public static void * memset4 (void* dst, uint32 val, size_t dwords);

    [CCode (cname = "SDL_modf")]
    public static float modf (double x, out double y);

    [CCode (cname = "SDL_modff")]
    public static float modff (float x, out float y);

    [CCode (cname = "SDL_murmur3_32")]
    public static uint32 murmur3_32 (void* data, size_t len, uint32 seed);

    [CCode (cname = "SDL_pow")]
    public static double pow (double x, double y);

    [CCode (cname = "SDL_powf")]
    public static float powf (float x, float y);

    [CCode (cname = "SDL_qsort")]
    public static void qsort (void* array_base, size_t nmemb, size_t size, CompareCallback compare);

    [CCode (cname = "SDL_qsort_r", has_target = true)]
    public static void qsort_r (void* array_base, size_t nmemb, size_t size,
            CompareCallbackR compare);

    [CCode (cname = "SDL_rand")]
    public static int32 rand (int32 n);

    [CCode (cname = "SDL_rand_bits")]
    public static uint32 rand_bits ();

    [CCode (cname = "SDL_rand_bits_r")]
    public static uint32 rand_bits_r (uint64 state);

    [CCode (cname = "SDL_rand_r")]
    public static int32 rand_r (uint64 state, int32 n);

    [CCode (cname = "SDL_randf")]
    public static float randf ();

    [CCode (cname = "SDL_randf_r")]
    public static float randf_r (uint64 state);

    [CCode (cname = "SDL_realloc")]
    public static void * realloc (void* mem, size_t size);

    [CCode (cname = "SDL_round")]
    public static double round (double x);

    [CCode (cname = "SDL_roundf")]
    public static float roundf (float x);

    [CCode (cname = "SDL_scalbn")]
    public static double scalbn (double x, int n);

    [CCode (cname = "SDL_scalbnf")]
    public static float scalbnf (float x, int n);

    [CCode (cname = "SDL_setenv_unsafe")]
    public static int setenv_unsafe (string name, string value, int overwrite);

    [CCode (cname = "SDL_SetEnvironmentVariable")]
    public static bool set_environment_variable (SDLEnvironment env, string name, string value,
            bool overwrite);

    [CCode (cname = "SDL_SetMemoryFunctions")]
    public static bool det_memoery_functions (MallocFunc malloc_func,
            CallocFunc calloc_func,
            ReallocFunc realloc_func,
            FreeFunc free_func);

    [CCode (cname = "SDL_sin")]
    public static double sin (double x);

    [CCode (cname = "SDL_sinf")]
    public static float sinf (float x);

    [CCode (cname = "SDL_size_add_check_overflow")]
    public static bool size_add_check_overflow (size_t a, size_t b, out size_t ret);

    [CCode (cname = "SDL_size_mul_check_overflow")]
    public static bool size_mul_check_overflow (size_t a, size_t b, out size_t ret);

    [PrintfFormat]
    [CCode (cname = "SDL_snprintf", sentinel = "")]
    public static int snprintf (string text, size_t maxlen, string format, ...);

    [CCode (cname = "SDL_sqrt")]
    public static double sqrt (double x);

    [CCode (cname = "SDL_sqrtf")]
    public static float sqrtf (float x);

    [CCode (cname = "SDL_srand")]
    public static void srand (uint64 seed);

    [ScanfFormat]
    [CCode (cname = "SDL_sscanf", sentinel = "")]
    public static int sscanf (string text, string format, ...);

    [CCode (cname = "SDL_StepBackUTF8")]
    public static uint32 step_back_utf8 (string start, ref string pstr);

    [CCode (cname = "SDL_StepUTF8")]
    public static uint32 step_utf8 (ref string pstr, size_t pslen);

    [CCode (cname = "SDL_strcasecmp")]
    public static int str_case_cmp (string str1, string str2);

    [CCode (cname = "SDL_strcasestr")]
    public static char ? str_case_str (string haystack, string needle);

    [CCode (cname = "SDL_strchr")]
    public static char ? str_chr (string str, int c);

    [CCode (cname = "SDL_strcmp")]
    public static int str_cmp (string str1, string str2);

    [CCode (cname = "SDL_strdup")]
    public static unowned string str_dup (string str);

    [CCode (cname = "SDL_strlcat")]
    public static size_t str_lcat (ref string dst, string src, size_t maxlen);

    [CCode (cname = "SDL_strlcpy")]
    public static size_t str_lcpy (ref string dst, string src, size_t maxlen);

    [CCode (cname = "SDL_strlen")]
    public static size_t str_len (string str);

    [CCode (cname = "SDL_strlwr")]
    public static unowned string str_lwr (string str);

    [CCode (cname = "SDL_strncasecmp")]
    public static int strn_casecmp (string str1, string str2, size_t maxlen);

    [CCode (cname = "SDL_strncmp")]
    public static int strn_cmp (string str1, string str2, size_t maxlen);

    [CCode (cname = "SDL_strndup")]
    public static unowned string strn_dup (string str, size_t maxlen);

    [CCode (cname = "SDL_strnlen")]
    public static size_t strn_len (string str, size_t maxlen);

    [CCode (cname = "SDL_strnstr")]
    public static char ? strn_str (string haystack, string needle, size_t maxlen);

    [CCode (cname = "SDL_strpbrk")]
    public static char ? str_pbrk (string str, string breakset);

    [CCode (cname = "SDL_strrchr")]
    public static char ? str_rchr (string str, int c);

    [CCode (cname = "SDL_strrev")]
    public static unowned string str_rev (string str);

    [CCode (cname = "SDL_strstr")]
    public static unowned string str_str (string haystack, string needle);

    [CCode (cname = "SDL_strtod")]
    public static double str_tod (string str, out string endp);

    [CCode (cname = "SDL_strtok_r")]
    public static unowned string str_tok_r (string str, string delim, ref string saveptr);

    [CCode (cname = "SDL_strtol")]
    public static long str_tol (string str, ref string? endp, int n_base);

    [CCode (cname = "SDL_strtoll")]
    public static long str_toll (string str, ref string? endp, int n_base);

    [CCode (cname = "SDL_strtoul")]
    public static ulong str_toul (string str, ref string? endp, int n_base);

    [CCode (cname = "SDL_strtoull")]
    public static ulong str_toull (string str, ref string? endp, int n_base);

    [CCode (cname = "SDL_strupr")]
    public static unowned string str_upr (string str);

    [PrintfFormat]
    [CCode (cname = "SDL_swprintf", sentinel = "")]
    public static int swprintf (string text, size_t maxlen, string format, ...);

    [CCode (cname = "SDL_tan")]
    public static double tan (double x);

    [CCode (cname = "SDL_tanf")]
    public static float tanf (float x);

    [CCode (cname = "SDL_tolower")]
    public static char tolower (char x);

    [CCode (cname = "SDL_toupper")]
    public static char toupper (char x);

    [CCode (cname = "SDL_trunc")]
    public static double trunc (double x);

    [CCode (cname = "SDL_truncf")]
    public static float truncf (float x);

    [CCode (cname = "SDL_UCS4ToUTF8")]
    public static unowned string ucs4_to_utf8 (uint32 codepoint, out string dst);

    [CCode (cname = "SDL_uitoa")]
    public static char uitoa (uint value, out char str, int radix);

    [CCode (cname = "SDL_ulltoa")]
    public static char ulltoa (ulong value, out char str, int radix);

    [CCode (cname = "SDL_ultoa")]
    public static char ultoa (ulong value, out char str, int radix);

    [CCode (cname = "SDL_unsetenv_unsafe")]
    public static int unsetenv_unsafe (string name);

    [CCode (cname = "SDL_UnsetEnvironmentVariable")]
    public static bool unset_environment_variable (SDLEnvironment env, string name);

    [CCode (cname = "SDL_utf8strlcpy")]
    public static size_t utf8_str_lcpy (out string dst, string src, size_t dst_bytes);

    [CCode (cname = "SDL_utf8strlen")]
    public static size_t utf8_str_len (string str);

    [CCode (cname = "SDL_utf8strnlen")]
    public static size_t utf8_strn_len (string str, size_t bytes);

    [CCode (cname = "SDL_vasprintf")]
    public static int vasprintf (out string strp, string format, va_list ap);

    [CCode (cname = "SDL_vsnprintf")]
    public static int vsnprintf (out string text, size_t maxlen, string format, va_list ap);

    [CCode (cname = "SDL_vsscanf")]
    public static int vsscanf (out string text, string format, va_list ap);

    [CCode (cname = "SDL_vswprintf")]
    public static int vswprintf (out string text, size_t maxlen, string format, va_list ap);

    [CCode (cname = "SDL_wcscasecmp")]
    public static int wcscasecmp (string str1, string str2);

    [CCode (cname = "SDL_wcscmp")]
    public static int wcscmp (string str1, string str2);

    [CCode (cname = "SDL_wcsdup")]
    public static unowned string wcsdup (string wstr);

    [CCode (cname = "SDL_wcslcat")]
    public static size_t wcslcat (out string dst, string src, size_t maxlen);

    [CCode (cname = "SDL_wcslcpy")]
    public static size_t wcslcpy (out string dst, string src, size_t maxlen);

    [CCode (cname = "SDL_wcslen")]
    public static size_t wcslen (string wstr);

    [CCode (cname = "SDL_wcsncasecmp")]
    public static int wcsncasecmp (string str1, string str2, size_t maxlen);

    [CCode (cname = "SDL_wcsncmp")]
    public static int wcsncmp (string str1, string str2, size_t maxlen);

    [CCode (cname = "SDL_wcsnlen")]
    public static size_t wcsnlen (string wstr, size_t maxlen);

    [CCode (cname = "SDL_wcsnstr")]
    public static unowned string wcsnstr (string haystack, string needle, size_t maxlen);

    [CCode (cname = "SDL_wcsstr")]
    public static unowned string wcsstr (string haystack, string needle);

    [CCode (cname = "SDL_wcstol")]
    public static long wcstol (string str, string? endp, int n_base);

    [CCode (cname = "SDL_calloc_func", has_target = false)]
    public delegate void * CallocFunc (size_t nmemb, size_t size);

    [CCode (cname = "SDL_CompareCallback", has_target = false)]
    public delegate int CompareCallback (void* a, void* b);

    [CCode (cname = "SDL_CompareCallback", has_target = true, instance_pos = 0)]
    public delegate int CompareCallbackR (void* a, void* b);

    [Compact, CCode (cname = "SDL_Environment", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class SDLEnvironment {}

    [CCode (cname = "SDL_free_func", has_target = false)]
    public delegate void FreeFunc (void* mem);

    [CCode (cname = "SDL_FunctionPointer", has_target = false)]
    public delegate void FunctionPointer ();

    [Compact, CCode (cname = "SDL_iconv_t", free_function = "", ref_function = "",
    unref_function = "", has_type_id = false)]
    public class Iconv {}

    [CCode (cname = "SDL_malloc_func", has_target = false)]
    public delegate void * MallocFunc (size_t size);

    [CCode (cname = "SDL_realloc_func", has_target = false)]
    public delegate void * ReallocFunc (void* mem, size_t size);

    [SimpleType, CCode (cname = "SDL_Time", has_type_id = false)]
    public struct Time : int64 {}

    [CCode (cname = "SDL_MAX_TIME")]
    public const int64 MAX_TIME;

    [CCode (cname = "SDL_MIN_TIME")]
    public const int64 MIN_TIME;

    [SimpleType, CCode (cname = "Sint16", has_type_id = false)]
    public struct Sint16 : int16 {}

    [CCode (cname = "SDL_MAX_SINT16")]
    public const int16 MAX_SINT16;

    [CCode (cname = "SDL_MIN_SINT16")]
    public const int16 MIN_SINT16;

    [SimpleType, CCode (cname = "Sint32", has_type_id = false)]
    public struct Sint32 : int32 {}

    [CCode (cname = "SDL_MAX_SINT32")]
    public const int32 MAX_SINT32;

    [CCode (cname = "SDL_MIN_SINT32")]
    public const int32 MIN_SINT32;

    [SimpleType, CCode (cname = "Sint64", has_type_id = false)]
    public struct Sint64 : int64 {}

    [CCode (cname = "SDL_MAX_SINT64")]
    public const int64 MAX_SINT64;

    [CCode (cname = "SDL_MIN_SINT64")]
    public const int64 MIN_SINT64;

    [SimpleType, CCode (cname = "Sint8", has_type_id = false)]
    public struct Sint8 : int8 {}

    [CCode (cname = "SDL_MAX_SINT8")]
    public const int8 MAX_SINT8;

    [CCode (cname = "SDL_MIN_SINT8")]
    public const int8 MIN_SINT8;

    [SimpleType, CCode (cname = "Uint16", has_type_id = false)]
    public struct Uint16 : uint16 {}

    [CCode (cname = "SDL_MAX_UINT16")]
    public const uint16 MAX_UINT16;

    [CCode (cname = "SDL_MIN_UINT16")]
    public const uint16 MIN_UINT16;

    [SimpleType, CCode (cname = "Uint32", has_type_id = false)]
    public struct Uint32 : uint32 {}

    [CCode (cname = "SDL_MAX_UINT32")]
    public const uint32 MAX_UINT32;

    [CCode (cname = "SDL_MIN_UINT32")]
    public const uint32 MIN_UINT32;

    [SimpleType, CCode (cname = "Uint64", has_type_id = false)]
    public struct Uint64 : uint64 {}

    [CCode (cname = "SDL_MAX_UINT64")]
    public const uint64 MAX_UINT64;

    [CCode (cname = "SDL_MIN_UINT64")]
    public const uint64 MIN_UINT64;

    [SimpleType, CCode (cname = "Uint8", has_type_id = false)]
    public struct Uint8 : uint8 {}

    [CCode (cname = "SDL_MAX_UINT8")]
    public const uint8 MAX_UINT8;

    [CCode (cname = "SDL_MIN_UINT8")]
    public const uint8 MIN_UINT8;

#if GOBJECT
    [CCode (cname = "SDL_clamp")]
public static unichar clamp_unichar (unichar x, unichar a, unichar b);
#endif

    [CCode (cname = "SDL_clamp")]
    public static int clamp_int (int x, int a, int b);

    [CCode (cname = "SDL_clamp")]
    public static char clamp_char (char x, char a, char b);

    [CCode (cname = "SDL_clamp")]
    public static short clamp_short (short x, short a, short b);

    [CCode (cname = "SDL_clamp")]
    public static long clamp_long (long x, long a, long b);

    [CCode (cname = "SDL_clamp")]
    public static int8 clamp_int8 (int8 x, int8 a, int8 b);

    [CCode (cname = "SDL_clamp")]
    public static int16 clamp_int16 (int16 x, int16 a, int16 b);

    [CCode (cname = "SDL_clamp")]
    public static int32 clamp_int32 (int32 x, int32 a, int32 b);

    [CCode (cname = "SDL_clamp")]
    public static int64 clamp_int64 (int64 x, int64 a, int64 b);

    [CCode (cname = "SDL_clamp")]
    public static uint clamp_uint (uint x, uint a, uint b);

    [CCode (cname = "SDL_clamp")]
    public static uchar clamp_uchar (uchar x, uchar a, uchar b);

    [CCode (cname = "SDL_clamp")]
    public static ushort clamp_ushort (ushort x, ushort a, ushort b);

    [CCode (cname = "SDL_clamp")]
    public static ulong clamp_ulong (ulong x, ulong a, ulong b);

    [CCode (cname = "SDL_clamp")]
    public static uint8 clamp_uint8 (uint8 x, uint8 a, uint8 b);

    [CCode (cname = "SDL_clamp")]
    public static uint16 clamp_uint16 (uint16 x, uint16 a, uint16 b);

    [CCode (cname = "SDL_clamp")]
    public static uint32 clamp_uint32 (uint32 x, uint32 a, uint32 b);

    [CCode (cname = "SDL_clamp")]
    public static uint64 clamp_uint64 (uint64 x, uint64 a, uint64 b);

    [CCode (cname = "SDL_clamp")]
    public static float clamp_float (float x, float a, float b);

    [CCode (cname = "SDL_clamp")]
    public static double clamp_double (double x, double a, double b);

    [CCode (cname = "SDL_FLT_EPSILON")]
    public const float FLT_EPSILON;

    [CCode (cname = "SDL_FOURCC")]
    public static uint32 fourcc (char a, char b, char c, char d);

    [CCode (cname = "SDL_INIT_INTERFACE", simple_generics = true)]
    public static T init_interface<T> (out T iface);

    [CCode (cname = "SDL_iconv_utf8_locale")]
    public static unowned string ? iconv_utf8_locale (string s);

    [CCode (cname = "SDL_iconv_utf8_ucs2")]
    public static unowned string ? iconv_utf8_ucs2 (string s);

    [CCode (cname = "SDL_iconv_utf8_ucs4")]
    public static unowned string ? iconv_utf8_ucs4 (string s);

    [CCode (cname = "SDL_iconv_wchar_utf8")]
    public static unowned string ? iconv_wchar_utf8 (string s);

    [CCode (cname = "SDL_INVALID_UNICODE_CODEPOINT")]
    public const uint32 INVALID_UNICODE_CODEPOINT;

#if GOBJECT
    [CCode (cname = "SDL_max")]
public static unichar max_unichar (unichar x, unichar y);
#endif

    [CCode (cname = "SDL_max")]
    public static int max_int (int x, int y);

    [CCode (cname = "SDL_max")]
    public static char max_char (char x, char y);

    [CCode (cname = "SDL_max")]
    public static short max_short (short x, short y);

    [CCode (cname = "SDL_max")]
    public static long max_long (long x, long y);

    [CCode (cname = "SDL_max")]
    public static int8 max_int8 (int8 x, int8 y);

    [CCode (cname = "SDL_max")]
    public static int16 max_int16 (int16 x, int16 y);

    [CCode (cname = "SDL_max")]
    public static int32 max_int32 (int32 x, int32 y);

    [CCode (cname = "SDL_max")]
    public static int64 max_int64 (int64 x, int64 y);

    [CCode (cname = "SDL_max")]
    public static uint max_uint (uint x, uint y);

    [CCode (cname = "SDL_max")]
    public static uchar max_uchar (uchar x, uchar y);

    [CCode (cname = "SDL_max")]
    public static ushort max_ushort (ushort x, ushort y);

    [CCode (cname = "SDL_max")]
    public static ulong max_ulong (ulong x, ulong y);

    [CCode (cname = "SDL_max")]
    public static uint8 max_uint8 (uint8 x, uint8 y);

    [CCode (cname = "SDL_max")]
    public static uint16 max_uint16 (uint16 x, uint16 y);

    [CCode (cname = "SDL_max")]
    public static uint32 max_uint32 (uint32 x, uint32 y);

    [CCode (cname = "SDL_max")]
    public static uint64 max_uint64 (uint64 x, uint64 y);

    [CCode (cname = "SDL_max")]
    public static float max_float (float x, float y);

    [CCode (cname = "SDL_max")]
    public static double max_double (double x, double y);

    [CCode (cname = "SDL_min")]
    public static int min_int (int x, int y);

    [CCode (cname = "SDL_min")]
    public static char min_char (char x, char y);

    [CCode (cname = "SDL_min")]
    public static short min_short (short x, short y);

    [CCode (cname = "SDL_min")]
    public static long min_long (long x, long y);

    [CCode (cname = "SDL_min")]
    public static int8 min_int8 (int8 x, int8 y);

    [CCode (cname = "SDL_min")]
    public static int16 min_int16 (int16 x, int16 y);

    [CCode (cname = "SDL_min")]
    public static int32 min_int32 (int32 x, int32 y);

    [CCode (cname = "SDL_min")]
    public static int64 min_int64 (int64 x, int64 y);

    [CCode (cname = "SDL_min")]
    public static int min_uint (uint x, uint y);

    [CCode (cname = "SDL_min")]
    public static char min_uchar (uchar x, uchar y);

    [CCode (cname = "SDL_min")]
    public static short min_ushort (ushort x, ushort y);

    [CCode (cname = "SDL_min")]
    public static long min_ulong (ulong x, ulong y);

    [CCode (cname = "SDL_min")]
    public static uint8 min_uint8 (uint8 x, uint8 y);

    [CCode (cname = "SDL_min")]
    public static uint16 min_uint16 (uint16 x, uint16 y);

    [CCode (cname = "SDL_min")]
    public static uint32 min_uint32 (uint32 x, uint32 y);

    [CCode (cname = "SDL_min")]
    public static uint64 min_uint64 (uint64 x, uint64 y);

    [CCode (cname = "SDL_min")]
    public static float min_float (float x, float y);

    [CCode (cname = "SDL_min")]
    public static double min_double (double x, double y);

    [CCode (cname = "SDL_PI_D")]
    public const double PI_D;

    [CCode (cname = "SDL_PI_F")]
    public const float PI_F;

    [CCode (cname = "SDL_PRILL_PREFIX")]
    public const string PRILL_PREFIX;

    [CCode (cname = "SDL_PRILLd")]
    public const string PRILLd; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRILLu")]
    public const string PRILLu; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRILLX")]
    public const string PRILLX;

    [CCode (cname = "SDL_PRILLx")]
    public const string PRILLx; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIs32")]
    public const string PRIs32; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIs64")]
    public const string PRIs64; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIu32")]
    public const string PRIu32; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIu64")]
    public const string PRIu64; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIX32")]
    public const string PRIX32;

    [CCode (cname = "SDL_PRIx32")]
    public const string PRIx32; // vala-lint=naming-convention

    [CCode (cname = "SDL_PRIX64")]
    public const string PRIX64;

    [CCode (cname = "SDL_PRIx64")]
    public const string PRIx64; // vala-lint=naming-convention

    [CCode (cname = "SDL_SIZE_MAX")]
    public const size_t SIZE_MAX;
} // SDL.StdInc

/**
 * GUIDs
 *
 * A GUID is a 128-bit value that represents something that is uniquely
 * identifiable by this value: "globally unique." SDL provides functions
 * to convert a GUID to/from a string.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryGUID]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_guid.h")]
namespace SDL.Guid {
    /**
     * Get an ASCII string representation for a given {@link Guid}.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GUIDToString]]
     *
     * @param guid the {@link Guid} you wish to convert to string.
     * @param psz_guid buffer in which to write the ASCII string.
     * @param cb_guid the size of psz_guid, should be at least 33 bytes.
     *
     * @since 3.2.0
     *
     * @see string_to_guid
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_GUIDToString")]
    public static void guid_to_string (Guid guid,
            [CCode (array_length = false)] out string psz_guid,
            int cb_guid);

    /**
     * Convert a GUID string into a {@link Guid} structure.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_StringToGUID]]
     *
     * @param pch_guid string containing an ASCII representation of a GUID.
     *
     * @return a {@link Guid} structure.
     *
     * @since 3.2.0
     *
     * @see guid_to_string
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_StringToGUID")]
    public static Guid string_to_guid (string pch_guid);

    /**
     * An {@link Guid} is a 128-bit identifier for an input device that
     * identifies that device across runs of SDL programs on the same platform.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_GUID]]
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [SimpleType, CCode (cname = "SDL_GUID", has_type_id = false)]
    public struct Guid {
        public uint8 data[16];
    } // Guid
} // SDL.Guid

/**
 * Miscellaneous
 *
 * SDL API functions that don't fit elsewhere.
 *
 *  * [[https://wiki.libsdl.org/SDL3/CategoryMisc]]
 *
 */
[CCode (cheader_filename = "SDL3/SDL_misc.h")]
namespace SDL.Misc {
    /**
     * Open a URL/URI in the browser or other appropriate external application.
     *
     *  * [[https://wiki.libsdl.org/SDL3/SDL_OpenURL]]
     *
     * @param url a valid URL/URI to open. Use the file protocol
     * for local files, if supported.
     *
     * @return true on success or false on failure; call
     * {@link SDL.Error.get_error} for more information.
     *
     * @since 3.2.0
     */
    [Version (since = "3.2.0")]
    [CCode (cname = "SDL_OpenURL")]
    public static bool open_url (string url);
} // SDL.Misc
