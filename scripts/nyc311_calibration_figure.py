#!/usr/bin/env python3
"""Generate accessible, responsive teaching SVGs from declared synthetic counts.

Run from any directory: python3 scripts/nyc311_calibration_figure.py
Uses only the Python standard library; no browser/runtime plotting dependency.
The publication assets are SVG with real text, not screenshots or traced glyphs.
Both axes are [0, 1] with the same physical scale. Fractions are computed from
the adjacent JSON counts. No empirical claim, uncertainty interval, or fitted
curve is implied. The diagonal represents perfect aggregate calibration; the
five dots are invented bin summaries, not five individual binary outcomes.
"""

from html import escape
import json
from pathlib import Path
import xml.etree.ElementTree as ET


FIGURES = Path(__file__).resolve().parents[1] / "files/cs439-nyc311/figures"
INK = "#163f3a"
TEAL = "#0c7064"
MUTED = "#52666b"
COPPER = "#9b4f25"
GRID = "#d6e1dc"


def make_svg(data, mobile=False):
    """Return an equal-scale calibration plot with a narrow-screen layout."""
    width, height = (360, 512) if mobile else (720, 562)
    left, top, side = (59, 60, 276) if mobile else (84, 60, 392)
    bottom = top + side
    summaries = " ".join(
        f"Mean prediction {item['mean_predicted_probability']:.2f} has "
        f"{item['positive_labels']} positive labels out of {item['requests']}, "
        f"an observed fraction of {item['positive_labels'] / item['requests']:.2f}."
        for item in data["bins"]
    )
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" '
        'aria-labelledby="calibration-title calibration-desc">',
        '<title id="calibration-title">Synthetic calibration plot: probabilities versus group outcomes</title>',
        '<desc id="calibration-desc">Both axes run from zero to one at equal scale. '
        'The dashed diagonal is an ideal match between predicted probabilities and observed fractions. '
        f'The dots summarize invented groups. {escape(summaries)} '
        'The highlighted group overestimates risk. These are not measured NYC 311 results.</desc>',
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
        f'<g font-family="Arial, Helvetica, sans-serif" fill="{INK}">',
    ]

    def text(x, y, value, size=16, color=INK, anchor="start", weight="400", transform=None):
        extra = f' transform="{transform}"' if transform else ""
        parts.append(
            f'<text x="{x:g}" y="{y:g}" font-size="{size}" fill="{color}" '
            f'text-anchor="{anchor}" font-weight="{weight}"{extra}>{escape(value)}</text>'
        )

    def line(x1, y1, x2, y2, color=GRID, stroke_width=1, dash=None):
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        parts.append(
            f'<line x1="{x1:g}" y1="{y1:g}" x2="{x2:g}" y2="{y2:g}" '
            f'stroke="{color}" stroke-width="{stroke_width}"{extra}/>'
        )

    def point(x, y, radius, fill, stroke="#ffffff", stroke_width=2):
        parts.append(
            f'<circle cx="{x:g}" cy="{y:g}" r="{radius}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{stroke_width}"/>'
        )

    def xy(probability, fraction):
        return left + probability * side, top + (1 - fraction) * side

    text(20 if mobile else left, 26, "Synthetic example · 100 requests per bin", 14, MUTED)
    for index in range(6):
        fraction = index / 5
        x, y = xy(fraction, fraction)
        line(x, top, x, bottom)
        line(left, y, left + side, y)
        text(x, bottom + 23, f"{fraction:.1f}", 14, MUTED, "middle")
        text(left - 11, y + 5, f"{fraction:.1f}", 14, MUTED, "end")
    line(left, bottom, left + side, bottom, MUTED, 1.5)
    line(left, top, left, bottom, MUTED, 1.5)
    line(left, bottom, left + side, top, MUTED, 2, "7 6")

    # A rotated direct label follows the equal-scale ideal diagonal.
    label_x, label_y = xy(0.44, 0.44)
    text(label_x, label_y - 11, "Ideal match", 14, MUTED,
         transform=f"rotate(-45 {label_x:g} {label_y - 11:g})")
    highlight = next(
        item for item in data["bins"]
        if item["mean_predicted_probability"] == data["highlight_mean_predicted_probability"]
    )
    for item in data["bins"]:
        probability = item["mean_predicted_probability"]
        fraction = item["positive_labels"] / item["requests"]
        x, y = xy(probability, fraction)
        if item is highlight:
            _, ideal_y = xy(probability, probability)
            line(x, ideal_y, x, y, COPPER, 2, "4 4")
            point(x, ideal_y, 4, "#ffffff", COPPER, 1.5)
            point(x, y, 7, COPPER)
        else:
            point(x, y, 6, TEAL)

    center = left + side / 2
    if mobile:
        text(center, bottom + 50, "Mean predicted probability", 16, anchor="middle")
        text(center, bottom + 71, "of slow_7d = 1", 16, anchor="middle")
    else:
        text(center, bottom + 50, "Mean predicted probability of slow_7d = 1", 16, anchor="middle")
    y_label_x = 17 if mobile else 24
    text(y_label_x, top + side / 2, "Observed fraction with slow_7d = 1", 14,
         anchor="middle", transform=f"rotate(-90 {y_label_x} {top + side / 2:g})")

    probability = highlight["mean_predicted_probability"]
    fraction = highlight["positive_labels"] / highlight["requests"]
    if mobile:
        point(26, 434, 6, COPPER, COPPER)
        text(42, 440, f"{probability:.2f} predicted · {fraction:.2f} observed", 16, COPPER, weight="700")
        text(22, 465, f"{highlight['positive_labels']} of {highlight['requests']} labels are 1 in this bin.", 15, MUTED)
        text(22, 488, "Risk is overestimated in this bin.", 15, MUTED)
    else:
        x, y = xy(probability, fraction)
        line(x + 12, y, 492, y, COPPER, 1.5)
        text(505, 247, f"{probability:.2f} predicted", 20, COPPER, weight="700")
        text(505, 278, f"{fraction:.2f} observed", 20, COPPER, weight="700")
        text(505, 305, f"({highlight['positive_labels']} of {highlight['requests']} labels are 1)", 15, MUTED)
        text(505, 343, "Risk is overestimated", 16, MUTED)
        text(505, 367, "in this bin.", 16, MUTED)
        text(left, 541, "Illustrative—not measured NYC 311 results.", 14, MUTED)
    parts.append("</g></svg>\n")
    svg = "\n".join(parts)
    ET.fromstring(svg)  # Fail generation if an accidental markup error slips in.
    return svg


def main():
    data = json.loads((FIGURES / "calibration-synthetic.json").read_text())
    probabilities = []
    for item in data["bins"]:
        probability = item["mean_predicted_probability"]
        assert 0 <= probability <= 1
        assert isinstance(item["requests"], int) and item["requests"] > 0
        assert isinstance(item["positive_labels"], int)
        assert 0 <= item["positive_labels"] <= item["requests"]
        probabilities.append(probability)
    assert probabilities == sorted(set(probabilities))
    assert data["highlight_mean_predicted_probability"] in probabilities
    # Fixed teaching example: keep the headers and interpretive annotation true.
    assert all(item["requests"] == 100 for item in data["bins"])
    highlight = next(item for item in data["bins"] if
                     item["mean_predicted_probability"] == data["highlight_mean_predicted_probability"])
    assert highlight["positive_labels"] / highlight["requests"] < highlight["mean_predicted_probability"]
    for mobile, filename in [(False, "calibration.svg"), (True, "calibration-mobile.svg")]:
        destination = FIGURES / filename
        destination.write_text(make_svg(data, mobile))
        print(destination)


if __name__ == "__main__":
    main()
