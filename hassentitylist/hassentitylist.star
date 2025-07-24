load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

# Colour constants (bright pastels for dark background)
TEMP_COLD     = "#ADD8E6"  # light blue
TEMP_COOL     = "#FFFFE0"  # light yellow
TEMP_WARM     = "#FFDAB9"  # peach puff
TEMP_HOT      = "#FFA07A"  # light salmon
TEMP_VERY_HOT = "#DDA0DD"  # plum

def main(config):
    children = add_children(config, "entity_1", "entity_2", "entity_3", "entity_4")
    return render.Root(
        child = render.Box(
            render.Column(
                expanded    = True,
                main_align  = "space_evenly",
                cross_align = "center",
                children    = children,
            ),
        ),
    )

def add_children(config, *childs):
    children = [
        entity for i, child in enumerate(childs)
        for _, entity in [render_entity(i, child, config)]
        if entity
    ]
    return children

def render_entity(row_id, entity_id, config):
    # Determine display name
    name = config.get(entity_id + "_name") or config.get(entity_id)
    fetch = fetch_entity(entity_id, config)
    if not fetch:
        return 0, None

    # Parse numeric value and unit
    count = int(float(fetch["state"]))
    unit  = fetch["attributes"].get("unit_of_measurement", "")

    # Determine if this is a water temperature
    is_water = unit.endswith("C") and "water" in name.lower()

    # Pick a bright pastel colour based on thresholds
    value_color = "#FF8888"  # fallback for non‑°C or undefined
    if unit.endswith("C"):
        if is_water:
            if count > 45:
                value_color = TEMP_HOT
            elif count > 35:
                value_color = TEMP_WARM
            elif count >= 30:
                value_color = TEMP_COOL
            else:
                value_color = TEMP_COLD
        else:
            if count > 30:
                value_color = TEMP_VERY_HOT
            elif count > 24:
                value_color = TEMP_HOT
            elif count > 18:
                value_color = TEMP_WARM
            elif count >= 16:
                value_color = TEMP_COOL
            else:
                value_color = TEMP_COLD

    # Alternate row backgrounds for readability
    line_bg = "#333333" if row_id % 2 else "#111111"

    return count, render.Stack(
        children = [
            render.Box(width = 64, height = 8, color = line_bg),
            render.Column([
                render.Box(width = 1, height = 1, color = "#00000000"),
                render.Row(
                    main_align = "space_between",
                    expanded   = True,
                    children   = [
                        render.Text(
                            content = name,
                            color   = "#FFFFFF",
                            font    = "tom-thumb",
                        ),
                        render.Text(
                            content = fetch["state"] + unit,
                            color   = value_color,
                            font    = "tom-thumb",
                        ),
                    ],
                ),
            ]),
        ],
    )

def fetch_entity(entity_id, config):
    if config.get(entity_id):
        rep = http.get(
            config.get("ha_url") + "/api/states/" + config.get(entity_id),
            ttl_seconds = 10,
            headers     = {"Authorization": "Bearer " + config.get("ha_token")},
        )
        if rep.status_code != 200:
            fail("%s request failed with status %d: %s" %
                 (entity_id, rep.status_code, rep.body()))
        return rep.json()
    return None

def get_schema():
    entity_schema = []
    for i in ["1", "2", "3", "4"]:
        entity_schema += [
            schema.Text(
                id   = "entity_" + i,
                name = "Entity ID " + i,
                desc = "Entity ID " + i + " (e.g. sensor.steps)",
                icon = "1",
            ),
            schema.Text(
                id   = "entity_" + i + "_name",
                name = "Entity Name " + i,
                desc = "Entity Name " + i + " (e.g. My Steps)",
                icon = "1",
            ),
        ]
    return schema.Schema(
        version = "1",
        fields  = [
            schema.Text(
                id   = "ha_url",
                name = "HomeAssistant URL",
                desc = "HomeAssistant URL. The address of your HomeAssistant instance, as a full URL.",
                icon = "book",
            ),
            schema.Text(
                id   = "ha_token",
                name = "HomeAssistant Token",
                desc = "HomeAssistant Token. Find in User Settings > Long‑lived access tokens.",
                icon = "book",
            ),
        ] + entity_schema,
    )

