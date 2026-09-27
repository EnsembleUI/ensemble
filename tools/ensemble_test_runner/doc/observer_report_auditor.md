# Observer report auditor

Run the full audit from this package directory:

```sh
dart run tool/audit_observer_report.dart /path/to/report/index.html
```

The path can also point to the report directory, `results.json.gz`, or an
uncompressed JSON report. Without a path, the auditor prompts for one. Use
`--format=json` for structured findings and `--no-ocr` for a structural-only
run. On macOS, the default run also compares screenshot text using Vision.

## Finding levels

- `ERROR` means the report violates a direct invariant, such as an element
  marked both visible and offscreen or an enabled state that conflicts with
  interactability. These findings produce a nonzero exit code.
- `WARN` means the report contains a concrete concern that can make an action
  unsafe, such as an ambiguous text action without an occurrence or bounds
  target.
- `REVIEW` means a heuristic found visual or cross-screen evidence that needs
  human confirmation. OCR can see background content behind a modal or text
  inside an illustration; these cases are not automatically classified as
  observer defects.
- `INFO` means a check could not run or found lower-confidence evidence.

JSON findings include a stable `code`, severity, confidence, explanation, and
report-relative screenshot path when visual evidence is available. Confidence
describes confidence in the finding itself, not a probability that the observer
is correct.

## Reference cases

`test/audit_observer_report_test.dart` is the initial labeled reference set. It
asserts that:

- an element genuinely below the viewport with a scroll example is accepted;
- multiple offscreen labels matching a different visited screen produce a
  `REVIEW` candidate;
- contradictory visible and offscreen state is an `ERROR`.
- ambiguous text actions warn when they omit occurrence or another scope, while
  an action example with an occurrence remains accepted.

Add a reviewed good or defective report snapshot whenever a new rule is added.
Each rule should have at least one positive case and one negative case before it
is used to raise severity or block a report.

The OCR pass currently runs only on macOS and skips screenshots whose aspect
ratio differs from the observer viewport because there is no verified
device-frame transform. It is a visual cross-check, not a complete visual
understanding system. Continue adding labeled snapshots and track false
positives and missed seeded defects before treating the auditor as a release
gate.
