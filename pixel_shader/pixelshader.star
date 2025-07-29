load("render.star", "render")
load("time.star", "time")
load("math.star", "math")

num_rows = 32
num_cols = 64

def byte_to_hex(x):
    """Convert a number (0–255) to a two-digit hex string."""
    x = max(0, min(255, int(x)))
    hex_digits = "0123456789ABCDEF"
    return hex_digits[(x >> 4) & 0xF] + hex_digits[x & 0xF]

def rgba8_to_hex(rgba):
    return ''.join([byte_to_hex(c) for c in rgba])


def pix_wipe(row, col, frame_num):
    frame_num *= 2

    a = 15 + 10 * math.sin((frame_num*1.2 + row + col) / 30)
    a = int(a) % 16
    r = 8 + (row-16) / 2 #30-row + 4 * math.sin((col + frame_num*0.9 + math.sin(frame_num/2)) / 20)
    g = row/3
    b = 30-col + 4 * math.sin((row + frame_num) / 20)
    return render.Box(width=1, height=1, color=rgba8_to_hex([r, g, b, a]))

def pix_dots(row, col, frame_num):
    # Every nth column, every nth row, moving left
    star = (((col + frame_num//2) % 16 == 0) and (row % 8 == 0))
    r = 15 if star else 2
    g = 12 if star else 4
    b = 14 if star else 8
    a = 15 if star else 6
    return render.Box(width=1, height=1, color=rgba8_to_hex([r, g, b, a]))

def pix_plasma(row, col, frame_num):
    v = (
        math.sin(row/4.0 + frame_num/16.0)
        + math.sin(col/6.0 + frame_num/12.0)
        + math.sin((row + col)/8.0 + frame_num/24.0)
    )
    # v ranges from -3 to 3, normalize to 0..1
    v = (v + 3) / 6.0
    r = int(8 + 7 * v)
    g = int(7 + 7 * (1-v))
    b = int(12 + 3 * math.sin(frame_num/20.0))
    a = 10 + int(5 * v)
    return render.Box(width=1, height=1, color=rgba8_to_hex([r, g, b, a]))

def pix_trongrid(row, col, frame_num):
    horizon = num_rows // 2
    fade = max(0, 1 - (row / horizon))
    # moving horizontal lines
    hline = (row + frame_num//3) % 8 == 0
    # moving vertical lines
    vline = (col + frame_num//2) % 12 == 0
    r = int(3 + 10 * fade) if hline or vline else int(3 * fade)
    g = int(8 + 6 * fade) if hline or vline else int(5 * fade)
    b = 15 if hline or vline else int(8 * fade)
    a = int(8 + 7 * fade)
    return render.Box(width=1, height=1, color=rgba8_to_hex([r, g, b, a]))


def pix_cloud(row, col, frame_num):
    # Simulate moving through 3D clouds: combine sine/cosine waves with parallax
    time = frame_num / 40.0
    x = col / 8.0 + time
    y = row / 4.0 + math.sin(time * 1.2)
    # Multi-layer noise for puffy clouds
    n = (
        0.6 * math.sin(x + 0.3 * y + 0.8 * time)
      + 0.4 * math.cos(0.7 * x - 0.2 * y + 1.5 * time)
      + 0.3 * math.sin(1.2 * x + 1.3 * y - 0.4 * time)
      + 0.25 * math.sin(0.3 * x * y - 1.5 * y + 2.5 * time)
    )
    n = (n + 1.5) / 3.0  # Normalize to 0..1
    # Adjust color and alpha for puffy, glowing clouds
    r = int(0.5 * 220.0 * n + 140)
    g = int(0.5 * 230.0 * n + 100)
    b = int(0.5 * 255.0 * n + 100)
    a = 255
    return render.Box(width=1, height=1, color=rgba8_to_hex([r, g, b, a]))


def render_grid(frame_num):
    rows = []

    shader_fn = pix_cloud
    for grid_row in range(num_rows):
        rows.append(render.Row([shader_fn(grid_row, grid_col, frame_num) for grid_col in range(num_cols)]))

    return render.Column(rows)

def main(config):
    NUM_FRAMES = 250
    frames = [render.Stack(children = [render_grid(i)]) for i in range(NUM_FRAMES)]

    return render.Root(
        delay = 60,
        child = render.Animation(frames),
    )
