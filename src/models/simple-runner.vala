namespace ProtonPlus.Models {
	public class SimpleRunner : Object {
		public string display_title { get; set; }
		public string internal_title { get; set; }

		public SimpleRunner (string display_title, string internal_title) {
			this.display_title = display_title;
			this.internal_title = internal_title;
		}

		public SimpleRunner.from_path (string path) throws Error {
			var content = Utils.Filesystem.get_file_content ("%s/compatibilitytool.vdf".printf (path));
			var start_text = "";
			var end_text = "";
			var start_pos = 0;
			var end_pos = 0;

			start_text = "display_name\" \"";
			start_pos = content.index_of (start_text, 0) + start_text.length;
			if (start_pos == -1)
				throw new Error(Quark.from_string ("simple-runner"), 0, "Error parsing the file");

			end_text = "\"";
			end_pos = content.index_of (end_text, start_pos);
			if (end_pos == -1)
				throw new Error(Quark.from_string ("simple-runner"), 0, "Error parsing the file");

			display_title = content.substring (start_pos, end_pos - start_pos);

			start_text = "compat_tools\"";
			start_pos = content.index_of (start_text, 0) + start_text.length;
			if (start_pos == -1)
				throw new Error(Quark.from_string ("simple-runner"), 0, "Error parsing the file");
			
			start_text = "\"";
			start_pos = content.index_of (start_text, start_pos) + start_text.length;
			if (start_pos == -1)
				throw new Error(Quark.from_string ("simple-runner"), 0, "Error parsing the file");

			end_text = "\" // Internal name of this tool";
			end_pos = content.index_of (end_text, start_pos);
			if (end_pos == -1)
				throw new Error(Quark.from_string ("simple-runner"), 0, "Error parsing the file");
			
			internal_title = content.substring (start_pos, end_pos - start_pos);
		}
	}
}
