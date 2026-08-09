namespace ProtonPlus.Models.Providers {
    internal class BuiltInProviderDefinitions : Object {
        internal static ProviderDefinition[] create_all () {
            var definitions = new Gee.ArrayList<ProviderDefinition> ();
            append (definitions, DxvkDefinitions.create ());
            append (definitions, Vkd3dDefinitions.create ());
            append (definitions, ProtonDefinitions.create ());
            append (definitions, WineDefinitions.create ());
            return copy_definitions (definitions);
        }

        private static void append (Gee.ArrayList<ProviderDefinition> target, ProviderDefinition[] values) {
            foreach (var value in values)
                target.add (value);
        }

        private static ProviderDefinition[] copy_definitions (Gee.Collection<ProviderDefinition> values) {
            var copied = new ProviderDefinition[values.size];
            var index = 0;
            foreach (var value in values)
                copied[index++] = value;
            return copied;
        }
    }
}
