

## 1.6.2

- Moved to Ensemble monorepo

## 1.6.1

- Add `equals` method to check if two dates are equal
- Add `operator -` to subtract a duration from a date
- Add `operator +` to add a duration to a date


## 1.6.0

- **Fork Release**: Published as `ensemble_date` - a maintained fork of `dart_date`
- Updated package name from `dart_date` to `ensemble_date`
- Updated repository links and documentation
- Improved dependency constraints
- Enhanced pub.dev compatibility

## 1.1.1

- Merge [PR](https://github.com/xantiagoma/dart_date/pull/16) to fix week calculation

## 1.1.0-nullsafety.0

- Add null-safety

## 1.0.9

- Rename `UTC` to `utc` & `Local` to `local` to follow dart analysis
- Changes in [PR #6](https://github.com/xantiagoma/dart_date/pull/6)
- Add optional `ignoreDaylightSavings` to `add*` methods

## 1.0.8

- Fix isMonday, isTuesday, isWednesday, isThursday, isFriday, isSaturday, isSunday

## 1.0.7

- Add getWeekYear, getWeek, getISOWeek, getISOWeeksInYear, startOfWeekYear, startOfISOWeekYear
- Merged PR: //github.com/xantiagoma/dart_date/pull/2

## 1.0.6

- Improve documentation
- Add extension operators on DateTime and Duration

## 1.0.5

- same `1.0.4`

## 1.0.4

- `pub.dev` recommendations

## 1.0.3

- Delete `this` if not needed and convert functions to `=>` if possible

## 1.0.2

- `dartfmt` overwriting

## 1.0.1

- Include recommendations from `pub.dev`

## 1.0.0

- **!!! Broken** API related to 0.x versions
- Using new fancy dart extensions feature
- Use `.method()` or `.property` to access extension methods / getters and `Date.method()` / `Date.property` for new static properties.

## 0.0.9

- Changes `Date.parse` to accept or not a format
- Added `date.isFirstDayOfMonth` getter
- Added `date.isLastDayOfMonth` getter
- Added `date.isLeapYear` getter

## 0.0.8

- Adding documentation and timeago `date.timeago()`
