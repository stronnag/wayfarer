namespace Utils {
	public string get_encopts(ScreenCap.Options o) {
		StringBuilder sb = new StringBuilder();
		switch(o.mediatype) {
		case "mp4":
			if ((o.vaapis & 2) == 2 ) {
				sb.append("vaapih264enc max-qp=17 ! h264parse");
			} else {
				sb.append_printf("x264enc qp-max=17 speed-preset=superfast threads=%u ! video/x-h264, profile=baseline", o.nproc);
			}
			break;
		case "mkv":
		case "webm":
			if ((o.vaapis & 1) == 1) {
				sb.append("vaapivp8enc");
			} else {
				sb.append_printf("vp8enc min_quantizer=10 max_quantizer=13 cpu-used=5 deadline=1000000 threads=%u",  (1+o.nproc/2));
			}
			break;
		default:
			print("Error: No encoder %s\n", o.mediatype.to_string());
			break;
		}
		sb.append(" ! queue");
		switch(o.mediatype) {
		case "mkv":
			sb.append(" ! matroskamux name=mux");
			break;
		case "mp4":
			sb.append(" ! mp4mux name=mux");
			break;
		case "webm":
			sb.append(" ! webmmux name=mux");
			break;
		}
		sb.append(" name=mux");
		return sb.str;
	}

	public int get_even(int v) {
		return (v&= ~1);
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

	public static bool is_vorbis(string filename) {
		try {
			var file = File.new_for_path (filename);
			var file_info = file.query_info ("*", FileQueryInfoFlags.NONE);
			var fi = file_info.get_content_type();
			stderr.printf("Type %s\n", fi);
			return ((file_info.get_size() > 0) && ((fi == "audio/x-vorbis+ogg") ||
												   (fi == "audio/x-opus+ogg")));
		} catch {
			return false;
		}
	}

	public static bool file_exists( string fn) {
		File file = File.new_for_path (fn);
		return  file.query_exists ();
	}
}
