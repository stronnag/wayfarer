using Gst;

class Encoders {
    public struct EProp {
        string k;
        GLib.Value v;
    }

    public struct EPropSet {
        string name;
        EProp[] fprops;
        EProp[] eprops;
    }

    public struct EProfile {
        string name;
        string pname;
        string extn;
        EPropSet venc;
        EPropSet aenc;
        EPropSet menc;
        bool is_valid;
    }

    public struct EList {
        string pname;
        string name;
        bool is_valid;
    }

    public static EProfile []eprofiles;

    public static void Init() {
        eprofiles = {
            {
                "matroska",
                "Matroska",
                "mkv",
                {"x264enc",
                 {{"profile", "baseline"}},
                 {{"qp-max", 17},
                  {"speed-preset", "super-fast"},
                  {"threads", preferred_threads()}},
                },
                {"opusenc", {}, {}},
                {"matroskamux", {}, {}},
            },
            {
                "webm",
                "WebM",
                "webm",
                {"vp8enc",
                 {},
                 {{"max-quantizer", 17},
                  {"cpu-used", 16},
                  {"cq-level", 13},
                  {"deadline", 1},
                  {"static-threshold", 1000},
                  {"keyframe-mode", "disabled"},
                  {"buffer-size", 20000},
                  {"threads", preferred_threads()}},
                },
                {"opusenc", {},{}},
                {"webmmux", {},{}}
            },
            {
                "mp4",
                "MP4",
                "mp4",
                {"x264enc",
                 {{"profile", "baseline"}},
                 {{"qp-max", 17},
                  {"speed-preset", "superfast"},
                  {"threads", preferred_threads()}},
                },
                {"lamemp3enc", {},{}},
                {"mp4mux", {},{}}
            },
            {
                "webm-vp9",
                "WebM VP9",
                "vp9.webm",
                {"vp9enc",
                 {{"max-quantizer", 17},
                 {"cpu-used", 16},
                 {"cq-level", 13},
                 {"deadline", 1},
                 {"static-threshold", 100},
                 {"keyframe-mode", "disabled"},
                 {"buffer-size", 20000},
                 {"threads", preferred_threads()}},
                },
                {"opusenc", {},{}},
                {"webmmux", {},{}}
            },
            {
                "webm-av1",
                "WebM AV1",
                "av1.webm",
                {"av1enc",
                 {{"max-quantizer", 17},
                 {"cpu-used", 8},
                 {"end-usage", "cq"},
                 {"buffer-sz", 20000},
                 {"threads", preferred_threads()}},
                },
                {"opusenc", {},{}},
                {"webmmux", {},{}}
            },
            {
                "vaapi-vp8",
                "VAAPI VP8",
                "va-vp8.webm",
                {"vaapivp8enc", {}, {}},
                {"opusenc", {}, {}},
                {"webmmux", {}, {}}
            },
            {
                "vaapi-vp9",
                "VAAPI VP9",
                "va-vp9.webm",
                {"vaapivp9enc", {}, {}},
                {"opusenc", {}, {}},
                {"webmmux", {}, {}}
            },
            {
                "vaapi-h264",
                "VAAPI H264",
                "va-h264.mp4",
                {"vaapih264enc", {}, {}},
                {"lamemp3enc", {}, {}},
                {"mp4mux", {}, {}}
            },
        };
        var j = 0;
        foreach (var e in eprofiles) {
            eprofiles[j].is_valid = profile_valid(e);
            j++;
        }
    }

    public static uint preferred_threads() {
        return 1+get_num_processors()/2;
    }

    public static EProfile[] get_all() {
        return eprofiles;
    }

    public static EProfile? find(string name) {
        foreach (var e in get_all()) {
            if (e.name == name) {
                return e;
            }
        }
        return null;
    }


    static bool profile_valid(EProfile e) {
        return  ( Gst.ElementFactory.find(e.venc.name) != null &&
                  Gst.ElementFactory.find(e.aenc.name) != null &&
                  Gst.ElementFactory.find(e.menc.name) != null);
    }

    public static EList[] list_profiles() {
        EList[] profiles = {};
        foreach (var e in get_all()) {
            var l = EList(){name = e.name, pname=e.pname, is_valid = e.is_valid};
            profiles += l;
        }
        return profiles;
    }

    static Gst.Caps? get_caps_for_name(Gst.ElementFactory factory, EPropSet ep) {
        foreach (var template in factory.get_static_pad_templates()) {
            if (template.direction == Gst.PadDirection.SRC ) {
                var template_caps = template.get_caps();
                unowned var structure = template_caps.get_structure(0);
                var os = structure.copy();
                foreach (var e in ep.fprops) {
                    os.set_value(e.k, e.v);
                }
                var caps = new Caps.empty();
                caps.append_structure(os.copy());
                return caps;
            }
        }
        return null;
    }

    public static Gst.PbUtils.EncodingContainerProfile? get_container_profile(EProfile ep) {
        var vfactory = Gst.ElementFactory.find(ep.venc.name);
        if (vfactory == null) {
            stderr.printf("No video factory\n");
            return null;
        }
        var caps = get_caps_for_name(vfactory, ep.venc);
        stderr.printf("Video Factory %s %s\n", vfactory.get_name(), ep.venc.name);
        var vp = new Gst.PbUtils.EncodingVideoProfile(caps, null, null, 0);
        var os = new Structure.empty(caps.get_structure(0).get_name());
        foreach (var e in ep.venc.eprops) {
            os.set_value(e.k, e.v);
        }
        vp.set_element_properties(os.copy());

        var afactory = Gst.ElementFactory.find(ep.aenc.name);
        if (afactory == null) {
            stderr.printf("No audio factory\n");
            return null;
        }

        caps = get_caps_for_name(afactory, ep.aenc);
        var ap = new Gst.PbUtils.EncodingAudioProfile(caps, null, null, 0);
        os = new Structure.empty(caps.get_structure(0).get_name());
        foreach (var e in ep.aenc.eprops) {
            os.set_value(e.k, e.v);
        }
        ap.set_element_properties(os.copy());

        stderr.printf("Video: %s\n", vp.element_properties.to_string());
        stderr.printf("Audio: %s\n", ap.element_properties.to_string());

        var mfactory = Gst.ElementFactory.find(ep.menc.name);
        if (mfactory == null) {
            stderr.printf("No mux factory\n");
            return null;
        }

        caps = get_caps_for_name(mfactory, ep.menc);
        var cp = new Gst.PbUtils.EncodingContainerProfile(ep.menc.name, null, caps, null);
        cp.add_profile(vp);
        cp.add_profile(ap);
        return cp;
    }
}
