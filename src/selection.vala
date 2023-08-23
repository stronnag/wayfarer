using Gtk;

public class AreaWindow : Gtk.Window {
    private const  int BLOB_RADIUS=20;
    private const  int LINE_RELAX=4;
    private const float LINE_WIDTH=2.0f;
    private const string ENDTEXT = "Save the area :\n    - Press Enter or Space, or\n    - Click Button 2 or Button 3\nQuit : Press ESCape";

    private enum DrawMode {
        NONE = 0,
        RECT = 1,
        TEXT = 2,
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
	private Gdk.RGBA dfill;
	public signal void area_set(int x0, int y0, int x1, int y1);
	public signal void area_quit();

    private bool show_hint;
    private bool ingrab = false;
    private DrawMode drawmode;
    private DragMode dragmode;

	public AreaWindow(bool _show_hint) {
        show_hint = _show_hint;
		fill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha= 0.2f};
		stroke = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.5f};
		bfill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.8f};
		dfill = Gdk.RGBA(){red = 0.0f, green = 0.0f, blue = 0.0f, alpha= 0.5f};

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
                drawmode = DrawMode.TEXT;
                queue_draw();
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
                break;
            }
        }
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

    private void show_message(Gtk.Snapshot snap) {
        var width = ((endx-spx)*9)/10;
        var height = ((endy - spy)*9)/10;
        var font = new Pango.FontDescription();
        font.set_family("Sans");
        var fsize = 20 * Pango.SCALE;
        var context = this.get_pango_context();
        var layout = new Pango.Layout(context);
        font.set_size(fsize);
        layout.set_font_description(font);
        layout.set_text(ENDTEXT, -1);
        int lwidth;
        int lheight;
        layout.get_pixel_size(out lwidth, out lheight);
        var fw = fsize * width / lwidth;
        var fh = fsize * height / lheight ;
        fsize = (fw < fh) ? fw : fh;
        font.set_size(fsize);
        layout.set_font_description(font);
        layout.set_text(ENDTEXT, -1);
        layout.get_pixel_size(out lwidth, out lheight);
        var point = Graphene.Point();
        point.x = spx + (endx-spx)/20;
        var bh = (endy- spy);
        point.y = spy + (endy-spy)/20 + (bh-lheight)/2;
        snap.save();
        snap.translate(point);
        snap.append_layout(layout, bfill);
        snap.restore();
    }

	public override void snapshot (Gtk.Snapshot snap) {
        if (drawmode == DrawMode.NONE) {
            var rect = Graphene.Rect.zero();
			snap.append_color(bfill, rect);
		} else {
			float[] lwidths = {LINE_WIDTH, LINE_WIDTH, LINE_WIDTH, LINE_WIDTH};
			Gdk.RGBA[] lcols = {stroke, stroke, stroke, stroke};
			var rect = Graphene.Rect.zero();
            var rrect = Gsk.RoundedRect(){};
			rect.init(spx, spy, endx-spx, endy-spy);
			rrect.init_from_rect(rect, 0.0f);
            if (drawmode == DrawMode.TEXT) {
                snap.append_color(dfill, rect);
            } else {
                snap.append_color(fill, rect);
            }
			snap.append_border(rrect, lwidths, lcols);
            add_corner(snap, spx, spy);
            add_corner(snap, endx, spy);
            add_corner(snap, endx, endy);
            add_corner(snap, spx, endy);
            if (drawmode == DrawMode.TEXT) {
                if(show_hint) {
                    show_message(snap);
                }
            }
        }
	}

    private void set_bg() {
        string css = "window {background: rgba(255, 255, 255, 0.1);}";
        var provider = new CssProvider();
		Utils.load_provider_string( ref provider, css);
        var stylec = get_style_context();
        stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }

	public void run (Wayfarer.PWSession xdt, GenericArray<PortalManager.SourceInfo?> sis) {
		set_cursor_from_name("none");
        set_bg();
        if(xdt == Wayfarer.PWSession.X11) {
            fullscreen();
        } else {
            set_decorated(false);
            int w =0;
            sis.foreach((s) => {
                    w += s.width;
                });
            maximize();
            var nht = 0;
            show.connect(() => {
                    Timeout.add(10, () => {
                        var ht  = get_allocated_height();
                        if (ht == 0) {
                            nht++;
                            return true;
                        }
                        set_size_request(w,ht);
                        set_cursor_from_name("crosshair");
                        return false;
                    });
            });
        }
		present();
	}
}
