# Illustrative challenge figures

The calibration plot uses only the invented group counts in
[`calibration-synthetic.json`](calibration-synthetic.json). These are not empirical
NYC 311 results and expose no student, source, or hidden-test records.

Each dot summarizes 100 hypothetical requests: its x-coordinate is the group's
mean predicted probability; its y-coordinate is the number of `slow_7d = 1`
labels divided by 100. The highlighted bin has mean prediction 0.70 but 50/100
positive labels, so its observed fraction is 0.50. The dashed diagonal is the
ideal aggregate match. A bin below that line overestimates risk in that group.
Bin summaries can fluctuate with sampling; this illustration does not establish
that a real model is miscalibrated or replace evaluation on held-out data.

Regenerate from the repository root with:

```sh
python3 scripts/nyc311_calibration_figure.py
```

The generator requires only the Python standard library and does not access the
network. It preserves selectable SVG text, includes a title and long description,
and uses equal physical scales for both 0–1 axes. Fixed input counts make the
output reproducible. No runtime chart package, CDN, image generation, or font
download is needed. SVG is used to keep axes and text crisp at all resolutions.

- `calibration.svg`: 720 × 562, for desktop.
- `calibration-mobile.svg`: 360 × 512, with larger relative labels and its callout
  below the plot. The course page uses this variant below 900 px to account for
  its sidebar, and caps the displayed narrow-layout plot at 480 px.

Suggested image alternative text: “Synthetic calibration plot: groups with mean
predictions 0.10, 0.30, 0.50, 0.70, and 0.90 have observed slow fractions 0.12,
0.25, 0.40, 0.50, and 0.70. The highlighted 0.70 bin contains 50 positive labels
out of 100, so its risk predictions are too high on average.”

The webpage should also provide a plain-text caption identifying the data as
synthetic and explaining that calibration compares probabilities with outcomes
across groups, not with an individual row's zero/one label.

The hand-authored `closure-timeline.svg` (760 × 304) and
`closure-timeline-mobile.svg` (320 × 320) show three other synthetic requests
checked at day 21. Closures at day 3 and day 9 receive labels 0 and 1;
no recorded closure at the mature snapshot receives label 1. Each event is
positioned on a common 0–21 calendar-day scale. Days 0–7 are the outcome window;
days 7–14 are the reporting buffer, not an extension of the target. These are
conceptual cases, not the exact timestamps from the separate worked row.

The webpage also contains a responsive HTML diagram separating training,
prediction inputs, output probabilities, and label access during scoring.
