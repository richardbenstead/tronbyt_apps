load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

def main(config):
    children = add_children(config, "entity_1", "entity_2", "entity_3", "entity_4")

    return render.Root(
        child = render.Box(
            render.Column(
                expanded      = True,
                main_align    = "space_evenly",
                cross_align   = "center",
                children      = children,
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
    name = config.get(entity_id + "_name")
    if not name:
        name = config.get(entity_id)
    fetch = fetch_entity(entity_id, config)
    if not fetch:
        return 0, None

    count = int(float(fetch["state"]))
    unit = ""
    if "unit_of_measurement" in fetch["attributes"]:
        unit = fetch["attributes"]["unit_of_measurement"]

    # Colour‑map any °C readings (air or water)
    value_color = "#FF8888"
    if unit.endswith("C"):
        if count > 30:
            value_color = "#800080"  # purple for >30°C
        elif count > 24:
            value_color = "#FF0000"  # red    for >24°C
        elif count > 18:
            value_color = "#FFA500"  # orange for >18°C
        elif count >= 16:
            value_color = "#FFFF00"  # yellow for ≥16°C
        else:
            value_color = "#0000FF"  # blue   for <16°C

    line_background_color = "#111111"
    if row_id % 2 == 1:
        line_background_color = "#333333"

    return count, render.Stack(
        children = [
            render.Box(width = 64, height = 8, color = line_background_color),
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

