namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public enum LaunchOptionEligibilityKind {
        AVAILABLE,
        VARIANT_SELECTABLE_WITH_WARNING,
        UNAVAILABLE_RUNTIME,
        UNAVAILABLE_COMPONENT,
        UNAVAILABLE_HARDWARE,
        UNSUPPORTED,
        LEGACY_ACTIVE_ONLY,
        UNKNOWN_CONTEXT
    }

    /* Presentation eligibility is deliberately local to launch options.  It
     * describes what the editor may offer; the composer remains the final
     * validation boundary for command construction. */
    public class LaunchOptionEligibility : Object {
        public LaunchOptionEligibilityKind kind { get; construct; }
        public bool may_activate { get; construct; }
        public bool may_modify { get; construct; }
        public bool show_when_inactive { get; construct; }
        public bool keep_visible_when_active { get; construct; }
        public string reason { get; construct; }

        public LaunchOptionEligibility (
            LaunchOptionEligibilityKind kind, bool may_activate, bool may_modify,
            bool show_when_inactive, bool keep_visible_when_active, string reason = ""
        ) {
            Object (kind: kind, may_activate: may_activate, may_modify: may_modify,
                show_when_inactive: show_when_inactive,
                keep_visible_when_active: keep_visible_when_active, reason: reason);
        }
    }

    public class LaunchOptionInstalledComponents : Object {
        public bool mangohud { get; construct; }
        public bool gamemode { get; construct; }
        public bool gamescope { get; construct; }
        public bool scopebuddy { get; construct; }
        public bool vkbasalt { get; construct; }

        public LaunchOptionInstalledComponents (
            bool mangohud = false, bool gamemode = false, bool gamescope = false,
            bool scopebuddy = false, bool vkbasalt = false
        ) {
            Object (mangohud: mangohud, gamemode: gamemode, gamescope: gamescope,
                scopebuddy: scopebuddy, vkbasalt: vkbasalt);
        }
    }

    public class LaunchOptionCapabilityResolver : Object {
        LaunchOptionCatalog catalog;

        public LaunchOptionCapabilityResolver (LaunchOptionCatalog? catalog = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
        }

        public LaunchCommandCapabilityContext resolve (
            Models.CompatibilityToolRuntimeKind[] runtimes, bool all_steam,
            LaunchOptionInstalledComponents components, Utils.GpuVendor gpu_vendor
        ) {
            LaunchOptionCapability[] values = {};
            if (all_steam)
                values = append_capability (values, LaunchOptionCapability.STEAM);

            var all_native = runtimes.length > 0;
            var all_proton = runtimes.length > 0;
            foreach (var runtime in runtimes) {
                all_native = all_native && runtime == Models.CompatibilityToolRuntimeKind.NATIVE;
                all_proton = all_proton && runtime == Models.CompatibilityToolRuntimeKind.PROTON;
            }
            if (all_native)
                values = append_capability (values, LaunchOptionCapability.NATIVE_LINUX);
            if (all_proton) {
                values = append_capability (values, LaunchOptionCapability.PROTON);
                /* These are standard, confirmed Proton-bundled facilities,
                 * not claims about a named custom variant. */
                values = append_capability (values, LaunchOptionCapability.DXVK);
                values = append_capability (values, LaunchOptionCapability.VKD3D_PROTON);
            }

            if (components.mangohud) values = append_capability (values, LaunchOptionCapability.MANGOHUD);
            if (components.gamemode) values = append_capability (values, LaunchOptionCapability.GAMEMODE);
            if (components.gamescope) values = append_capability (values, LaunchOptionCapability.GAMESCOPE);
            if (components.scopebuddy) values = append_capability (values, LaunchOptionCapability.SCOPEBUDDY);
            if (components.vkbasalt) values = append_capability (values, LaunchOptionCapability.VKBASALT);
            switch (gpu_vendor) {
                case Utils.GpuVendor.AMD: values = append_capability (values, LaunchOptionCapability.AMD); break;
                case Utils.GpuVendor.NVIDIA: values = append_capability (values, LaunchOptionCapability.NVIDIA); break;
                case Utils.GpuVendor.INTEL: values = append_capability (values, LaunchOptionCapability.INTEL); break;
                default: break;
            }
            return new LaunchCommandCapabilityContext (values);
        }

        public Models.CompatibilityToolRuntimeKind runtime_for_tool (Models.CompatibilityTool? tool) {
            if (tool == null)
                return Models.CompatibilityToolRuntimeKind.UNKNOWN;
            if (tool.runtime_kind != Models.CompatibilityToolRuntimeKind.UNKNOWN)
                return tool.runtime_kind;
            if (tool.internal_title == "Default")
                return Models.CompatibilityToolRuntimeKind.PROTON;
            if (Models.Launchers.Steam.is_steam_linux_runtime (tool.display_title, tool.internal_title))
                return Models.CompatibilityToolRuntimeKind.NATIVE;
            return Models.CompatibilityToolRuntimeKind.UNKNOWN;
        }

        public LaunchOptionEligibility evaluate (
            LaunchOptionMetadata metadata, LaunchCommandCapabilityContext? context, bool active = false
        ) {
            var semantics = metadata.semantics;
            if (semantics == null || semantics.support == LaunchOptionSupport.UNSUPPORTED
                || semantics.support == LaunchOptionSupport.UNKNOWN_UNVERIFIED) {
                return unavailable (LaunchOptionEligibilityKind.UNSUPPORTED, active,
                    _("This option is unsupported and cannot be newly enabled."));
            }
            if (semantics.support == LaunchOptionSupport.LEGACY_DEPRECATED
                || !semantics.managed_emission
                || semantics.kind == LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT
                || semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY) {
                return unavailable (LaunchOptionEligibilityKind.LEGACY_ACTIVE_ONLY, active,
                    _("This legacy option is preserved but cannot be newly enabled."));
            }
            if (context == null)
                return unavailable (LaunchOptionEligibilityKind.UNKNOWN_CONTEXT, active,
                    _("Compatibility-tool capabilities are not known yet."));

            foreach (var capability in required_capabilities (metadata)) {
                if (!context.has (capability))
                    return unavailable (kind_for (capability), active, reason_for (capability));
            }
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR) {
                var has_available_wrapper = false;
                foreach (var id in semantics.selectable_wrapper_ids) {
                    var wrapper = catalog.lookup_wrapper (id);
                    if (wrapper != null && context.has (wrapper.required_capability)) {
                        has_available_wrapper = true;
                        break;
                    }
                }
                if (!has_available_wrapper)
                    return unavailable (LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT, active,
                        _("Requires an available launch backend."));
            }
            if (semantics.support == LaunchOptionSupport.VARIANT_SPECIFIC) {
                /* Confirming Proton establishes that managed emission is safe,
                 * but deliberately does not claim support by a named variant. */
                return new LaunchOptionEligibility (
                    LaunchOptionEligibilityKind.VARIANT_SELECTABLE_WITH_WARNING,
                    true, true, true, true,
                    _("Requires a compatible Proton variant.")
                );
            }
            return new LaunchOptionEligibility (LaunchOptionEligibilityKind.AVAILABLE,
                true, true, true, true);
        }

        public LaunchOptionEligibility evaluate_selection (
            LaunchOptionMetadata metadata, LaunchCommandSelection selection,
            LaunchCommandCapabilityContext? context, bool active = false
        ) {
            var eligibility = evaluate (metadata, context, active);
            if (!eligibility.may_activate || selection.wrapper_id == "")
                return eligibility;
            var wrapper = catalog.lookup_wrapper (selection.wrapper_id);
            if (wrapper == null)
                return unavailable (LaunchOptionEligibilityKind.UNSUPPORTED, active,
                    _("The selected launch backend is not supported."));
            if (context == null || !context.has (wrapper.required_capability))
                return unavailable (kind_for (wrapper.required_capability), active,
                    reason_for (wrapper.required_capability));
            return eligibility;
        }

        LaunchOptionEligibility unavailable (LaunchOptionEligibilityKind kind, bool active, string reason) {
            return new LaunchOptionEligibility (kind, false, false, false, active, reason);
        }

        LaunchOptionCapability[] required_capabilities (LaunchOptionMetadata metadata) {
            LaunchOptionCapability[] values = {};
            var semantics = metadata.semantics;
            if (semantics == null)
                return values;
            foreach (var capability in semantics.get_required_capabilities ())
                if (!contains_capability (values, capability))
                    values = append_capability (values, capability);
            if (semantics.wrapper_id != "") {
                var wrapper = catalog.lookup_wrapper (semantics.wrapper_id);
                if (wrapper != null && !contains_capability (values, wrapper.required_capability))
                    values = append_capability (values, wrapper.required_capability);
            }
            return values;
        }

        LaunchOptionCapability[] append_capability (
            LaunchOptionCapability[] values, LaunchOptionCapability capability
        ) {
            var expanded = new LaunchOptionCapability[values.length + 1];
            for (var index = 0; index < values.length; index++)
                expanded[index] = values[index];
            expanded[values.length] = capability;
            return expanded;
        }

        bool contains_capability (LaunchOptionCapability[] values, LaunchOptionCapability capability) {
            foreach (var value in values)
                if (value == capability) return true;
            return false;
        }

        LaunchOptionEligibilityKind kind_for (LaunchOptionCapability capability) {
            switch (capability) {
                case LaunchOptionCapability.AMD:
                case LaunchOptionCapability.NVIDIA:
                case LaunchOptionCapability.INTEL:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_HARDWARE;
                case LaunchOptionCapability.MANGOHUD:
                case LaunchOptionCapability.GAMEMODE:
                case LaunchOptionCapability.GAMESCOPE:
                case LaunchOptionCapability.SCOPEBUDDY:
                case LaunchOptionCapability.VKBASALT:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT;
                case LaunchOptionCapability.PROTON:
                case LaunchOptionCapability.DXVK:
                case LaunchOptionCapability.VKD3D_PROTON:
                case LaunchOptionCapability.NATIVE_LINUX:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME;
                default:
                    return LaunchOptionEligibilityKind.UNKNOWN_CONTEXT;
            }
        }

        string reason_for (LaunchOptionCapability capability) {
            switch (capability) {
                case LaunchOptionCapability.AMD: return _("Requires an AMD GPU.");
                case LaunchOptionCapability.NVIDIA: return _("Requires an NVIDIA GPU.");
                case LaunchOptionCapability.INTEL: return _("Requires an Intel GPU.");
                case LaunchOptionCapability.MANGOHUD: return _("Requires MangoHud, which is not available.");
                case LaunchOptionCapability.GAMEMODE: return _("Requires GameMode, which is not available.");
                case LaunchOptionCapability.GAMESCOPE: return _("Requires Gamescope, which is not available.");
                case LaunchOptionCapability.SCOPEBUDDY: return _("Requires ScopeBuddy, which is not available.");
                case LaunchOptionCapability.VKBASALT: return _("Requires vkBasalt, which is not available.");
                case LaunchOptionCapability.DXVK: return _("Requires DXVK from the selected compatibility tool.");
                case LaunchOptionCapability.VKD3D_PROTON: return _("Requires VKD3D-Proton from the selected compatibility tool.");
                case LaunchOptionCapability.NATIVE_LINUX: return _("Not supported by the selected compatibility tool.");
                default: return _("Not supported by the selected compatibility tool.");
            }
        }
    }
}
