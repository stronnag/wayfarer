//
// valac --pkg libportal ptest.vala
//

public class PortalManager : Object {
	public struct SourceInfo {
		int width;
		int height;
		int x;
		int y;
		uint32 source_type;
		uint32 node_id;
	}

	public signal void complete(int fd);
	public signal void source_info(SourceInfo si);

	private Xdp.Portal p;
	private string token;

	public PortalManager(string? t) {
        token = t;
		p = new Xdp.Portal();
	}

	public void invalidate() {
        token = null;
	}

	public string get_token() {
        return token;
    }

	public void set_token(string _t) {
        token = _t;
    }

	public void run (bool want_mouse) {
		p.create_screencast_session.begin(
			Xdp.OutputType.MONITOR,
			Xdp.ScreencastFlags.MULTIPLE,
			(want_mouse) ? Xdp.CursorMode.EMBEDDED : Xdp.CursorMode.HIDDEN,
			Xdp.PersistMode.PERSISTENT, token, null, (obj, res) => {
				try {
					var session = p.create_screencast_session.end(res);
					session.start.begin(null, null, (obj,res) => {
							try {
								GLib.Variant? val = null;
								var ok = session.start.end(res);
								if (ok) {
									token = session.get_restore_token ();
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
														val2.get_child (0, "i", &si.x);
														val2.get_child (1, "i", &si.y);
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
                                    print("portal complete\n");
									complete(-3);
								}
							} catch (Error e) {
								print("portal %s\n", e.message);
								complete(-2);
						}
					});
				} catch (Error e) {
					print("portal session: %s\n", e.message);
					complete(-1);
				}
			});
	}
}
