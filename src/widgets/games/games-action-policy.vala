namespace ProtonPlus.Widgets.Games {
    public enum GameRowActivation {
        MODIFY,
        TOGGLE_SELECTION
    }

    public enum GameCollectionBoundaryAction {
        NONE,
        FOCUS_TOOLBAR,
        FOCUS_FIRST_GAME
    }

    public enum GameFocusLane {
        SELECTION,
        ROW,
        FIRST_ACTION,
        PRIMARY_ACTION,
        SECONDARY_ACTION
    }

    public enum GameAntiCheatState {
        LOADING,
        SUPPORTED,
        RUNNING,
        PLANNED,
        BROKEN,
        DENIED,
        UNKNOWN
    }

    public class GameActionAvailability : Object {
        public bool native_game { get; private set; }
        public bool show_launch { get; private set; }
        public bool show_custom_executable { get; private set; }
        public bool enable_custom_executable { get; private set; }
        public bool show_install_directory { get; private set; }
        public bool show_prefix_directory { get; private set; }
        public bool show_protontricks { get; private set; }
        public bool show_protondb { get; private set; }
        public bool show_anticheat { get; private set; }
        public bool enable_anticheat { get; private set; }
        public GameAntiCheatState anticheat_state { get; private set; }

        public bool has_secondary_actions {
            get {
                return show_custom_executable || show_install_directory ||
                    show_prefix_directory || show_protontricks || show_protondb ||
                    show_anticheat;
            }
        }

        public static GameActionAvailability evaluate (bool is_steam,
            bool is_non_steam, bool is_native, bool has_install_directory,
            bool has_prefix_directory, bool protontricks_available,
            string? anticheat_status, bool has_anticheat_page) {
            var result = new GameActionAvailability ();
            result.native_game = is_native;
            result.show_launch = is_steam;
            result.show_custom_executable = is_steam;
            result.enable_custom_executable = is_steam && has_prefix_directory;
            result.show_install_directory = has_install_directory;
            result.show_prefix_directory = has_prefix_directory;
            result.show_protontricks = is_steam && !is_non_steam &&
                protontricks_available;
            result.show_protondb = is_steam && !is_non_steam;
            result.show_anticheat = is_steam && !is_non_steam;
            result.anticheat_state = parse_anticheat_state (anticheat_status);
            result.enable_anticheat = result.show_anticheat &&
                has_anticheat_page && is_known_anticheat_state (
                    result.anticheat_state
                );
            return result;
        }

        public static GameRowActivation row_activation (bool selection_mode) {
            return selection_mode
                ? GameRowActivation.TOGGLE_SELECTION
                : GameRowActivation.MODIFY;
        }

        static GameAntiCheatState parse_anticheat_state (string? status) {
            switch (status) {
            case null:
                return GameAntiCheatState.LOADING;
            case "Supported":
                return GameAntiCheatState.SUPPORTED;
            case "Running":
                return GameAntiCheatState.RUNNING;
            case "Planned":
                return GameAntiCheatState.PLANNED;
            case "Broken":
                return GameAntiCheatState.BROKEN;
            case "Denied":
                return GameAntiCheatState.DENIED;
            default:
                return GameAntiCheatState.UNKNOWN;
            }
        }

        static bool is_known_anticheat_state (GameAntiCheatState state) {
            return state != GameAntiCheatState.LOADING &&
                state != GameAntiCheatState.UNKNOWN;
        }
    }

    public class GameControllerNavigationPolicy : Object {
        public static bool top_boundary_uses_selection (GameFocusLane lane) {
            return lane == GameFocusLane.SELECTION;
        }

        public static GameFocusLane action_lane (bool secondary_action) {
            return secondary_action
                ? GameFocusLane.SECONDARY_ACTION
                : GameFocusLane.PRIMARY_ACTION;
        }

        public static bool can_attempt_action_focus (
            bool mapped, bool visible, bool sensitive) {
            return mapped && visible && sensitive;
        }

        public static GameCollectionBoundaryAction boundary_action (
            bool focused_in_toolbar, bool focused_in_collection,
            Utils.ControllerNavigationDirection direction) {
            if (focused_in_toolbar &&
                direction == Utils.ControllerNavigationDirection.DOWN)
                return GameCollectionBoundaryAction.FOCUS_FIRST_GAME;

            if (!focused_in_collection)
                return GameCollectionBoundaryAction.NONE;

            if (direction == Utils.ControllerNavigationDirection.UP)
                return GameCollectionBoundaryAction.FOCUS_TOOLBAR;
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return GameCollectionBoundaryAction.FOCUS_FIRST_GAME;
            return GameCollectionBoundaryAction.NONE;
        }
    }

    public class GameActionTarget : Object {
        public GameListItem? item { get; private set; }
        public uint64 generation { get; private set; default = 0; }

        public void bind (GameListItem item) {
            generation++;
            this.item = item;
        }

        public void unbind () {
            generation++;
            item = null;
        }
    }
}
