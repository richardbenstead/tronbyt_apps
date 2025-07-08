"""
Applet: ChatGPT
Summary: Gets news
Description: Gets news.
Author: RB
"""

load("render.star", "render")
load("schema.star", "schema")
load("http.star", "http")
load("encoding/json.star", "json")

DEFAULT_COLORS = {
    "header": "#00ff00",  # Green for feed name
    "headline": "#ffa500",  # Orange for headlines
    "desc": "#ffffff",  # White for descriptions
    "separator": "#666666",  # Gray for separator
}

def get_headlines(config):
    api_key = config.get("api_key", "")
    query = config.get("query", "Fetch news headlines from online sources. Give headlines using 80 charaters per headline. Use abbreviations as needed. Your response must be plain text, formatted as {headline1}<SEP>{headline2}<SEP>...")
    use_search = config.get("use_search")

    headers = {
        "Authorization": "Bearer " + api_key,
        "Content-Type": "application/json",
    }

    body = {
        "model": "gpt-4o",
        "input": [
            {"role": "system", "content": "You are a news summarizer."},
            {"role": "user", "content": query},
        ],
    }

    if use_search:
        body["tools"] = [{"type": "web_search_preview"}]

    body = json.encode(body)

    res = http.post(
        "https://api.openai.com/v1/responses",
        headers = headers,
        body = body,
    )

    json_txt = res.json()
    print(json_txt)
    print("")
    output = [o for o in json_txt["output"] if o["type"] == "message"][0]

    if res.status_code != 200:
        return render.Root(
            child = render.Text(
                content = "API Error",
                font = "6x10"
            )
        )

    text = output["content"][0]["text"]
    lines = text.split("<SEP>")
    headlines = []
    for line in lines:
        if line.strip() != "":
            headlines.append(line.lstrip("-• ").strip())

    return headlines

def main(config):
    colors = {
        "header": config.str("header_color", DEFAULT_COLORS["header"]),
        "headline": config.str("headline_color", DEFAULT_COLORS["headline"]),
        "desc": config.str("desc_color", DEFAULT_COLORS["desc"]),
        "separator": DEFAULT_COLORS["separator"],
    }

    scroll_speed = int(config.str("scroll_speed", "75"))  # Default to normal speed
    headlines = get_headlines(config)

    print("")
    print(headlines)

    def get_child(headline):
        return [render.WrappedText(
                content = headline,
                width = 64,
                color = colors["headline"],
                font = "tom-thumb",
            ),
            # Separator line
            render.Box(
                height = 1,
                color = colors["separator"],
            )]


    return render.Root(
        delay = scroll_speed,
        child = render.Marquee(
            height = 32,
            scroll_direction = "vertical",
            offset_start = 32,
            child = render.Column(
                expanded = True,
                children = [item for sublist in [get_child(h) for h in headlines] for item in sublist],
            ),
        ),
    )


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "API key",
                desc = "openai API key",
                icon = "user",
            ),
            schema.Text(
                id = "query",
                name = "chatgpt query",
                desc = "chatgpt prompt",
                icon = "user",
            ),
            schema.Toggle(
                id = "use_search",
                name = "Use search",
                desc = "Enable chatgpt search",
                icon = "compress",
                default = False,
            ),
            schema.Dropdown(
                id = "scroll_speed",
                name = "Scroll Speed",
                desc = "Speed of text scrolling",
                icon = "gear",
                default = "75",
                options = [
                    schema.Option(
                        display = "Faster",
                        value = "50",
                    ),
                    schema.Option(
                        display = "Normal",
                        value = "75",
                    ),
                    schema.Option(
                        display = "Slower",
                        value = "100",
                    ),
                ],
            ),
        ]
    )

