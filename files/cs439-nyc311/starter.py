#!/usr/bin/env python3
"""Synthetic NYC 311 learning demo. No downloads or third-party packages.

Run: python3 starter.py
Test: python3 starter.py --self-test
Export: python3 starter.py --output predictions.csv

This is an interface demonstration, not the graded course starter or real data.
"""

import argparse
import csv
import math
import sys
import unittest
from datetime import date
from pathlib import Path


def synthetic_rows():
    """Hand-authored labels: these are not actual NYC requests or outcomes."""
    training_labels = [0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1]
    development_labels = [1, 0, 1, 0, 0, 1]
    rows = []
    for month, labels in [(1, training_labels), (2, development_labels)]:
        for day, label in enumerate(labels, start=1):
            rows.append({
                "row_id": "synthetic-{:02d}-{:02d}".format(month, day),
                "created_date": date(2025, month, day).isoformat(),
                "label": label,
            })
    return rows


def chronological_split(rows, cutoff):
    """Earlier records train; records on/after cutoff evaluate the model."""
    train = [row for row in rows if date.fromisoformat(row["created_date"]) < cutoff]
    dev = [row for row in rows if date.fromisoformat(row["created_date"]) >= cutoff]
    if not train or not dev:
        raise ValueError("Both time periods must contain at least one record.")
    return train, dev


def fit_global_rate(train):
    """The baseline learns one probability from training labels only."""
    if not train or any(row["label"] not in (0, 1) for row in train):
        raise ValueError("Training requires nonempty, binary labels.")
    return sum(row["label"] for row in train) / len(train)


def validate_predictions(expected_ids, predictions):
    """Require exactly one finite probability in [0, 1] per expected row."""
    expected_ids = list(expected_ids)
    ids = [row_id for row_id, _ in predictions]
    if len(set(expected_ids)) != len(expected_ids):
        raise ValueError("Expected row IDs are not unique.")
    if len(set(ids)) != len(ids):
        raise ValueError("Prediction row IDs are not unique.")
    if set(ids) != set(expected_ids):
        raise ValueError("Predictions must cover exactly the expected row IDs.")
    for _, probability in predictions:
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("Probabilities must be finite and between 0 and 1.")


def brier_score(rows, predictions):
    """Mean squared probability error; smaller is better (zero is perfect)."""
    if not rows or any(row["label"] not in (0, 1) for row in rows):
        raise ValueError("Scoring requires nonempty, binary labels.")
    validate_predictions([row["row_id"] for row in rows], predictions)
    probabilities = dict(predictions)
    return sum((probabilities[row["row_id"]] - row["label"]) ** 2
               for row in rows) / len(rows)


def write_predictions(path, predictions):
    """Exclusive creation protects existing files from accidental overwrite."""
    with Path(path).open("x", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["row_id", "p_slow_7d"])
        writer.writerows(predictions)


class DemoTests(unittest.TestCase):
    def setUp(self):
        self.train, self.dev = chronological_split(
            synthetic_rows(), date(2025, 2, 1))
        self.ids = [row["row_id"] for row in self.dev]

    def test_time_split(self):
        self.assertEqual((len(self.train), len(self.dev)), (12, 6))
        self.assertLess(max(row["created_date"] for row in self.train),
                        min(row["created_date"] for row in self.dev))

    def test_training_only_rate(self):
        self.assertAlmostEqual(fit_global_rate(self.train), 5 / 12)

    def test_perfect_score_and_id_alignment(self):
        predictions = [(row["row_id"], float(row["label"]))
                       for row in reversed(self.dev)]
        self.assertEqual(brier_score(self.dev, predictions), 0)

    def test_missing_or_extra_ids(self):
        for ids in [self.ids[:-1], self.ids + ["unexpected"]]:
            with self.assertRaises(ValueError):
                validate_predictions(self.ids, [(row_id, 0.5) for row_id in ids])

    def test_duplicate_predictions(self):
        predictions = [(row_id, 0.5) for row_id in self.ids]
        with self.assertRaises(ValueError):
            validate_predictions(self.ids, predictions + predictions[:1])

    def test_invalid_probability(self):
        for probability in [-0.1, 1.1, float("nan"), float("inf")]:
            with self.assertRaises(ValueError):
                validate_predictions(["one"], [("one", probability)])

    def test_empty_split_rejected(self):
        with self.assertRaises(ValueError):
            chronological_split(synthetic_rows(), date(2024, 1, 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        help="Optional new CSV path; existing files are never overwritten.")
    parser.add_argument("--self-test", action="store_true",
                        help="Run the small built-in test suite and exit.")
    args = parser.parse_args()
    if args.self_test:
        if args.output:
            parser.error("Use --self-test separately from --output.")
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(DemoTests)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1

    train, dev = chronological_split(synthetic_rows(), date(2025, 2, 1))
    rate = fit_global_rate(train)
    # Development labels are used only for evaluation, never to fit the baseline.
    predictions = [(row["row_id"], rate) for row in dev]
    validate_predictions([row["row_id"] for row in dev], predictions)
    print("SYNTHETIC DEMO — not real NYC data or a graded submission")
    print("Chronological split: {} training / {} development rows".format(len(train), len(dev)))
    print("Training global-rate probability: {:.6f}".format(rate))
    print("Development Brier score: {:.6f} (lower is better)".format(brier_score(dev, predictions)))
    print("Validated: exact ID coverage, unique IDs, finite probabilities in [0, 1].")
    if args.output:
        try:
            write_predictions(args.output, predictions)
        except OSError as error:
            print("Could not create output: {}".format(error), file=sys.stderr)
            return 1
        print("Created: {}".format(args.output))
    else:
        print("No files written. To export: python3 starter.py --output predictions.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
