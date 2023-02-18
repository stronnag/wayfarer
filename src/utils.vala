namespace Utils {
	public void get_even(ref int v, bool up = false) {
        if (up)
            v++;
        v&= ~1;
	}

	public static bool exists_on_path(string s) {
		int n;
		n = Posix.access(s, Posix.X_OK|Posix.R_OK);
		if (n != 0) {
			var ep = Environment.get_variable("PATH");
			if (ep != null) {
				var parts = ep.split(":");
				foreach(var p in parts) {
					string pp = Path.build_filename(p, s);
					n = Posix.access(pp, Posix.X_OK|Posix.R_OK);
					if (n == 0)
							break;
				}
			}
		}
			return (n == 0);
	}

	public static bool file_exists( string fn) {
		File file = File.new_for_path (fn);
		return  file.query_exists ();
	}
}
