namespace ProtonPlus.Widgets.Tools {
    public enum InlineExpansionTransition {
        NONE,
        EXPAND,
        COLLAPSE,
        SWITCH
    }

    public enum InlineReleaseRequestKind {
        INITIAL,
        REFRESH,
        LOAD_MORE
    }

    public enum InlineReleaseView {
        LOADING,
        LIST,
        EMPTY,
        ERROR
    }

    public enum InlineReleaseEmptyReason {
        CATALOG,
        FILTER,
        UNAVAILABLE
    }

    public class InlineReleasePresentation : Object {
        public InlineReleaseView view { get; private set; }
        public bool show_error_banner { get; private set; }

        public static InlineReleasePresentation evaluate (
            InlineReleaseRequestKind kind,
            bool request_in_progress,
            bool has_content,
            bool failed,
            bool filtered_empty = false
        ) {
            var result = new InlineReleasePresentation ();
            if (request_in_progress) {
                result.view = kind == InlineReleaseRequestKind.INITIAL || !has_content
                    ? InlineReleaseView.LOADING
                    : filtered_empty
                        ? InlineReleaseView.EMPTY
                        : InlineReleaseView.LIST;
                return result;
            }
            if (failed) {
                result.show_error_banner = kind != InlineReleaseRequestKind.INITIAL &&
                    has_content;
                result.view = result.show_error_banner
                    ? filtered_empty
                        ? InlineReleaseView.EMPTY
                        : InlineReleaseView.LIST
                    : InlineReleaseView.ERROR;
                return result;
            }
            result.view = has_content
                ? InlineReleaseView.LIST
                : InlineReleaseView.EMPTY;
            return result;
        }

        public static InlineReleaseEmptyReason empty_reason (
            Filter filter, bool compatible
        ) {
            if (filter != Filter.ALL)
                return InlineReleaseEmptyReason.FILTER;
            if (!compatible)
                return InlineReleaseEmptyReason.UNAVAILABLE;
            return InlineReleaseEmptyReason.CATALOG;
        }
    }

    public class InlineReleaseInteractionState : Object {
        Object? owner;
        Object? navigation_owner;
        Object? navigation_item;
        double scroll_position = 0.0;

        public Object? expanded_owner {
            get { return owner; }
        }

        public InlineExpansionTransition expand (Object new_owner) {
            if (owner == new_owner)
                return InlineExpansionTransition.NONE;

            var transition = owner == null
                ? InlineExpansionTransition.EXPAND
                : InlineExpansionTransition.SWITCH;
            owner = new_owner;
            return transition;
        }

        public InlineExpansionTransition collapse (Object collapsed_owner) {
            if (owner != collapsed_owner)
                return InlineExpansionTransition.NONE;
            owner = null;
            return InlineExpansionTransition.COLLAPSE;
        }

        public bool is_expanded (Object candidate) {
            return owner == candidate;
        }

        public void remember_navigation (
            Object current_owner, Object selected_item, double position
        ) {
            navigation_owner = current_owner;
            navigation_item = selected_item;
            scroll_position = position;
        }

        public bool restore_navigation (
            Object current_owner, Object selected_item, out double position
        ) {
            position = scroll_position;
            return navigation_owner == current_owner && navigation_item == selected_item;
        }

        public void clear_navigation (Object cleared_owner) {
            if (navigation_owner != cleared_owner)
                return;
            navigation_owner = null;
            navigation_item = null;
            scroll_position = 0.0;
        }
    }

    public class InlineReleaseRequestGuard : Object {
        Object? owner;
        public uint generation { get; private set; default = 0; }

        public uint select (Object selected_owner) {
            owner = selected_owner;
            generation++;
            return generation;
        }

        public void clear () {
            owner = null;
            generation++;
        }

        public bool is_current (Object selected_owner, uint request_generation) {
            return owner == selected_owner && generation == request_generation;
        }
    }
}
