namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class AudioOptionsGroup : BaseOptionsGroup {

        LaunchOptionSpinTile pulse_latency_tile { get; private set; }

        public AudioOptionsGroup (owned SimpleCallback standard_control_changed, Gee.List<ILaunchOption> launch_option_handlers) {
            base((owned) standard_control_changed, launch_option_handlers, true);

            this.title = _ ("Audio options");
            this.description = _ ("Audio-related launch options.");

            pulse_latency_tile = create_spin_tile  (
                _ ("PulseAudio low latency"), 
                _ ("Enables low latency mode in PulseAudio which can reduce audio latency in some games (60, 90, 120)."), 
                _ ("MSEC"), 
                30, 360, 
                90,
                 "PULSE_LATENCY_MSEC="
            );

            this.add (pulse_latency_tile);
        }
    }
}
