//
// valac --pkg libportal ptest.vala
//

public class PortalManager : Object {
	public struct SourceInfo {
		int width;
		int height;
		int xpos;
		int ypos;
		uint32 source_type;
		uint32 node_id;
	}

	public signal void complete(int fd);
	public signal void source_info(SourceInfo si);

	private Xdp.Portal p;
	private string persist = null;

	public PortalManager() {
		p = new Xdp.Portal();
	}

	public void invalidate() {
		persist = null;
	}

	public void run (bool want_mouse) {
		p.create_screencast_session.begin(
			Xdp.OutputType.MONITOR, // |Xdp.OutputType.WINDOW, // FIXME
			Xdp.ScreencastFlags.MULTIPLE, // FIXME
			(want_mouse) ? Xdp.CursorMode.EMBEDDED : Xdp.CursorMode.HIDDEN,
			Xdp.PersistMode.PERSISTENT, persist, null, (obj, res) => {
				try {
					var session = p.create_screencast_session.end(res);
					session.start.begin(null, null, (obj,res) => {
							try {
								GLib.Variant? val = null;
								var ok = session.start.end(res);
								if (ok) {
									persist = session.get_restore_token ();
									var streams = session.get_streams();
									var iter = streams.iterator();
									while ((val = iter.next_value()) != null) {
										var viter = val.iterator();
										GLib.Variant? val1 = null;
										int j = 0;
										SourceInfo si = {0};
										while ((val1 = viter.next_value()) != null) {
											if (j == 0) {
												si.node_id = val1.get_uint32();
											} else 	{
												var v1iter = val1.iterator();
												GLib.Variant? val2 = null;
												string? key = null;
												while (v1iter.next ("{sv}", out key, out val2)) {
													switch (key) {
													case "id":
//														si.id = val2.get_string (null);
														break;
													case "source_type":
														si.source_type = val2.get_uint32();
														break;
													case "size":
														val2.get_child (0, "i", &si.width);
														val2.get_child (1, "i", &si.height);
														break;
													case "position":
														val2.get_child (0, "i", &si.xpos);
														val2.get_child (1, "i", &si.ypos);
														break;
													}
												}
											}
											j++;
										}
										source_info(si);
									}
									int fd = session.open_pipewire_remote();
									complete(fd);
								} else {
									complete(-1);
								}
							} catch (Error e) {
								print("start error %s\n", e.message);
								complete(-1);
						}
					});
				} catch (Error e) {
					print("start error %s\n", e.message);
					complete(-1);
				}
			});
	}
}

#if TEST
	public static int main(string? [] args) {
		var loop = new MainLoop();
		var pw = new PortalManager();
		pw.complete.connect((fd) => {
				if (fd == -1) {
					loop.quit();
				}
				print("Got fd = %d\n", fd);
			});
		pw.source_info.connect((s) => {
				print("si = %u %d %d %d %d %u\n", s.node_id, s.width, s.height,s.xpos,s.ypos,s.source_type);
			});

		Timeout.add(5, () => {
				pw.run();
				return false;
			});
		loop.run();
		return 0;
	}
#endif
