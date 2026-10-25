namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Forks : Base {
        public Forks () {
            base (
                _("Choosing a Community Build"),
                _("Community builds such as GE-Proton offer additional fixes and game-specific changes. Try one when a game needs it; a newer or different build is not always better for every game."), // vala-lint=line-length
                "%s/fork.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}
