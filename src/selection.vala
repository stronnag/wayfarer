using Gtk;

public class AreaWindow : Gtk.Window {
    private const  int BLOB_RADIUS=20;
    private const  int LINE_RELAX=4;
    private const float LINE_WIDTH=2.0f;

    private enum DrawMode {
        NONE,
        RECT,
    }

    private enum DragMode {
        NONE,
        NE,
        SE,
        SW,
        NW,
        N,
        E,
        S,
        W,
        GRAB,
        FREE,
    }

    private struct CursorforMode {
        DragMode mode;
        string name;
    }

    static CursorforMode []cursor_modes = {
        {DragMode.N, "n-resize"},
        {DragMode.E, "e-resize"},
        {DragMode.S, "s-resize"},
        {DragMode.W, "w-resize"},
        {DragMode.NE, "ne-resize"},
        {DragMode.SE, "se-resize"},
        {DragMode.SW, "sw-resize"},
        {DragMode.NW, "nw-resize"},
        {DragMode.GRAB, "move"},
        {DragMode.FREE, "crosshair"}
    };

    private int startx=-1;
    private int starty=-1;
    private int spx=-1;
    private int spy=-1;
    private int endx;
    private int endy;
    private int absx;
    private int absy;

	private Gdk.RGBA fill;
	private Gdk.RGBA stroke;
	private Gdk.RGBA bfill;
	public signal void area_set(int x0, int y0, int x1, int y1);
	public signal void area_quit();

    bool ingrab = false;
    private DrawMode drawmode;
    private DragMode dragmode;

	public AreaWindow() {
		fill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha= 0.2f};
		stroke = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.5f};
		bfill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.8f};
        title = "Wayfarer";
        drawmode = DrawMode.NONE;
        dragmode = DragMode.FREE;

        var evtc = new EventControllerKey ();
        evtc.set_propagation_phase(PropagationPhase.CAPTURE);
        ((Gtk.Widget)this).add_controller(evtc);

        var evtm = new EventControllerMotion ();
        evtm.set_propagation_phase(PropagationPhase.CAPTURE);
        ((Gtk.Widget)this).add_controller(evtm);

        evtm.motion.connect((x,y) => {
                absx = (int)x;
                absy = (int)y;
                if (!ingrab) {
                    dragmode = set_cursor_mode((int)x,(int)y);
                }
            });

        var esckey = Gdk.keyval_from_name("Escape");
        var spckey = Gdk.keyval_from_name("space");
        var entkey = Gdk.keyval_from_name("Return");

        evtc.key_pressed.connect((kv, kc, mfy) => {
                if (kv == esckey) {
                    area_quit();
                }
                if (kv == spckey || kv == entkey) {
                    area_set(spx, spy, endx, endy);
                }
                return false;
            });

        var gestd = new GestureDrag();
        gestd.set_exclusive(true);
        ((Gtk.Widget)this).add_controller(gestd);

        var gestb = new GestureClick();
        gestb.set_exclusive(true);
        gestb.set_button(0);
        ((Gtk.Widget)this).add_controller(gestb);
        gestb.released.connect((n, x,y) => {
                var nb = gestb.get_current_button();
                if (nb == 2 || nb == 3) {
                    area_set(spx, spy, endx, endy);
                }
            });

        gestd.drag_begin.connect((x,y) => {
                ingrab = true;
                startx = 0;
                starty = 0;
                switch (dragmode) {
                case DragMode.FREE:
                    spx = (int)x;
                    spy = (int)y;
                    break;
                default:
                    break;
                }
                drawmode = DrawMode.RECT;
            });

        gestd.drag_end.connect((x,y) => {
                ingrab = false;
                check_relative();
                if (dragmode == DragMode.GRAB) {
                    dragmode = set_cursor_mode(absx, absy);
                }
            });

        gestd.drag_update.connect((x,y) => {
                var dx = (int)x - startx;
                var dy = (int)y - starty;
                switch (dragmode) {
                case DragMode.GRAB:
                    spx += dx;
                    endx += dx;
                    spy += dy;
                    endy += dy;
                    break;
                case DragMode.N:
                    spy += dy;
                    break;
                case DragMode.S:
                    endy += dy;
                    break;
                case DragMode.E:
                    endx += dx;
                    break;
                case DragMode.W:
                    spx += dx;
                    break;
                case DragMode.NE:
                    endx += dx;
                    spy += dy;
                    break;
                case DragMode.SE:
                    endx += dx;
                    endy += dy;
                    break;
                case DragMode.SW:
                    spx += dx;
                    endy += dy;
                    break;
                case DragMode.NW:
                    spx += dx;
                    spy += dy;
                    break;
                case DragMode.FREE:
                    endx = spx + (int)x;
                    endy = spy + (int)y;
                    break;
                default:
                    break;
                }
                if (check_relative()) {
                    dragmode = set_cursor_mode(absx, absy);
                }

                startx = (int)x;
                starty = (int)y;
                drawmode = DrawMode.RECT;
                queue_draw();
            });
    }

    private bool check_relative() {
        int mode = 0;
        int tmp;
        if (spx > endx) {
            mode |= 1;
            tmp = spx;
            spx = endx;
            endx = tmp;
        }
        if (spy > endy) {
            mode |= 2;
            tmp = spy;
            spy = endy;
            endy = tmp;
        }
        return (mode != 0);
    }

    private DragMode set_cursor_mode(int x, int y) {
        DragMode ret = DragMode.FREE;
        if(Math.sqrt((spx-x)*(spx-x) + (spy-y)*(spy-y)) < BLOB_RADIUS) {
            ret = DragMode.NW;
        } else if(Math.sqrt((endx-x)*(endx-x) + (spy-y)*(spy-y)) < BLOB_RADIUS) {
            ret = DragMode.NE;
        } else if(Math.sqrt((endx-x)*(endx-x) + (endy-y)*(endy-y)) < BLOB_RADIUS) {
            ret = DragMode.SE;
        } else if(Math.sqrt((spx-x)*(spx-x) + (endy-y)*(endy-y)) < BLOB_RADIUS) {
            ret = DragMode.SW;
        } else if(x > spx && x < endx && y > spy && y < endy) {
            ret = DragMode.GRAB;
        } else if(x > spx && x < endx && y > (spy - LINE_RELAX) && y < (spy+LINE_RELAX)) {
            ret = DragMode.N;
        } else if(x > spx && x < endx && y > (endy - LINE_RELAX) && y < (endy+LINE_RELAX)) {
            ret = DragMode.S;
        } else if(x > (spx-LINE_RELAX) && x < (spx+LINE_RELAX) && y > spy && y < endy) {
            ret = DragMode.W;
        } else if(x > (endx-LINE_RELAX) && x < (endx+LINE_RELAX) && y > spy && y < endy) {
            ret = DragMode.E;
        } else if(x > spx && x < endx && y > spy && y < endy) {
            ret = DragMode.GRAB;
        }
        set_cursor_for_mode(ret);
        return ret;
    }

    private void set_cursor_for_mode(DragMode mode) {
        foreach (var cm in cursor_modes) {
            if (cm.mode == mode) {
                set_cursor_from_name(cm.name);
                ///da.set_cursor_from_name(cm.name);
                break;
            }
        }
    }

	public void run (int mno) {
		set_cursor_from_name("crosshair");
		remove_css_class("background");
		if(mno == -1) {
			fullscreen();
		} else {
			var dpy = Gdk.Display.get_default();
			var mons = dpy.get_monitors();
			var nitems = mons.get_n_items();
			if (mno < nitems) {
				var monitor = (Gdk.Monitor)mons.get_item(mno);
				fullscreen_on_monitor(monitor);
			} else {
				fullscreen();
			}
		}
		present();
	}

    private void add_corner(Gtk.Snapshot snap, float x, float y) {
        var xrect = Graphene.Rect.zero();
        var xrrect = Gsk.RoundedRect(){};
        xrect.init(x-BLOB_RADIUS, y-BLOB_RADIUS, 2*BLOB_RADIUS, 2*BLOB_RADIUS);
        xrrect.init_from_rect(xrect, 90.0f);
        snap.push_rounded_clip(xrrect);
        snap.append_color(stroke, xrect);
        snap.pop();
    }

	public override void snapshot (Gtk.Snapshot snap) {
        if (drawmode == DrawMode.RECT) {
			float[] lwidths = {LINE_WIDTH, LINE_WIDTH, LINE_WIDTH, LINE_WIDTH};
			Gdk.RGBA[] lcols = {stroke, stroke, stroke, stroke};

			var rect = Graphene.Rect.zero();
            var rrect = Gsk.RoundedRect(){};
			rect.init(spx, spy, endx-spx, endy-spy);
			rrect.init_from_rect(rect, 0.0f);
			snap.append_color(fill, rect);
			snap.append_border(rrect, lwidths, lcols);
            add_corner(snap, spx, spy);
            add_corner(snap, endx, spy);
            add_corner(snap, endx, endy);
            add_corner(snap, spx, endy);
        } else {
			var rect = Graphene.Rect.zero();
			snap.append_color(bfill, rect);
		}
	}
}

#if TEST
// valac -D TEST  --pkg gtk4  sel4xa.vala
class SelTest : Gtk.Application {
	private uint32 tid = 0;
	private int monid = -1;

	public SelTest() {
        Object(application_id: "org.stronnag.seltest",
               flags: ApplicationFlags.FLAGS_NONE);
    }

	public void setmon(int id) {
		monid = id;
	}

    public override void activate () {
        base.startup();
		var window = new Gtk.ApplicationWindow(this);
		add_window (window);
		var sw = new AreaWindow ();
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

		var button = new Gtk.Button.with_label("SelTest");
		button.clicked.connect(() => {
				sw.run(monid);
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
    if (Environment.get_variable("GDK_BACKEND") == null) {
        Environment.set_variable("GDK_BACKEND", "x11", true);
    }
	int mno = -1;
    Gtk.init ();
	if(args.length > 1)
		mno = int.parse(args[1]);
	var app = new SelTest();
	app.setmon(mno);
	app.run();
	return 0;
}
#endif
