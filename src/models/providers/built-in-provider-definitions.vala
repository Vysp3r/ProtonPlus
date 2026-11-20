namespace ProtonPlus.Models.Providers {
    internal class BuiltInProviderDefinitions : Object {
        internal static ProviderDefinition[] create_all () {
            var definitions = new Gee.ArrayList<ProviderDefinition> ();
            definitions.add_all_array (DxvkDefinitions.create ());
            definitions.add_all_array (Vkd3dDefinitions.create ());
            definitions.add_all_array (ProtonDefinitions.create ());
            definitions.add_all_array (WineDefinitions.create ());
            return definitions.to_array ();
        }
    }
}
