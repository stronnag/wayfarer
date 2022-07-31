using Gtk;

public class AreaWindow : Gtk.Window {
	private int spx=-1;
	private int spy=-1;
	private int ax;
	private int ay;
	private bool dorect;
	private Gdk.RGBA fill;
	private Gdk.RGBA stroke;
	public signal void area_set(int x0, int y0, int x1, int y1);
	public signal void area_quit();


	public AreaWindow() {

		fill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha= 0.2f};
		stroke = Gdk.RGBA(){red = 0.0f, green = 0.2f, blue = 0.8f, alpha = 0.8f};

		set_cursor_from_name("crosshair");
		remove_css_class("background");

		var evtc = new EventControllerKey ();
		evtc.set_propagation_phase(PropagationPhase.CAPTURE);
		((Gtk.Widget)this).add_controller(evtc);

		evtc.key_pressed.connect((kv, kc, mfy) => {
				var ec = Gdk.keyval_from_name("Escape");
				if (kv == ec) {
					area_quit();
				}
				return false;
			});

		var gestd = new GestureDrag();
		gestd.set_exclusive(true);
		((Gtk.Widget)this).add_controller(gestd);

		gestd.drag_begin.connect((x,y) => {
				spx = (int)x;
				spy = (int)y;
				draw_area(false);
			});

		gestd.drag_end.connect((x,y) => {
				int ex = spx + (int)x;
				int ey = spy + (int)y;
				draw_area(false);
				area_set(spx, spy, ex, ey);
			});

		gestd.drag_update.connect((x,y) => {
				ax = spx + (int)x;
				ay = spy + (int)y;
				draw_area(true);
			});
	}

	public void run(int monitor) {
		if (monitor == -1) {
			fullscreen();
		} else {
//			fullscreen_on_monitor(Gdk.Screen.get_default(), monitor);
			fullscreen();
		}
		present();
	}

	private void draw_area(bool flag) {
		dorect = flag;
		queue_draw();
	}

	public override void snapshot (Gtk.Snapshot snap) {
		if (dorect) {
			var rect = Graphene.Rect.alloc();
			float[] lwidths = {2,2,2,2};
			Gdk.RGBA[] lcols = {stroke, stroke, stroke, stroke};
			var rrect = Gsk.RoundedRect(){};
			rect.init(spx, spy, ax-spx, ay-spy);
			rrect.init_from_rect(rect, 0.0f);
			snap.append_color(fill, rect);
			snap.append_border(rrect, lwidths, lcols);
		} else {
			var rect = Graphene.Rect.zero();
			snap.append_color(fill, rect);
		}
	}
}

#if TEST
// valac -D TEST  --pkg gtk4 --pkg cairo  sel4.vala
class SelTest : Gtk.Application {
	uint32 tid = 0;
	public SelTest() {
        Object(application_id: "org.stronnag.seltest",
               flags: ApplicationFlags.FLAGS_NONE);
    }

    public override void activate () {
        base.startup();
		var window = new Gtk.ApplicationWindow(this);
		add_window (window);
		var button = new Gtk.Button.with_label("SelTest");
		button.clicked.connect(() => {
				var sw = new AreaWindow (0);
				sw.area_set.connect((x0, y0, x1, y1) => {
						if(tid != 0) {
							Source.remove(tid);
							tid = 0;
						}
						stderr.printf("area: %d %d %d %d\n", x0, y0, x1, y1);
						sw.destroy();
					});
				sw.area_quit.connect(() => {
						if(tid != 0) {
							Source.remove(tid);
							tid = 0;
						}
						print("ESC\n");
						sw.destroy();
					});
				Timeout.add_seconds(60, () => {
						quit();
						return false;
					});
			});
		window.child = button;
		window.present();
	}
}

int main (string[] args) {
    Gtk.init ();
	var app = new SelTest();
	app.run();
	return 0;
}
#endif
