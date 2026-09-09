# NYC 311: synthetic getting-started demo

This small, public demo lets you check your Python setup and explore the shape of
the challenge. All 18 example records and labels are fictional. It is not the
graded starter, the course dataset, or a complete challenge solution. The official
data package, submission interface, and deadlines will be announced through the
course page and Canvas.

## Run it

Download `starter.py` into a folder and open a terminal in that folder. You need
Python 3.8 or newer. No extra packages, accounts, API keys, network requests, or
downloads are required by the script.

```sh
python3 --version
python3 starter.py
python3 starter.py --self-test
```

On a Windows installation with the Python launcher, use `py -3` in place of
`python3`.

The default run prints a result and writes no files. You should see:

```text
Chronological split: 12 training / 6 development rows
Training global-rate probability: 0.416667
Development Brier score: 0.256944 (lower is better)
```

To create a demonstration prediction file explicitly:

```sh
python3 starter.py --output predictions.csv
```

The file has `row_id,p_slow_7d` columns. The program refuses to overwrite an
existing file. Choose a new name if you run the export again. This CSV format is
illustrative; follow the official submission contract when it is released.

## What you are learning

The program separates earlier January records from later February records. It
learns one probability from the training labels: the fraction of training labels
equal to one. It then assigns that probability to every development record. This
is the global-rate baseline.

The Brier score is the mean of `(predicted_probability - observed_label) ** 2`.
A smaller score is better. Development labels are used to evaluate the baseline,
not to train it. The score shown above describes only this fictional example; it
is not a performance target for the real challenge.

Before scoring, the script verifies that every expected row ID appears exactly
once and that each probability is finite and between zero and one. Predictions
are matched to labels by ID rather than by file order. IDs are join keys, not
predictive features.

## Understand the real target before modeling

The planned challenge target asks whether a request lacks a recorded closure
timestamp within seven days of creation, in a frozen course snapshot. A closure
at or before the seven-day boundary means label `0`; a later closure or no
recorded closure means label `1`, provided the request is old enough to label.

Staff will construct labels only for requests at least 14 days old at extraction:
seven days for the outcome and a further seven-day reporting buffer. A missing
closure on a recent request is not enough to assign label `1`. Mature open
requests remain in the dataset. Invalid timestamps are handled by published
exclusion rules. Recorded administrative closure does not prove that the
underlying civic problem was resolved.

This script uses hand-authored labels and does not implement real-data target
construction, reporting delays, or leakage-safe feature engineering.

## Use only eligible information

The prediction is made from course-approved attributes plausibly available at
intake. The planned allowlist includes creation date/hour, agency, problem and
reviewed problem detail, location type, borough, community board, and submission
channel. Follow the final data dictionary for exact names and eligibility.

Closure dates, status, resolution descriptions, due dates, update timestamps,
original public request IDs, addresses, and precise coordinates are excluded
from the scored feature files. A field's presence in a public download does not
make it eligible. Never retrieve request outcomes from the live public dataset
to fill in missing or hidden course labels. The real benchmark uses a frozen
snapshot, and historical attributes may have been revised after intake.

## Small exercises before the official release

1. Explain why the probability is `5 / 12` and why the development labels do not
   change it.
2. Reverse the order of the prediction rows. Explain why the score is unchanged.
3. Try a duplicate ID, a missing ID, or a probability of `1.2`. Identify the
   validation failure before running the code.
4. Explain why an always-zero predictor could appear strong on an imbalanced
   dataset, and what the global-rate baseline adds to that comparison.

AI assistance is welcome for explaining the demo. Check suggestions by running
the code, inspecting the inputs, and testing an example yourself. Be prepared to
explain any change you keep.
