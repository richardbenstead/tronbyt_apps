"""
Applet: Formula 1 Rotating Display
Summary: Rotates through Next Race, Constructor Standings, and Driver Standings
Description: Shows next race info, WCC standings, and WDC standings in turn with smooth slide transitions.
Author: AmillionAir
"""

load("encoding/base64.star", "base64")
load("encoding/json.star",      "json")
load("http.star",               "http")
load("render.star",             "render")
load("animation.star",          "animation")
load("schema.star",             "schema")
load("time.star",               "time")

VERSION = 25072

# Timing constants
FRAME_DELAY_MS    = 100   # 100 ms per frame
STATIC_FRAMES     = 30    # hold each page for 30 frames = 3 s
TRANSITION_FRAMES = 10    # slide transition across 10 frames = 1 s

DEFAULTS = {
    "timezone": "America/New_York",
    "time_24":   True,
    "date_us":   False,
}

F1_URLS = {
    "NRI": "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/next.json",
    "CS":  "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/constructorStandings.json",
    "DS":  "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/driverStandings.json",
}
METADATA_URLS = {
    "TRACKS": "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/metadata/tracks.json",
    "NAMES":  "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/metadata/constructor_names.json",
    "LOGOS":  "https://raw.githubusercontent.com/jvivona/tidbyt-data/refs/heads/main/formula1/metadata/constructor_logo.json",
}

F1_API_TTL   =  1800
METADATA_TTL = 43200

def main(config):
    tz   = config.get("$tz", DEFAULTS["timezone"])
    year = time.now().in_location(tz).format("2006")

    # ── Build Page 1: Next Race ───────────────────────────────────────────────
    nri   = get_f1_data(F1_URLS["NRI"].format(year), F1_API_TTL)["MRData"]
    tracks = get_f1_data(METADATA_URLS["TRACKS"], METADATA_TTL)

    if nri["RaceTable"]["Races"]:
        nr = nri["RaceTable"]["Races"][0]
        # parse or default to TBD
        if nr.get("time", "TBD") == "TBD":
            dt = time.parse_time(nr["date"] + "T12:00:00Z",
                                 "2006-01-02T15:04:05Z", "UTC").in_location(tz)
            time_str = "TBD"
        else:
            dt = time.parse_time(nr["date"] + "T" + nr["time"],
                                 "2006-01-02T15:04:05Z", "UTC").in_location(tz)
            fmt = "15:04" if config.bool("time_24", DEFAULTS["time_24"]) else "3:04pm"
            time_str = dt.format(fmt).replace("m", "")
        date_fmt = "Jan 2" if config.bool("date_us", DEFAULTS["date_us"]) else "2 Jan"
        date_str = dt.format(date_fmt)

        page1 = render.Column(children=[
            render.Marquee(
                width        = 64,
                child        = render.Text(
                                  " " + nr["raceName"]
                                  + " – " + nr["Circuit"]["Location"]["locality"]
                                  + " " + nr["Circuit"]["Location"]["country"]
                              ),
                offset_start = 5,
                offset_end   = 5,
            ),
            render.Box(width=64, height=1, color="#a0a"),
            render.Row(children=[
                render.Image(
                    src    = base64.decode(
                               tracks[nr["Circuit"]["circuitId"].lower()]),
                    height = 23, width = 28
                ),
                render.Column(children=[
                    render.Text(date_str, font="5x8"),
                    render.Text(time_str),
                    render.Text("Race " + nr["round"]),
                ]),
            ]),
        ])
    else:
        page1 = render.Column(children=[render.Text("No upcoming races!")])

    # ── Build Page 2: Constructor Standings ─────────────────────────────────
    cs   = get_f1_data(F1_URLS["CS"].format(year), F1_API_TTL)["MRData"]
    logos = get_f1_data(METADATA_URLS["LOGOS"], METADATA_TTL)
    names = get_f1_data(METADATA_URLS["NAMES"], METADATA_TTL)

    cs_rows = []
    if cs["StandingsTable"]["StandingsLists"]:
        top3 = cs["StandingsTable"]["StandingsLists"][0]["ConstructorStandings"][:3]
        for i in range(len(top3)):
            entry = top3[i]
            idx   = i + 1
            cid   = entry["Constructor"]["constructorId"]
            pts   = text_justify_trunc(3, entry["points"], "right")
            team = "   " + pts + " " + text_justify_trunc(12, names[cid], "left")
            cs_rows.append(render.Row(children=[
                render.Stack(children=[
                    render.Image(src=base64.decode(logos[cid])),
                    render.Text(team, font="tom-thumb"),
                ])
            ]))
    page2 = render.Column(children=(
        [ render.Text("WCC Standings"),
          render.Box(width=64, height=1, color="#a0a") ]
        + cs_rows
    ))

    # ── Build Page 3: Driver Standings ────────────────────────────────────────
    ds    = get_f1_data(F1_URLS["DS"].format(year), F1_API_TTL)["MRData"]
    ds_rows = []
    if ds["StandingsTable"]["StandingsLists"]:
        dr_list = ds["StandingsTable"]["StandingsLists"][0]["DriverStandings"][:3]
        for entry in dr_list:
            lname = entry["Driver"]["familyName"]
            pts   = text_justify_trunc(3, entry["points"], "right")
            ds_rows.append(render.Row(children=[
                render.Stack(children=[
                    render.Text(pts + " " + lname, font="tom-thumb"),
                ]),
            ]))
    page3 = render.Column(children=(
        [ render.Text("WDC Standings"),
          render.Box(width=64, height=1, color="#a0a") ]
        + ds_rows
    ))

    # ── Static holds ────────────────────────────────────────────────────────
    hold1 = animation.Transformation(
        child     = page1,
        duration  = STATIC_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[]),
            animation.Keyframe(1.0, transforms=[]),
        ],
    )
    hold2 = animation.Transformation(
        child     = page2,
        duration  = STATIC_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[]),
            animation.Keyframe(1.0, transforms=[]),
        ],
    )
    hold3 = animation.Transformation(
        child     = page3,
        duration  = STATIC_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[]),
            animation.Keyframe(1.0, transforms=[]),
        ],
    )

    # ── Slide 1 → 2: page1 slides left, page2 slides in ─────────────────────
    # page1 slide: from x=0 → x=-64
    page1_slide = animation.Transformation(
        child     = page1,
        duration  = TRANSITION_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[]),
            animation.Keyframe(1, transforms=[animation.Translate(0, 128)]),
        ],
    )
    # page2 slide: from x=+64 → x=0
    page2_slide = animation.Transformation(
        child     = page2,
        duration  = TRANSITION_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[animation.Translate(0, -64)]),
            animation.Keyframe(0.5, transforms=[animation.Translate(0, 0)]),
            animation.Keyframe(1, transforms=[animation.Translate(0, 0)]),
        ],
    )
    slide1 = render.Stack(children=[page1_slide, page2_slide])

    # ── Slide 2 → 3: page2 slides left, page3 slides in ─────────────────────
    page2_slide2 = animation.Transformation(
        child     = page2,
        duration  = TRANSITION_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[animation.Translate(0, 0)]),
            animation.Keyframe(1, transforms=[animation.Translate(0, 128)]),
        ],
    )
    page3_slide  = animation.Transformation(
        child     = page3,
        duration  = TRANSITION_FRAMES,
        keyframes = [
            animation.Keyframe(0.0, transforms=[animation.Translate(0, -64)]),
            animation.Keyframe(0.5, transforms=[animation.Translate(0, 0)]),
            animation.Keyframe(1, transforms=[animation.Translate(0, 0)]),
        ],
    )
    slide2 = render.Stack(children=[page2_slide2, page3_slide])

    # ── Chain them all in order ─────────────────────────────────────────────
    seq = render.Sequence(
        children=[hold1, slide1, hold2, slide2, hold3],
    )

    return render.Root(
        child               = seq,
        delay               = FRAME_DELAY_MS,
        show_full_animation = True,
    )

def get_schema():
    return schema.Schema(
        version="1",
        fields=[
            schema.Toggle(
                id      = "time_24",
                name    = "24-hour format",
                desc    = "Display times in 24-hour format",
                icon    = "clock",
                default = DEFAULTS["time_24"],
            ),
            schema.Toggle(
                id      = "date_us",
                name    = "US date format",
                desc    = "Display dates MM/DD style",
                icon    = "calendarDays",
                default = DEFAULTS["date_us"],
            ),
        ],
    )

def get_f1_data(url, ttl):
    resp = http.get(url, ttl_seconds=ttl)
    if resp.status_code != 200:
        fail("HTTP {} for URL {}".format(resp.status_code, url))
    body = resp.body()
    if body.startswith("Unable"):
        fail("API issue for URL {}".format(url))
    return json.decode(body)

def text_justify_trunc(length, text, direction):
    chars = list(text.codepoints())
    if len(chars) < length:
        pad = " " * (length - len(chars))
        return (pad + text) if direction == "right" else (text + pad)
    return "".join(chars[:length])

