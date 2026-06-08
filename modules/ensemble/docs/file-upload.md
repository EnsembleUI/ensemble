# File upload action

This document describes the `uploadFiles` action, foreground and background
upload batches, and the `UploadFilesResponse` invokable API. Implementation
lives in `lib/action/upload_files_action.dart`, `lib/util/upload_utils.dart`,
and `lib/framework/data_context.dart`.

For multipart path-traversal checks, see
[Runtime security and data bindings](runtime-security-and-data-bindings.md#multipart-upload-paths).

## Action shape

```yaml
- uploadFiles:
    id: myUpload
    uploadApi: uploadPhotosApi
    files: ${filePicker.files}
    fieldName: files
    inputs:
      - albumId
    options:
      batchSize: 5
      maxFileSize: 10240
      backgroundTask: true
      showNotification: true
      networkType: unmetered
      requiresBatteryNotLow: true
    onComplete:
      invokeAPI:
        name: refreshGallery
    onError:
      showToast:
        message: Upload failed
```

### Required fields

| Field | Description |
| --- | --- |
| `uploadApi` | Name of a multipart API defined in the app's API map |
| `files` | Bound file list from camera, picker, or API data (see `_getRawFiles`) |

### Options

| Option | Default | Description |
| --- | --- | --- |
| `batchSize` | `null` (single batch) | Split files into sequential batches of at most N files |
| `maxFileSize` | 100 MB total | Maximum combined size of selected files (kilobytes in the action model) |
| `backgroundTask` | `false` | Run each batch via `Workmanager` instead of in the foreground isolate |
| `showNotification` | `false` | Show Android progress notifications during upload |
| `networkType` | `connected` | Workmanager network constraint (`connected`, `metered`, `unmetered`, `not_roaming`, `not_required`, `temporarily_unmetered`) |
| `requiresBatteryNotLow` | `false` | Workmanager battery constraint for background tasks |

## Batching

`splitUploadFileBatches` (`lib/util/upload_utils.dart`) divides the selected
files when `options.batchSize` is set:

- `batchSize: null` — one request with all files
- `batchSize: N` — multiple sequential uploads, each with at most N files
- Each batch creates a separate `UploadTask` when `id` is set

Background mode registers **one Workmanager task per batch**, each with a
unique task name and matching tag (see below).

## Foreground upload

When `backgroundTask` is `false` (default), each batch uploads in the current
isolate. Progress updates dispatch `ModelChangeEvent` on the action `id` binding
source when `id` is provided.

`onComplete` runs after each successful foreground batch. `onError` runs when
file selection, size validation, or upload fails.

## Background upload

When `backgroundTask` is `true`:

- **Not supported on web** — throws `LanguageError`
- Each batch registers a `Workmanager` one-off task with:
  - **Unique name** = generated 8-character task id
  - **Tag** = same task id (used for targeted cancellation)
  - Task name constant: `backgroundUploadTask` (`lib/ensemble_app.dart`)
- Progress, completion, errors, and cancellation are relayed from the background
  isolate to the UI isolate through `IsolateNameServer` ports keyed by task id

The host app must initialize Workmanager in `EnsembleApp` (already done in
starter).

## `UploadFilesResponse` API

When `id` is set on the action, the scope receives an `UploadFilesResponse`
invokable:

### Getters (last task)

| Getter | Description |
| --- | --- |
| `id` | Last task id |
| `progress` | Last task progress (`0.0`–`1.0`) |
| `status` | `pending`, `running`, `completed`, `cancelled`, or `failed` |
| `body` | Response body from the upload API |
| `headers` | Response headers |
| `allTasks` | JSON list of every task |

### Methods

| Method | Description |
| --- | --- |
| `cancelTask(taskId)` | Marks the task cancelled, calls `Workmanager.cancelByTag` for background tasks, and signals the background isolate |
| `cancelAll()` | Marks all non-completed tasks cancelled; cancels **only background upload tasks** via `cancelByTag` (does not call `Workmanager.cancelAll`, so other Workmanager jobs such as Bluetooth scans are unaffected) |
| `clear()` | Removes all tasks from the in-memory list |

Completed tasks are left unchanged by `cancelAll`.

### Example bindings

```yaml
Text:
  text: ${myUpload.status}
Progress:
  value: ${myUpload.progress}
```

```yaml
- Button:
    label: Cancel uploads
    onTap: myUpload.cancelAll();
```

## Constraints

- File paths containing a `..` segment are rejected before multipart assembly
  (see security doc).
- Total selected file size is checked before any batch starts; oversize
  selections show a toast and optionally run `onError`.
- Background `onComplete` / `onError` run on the UI isolate when the background
  task sends completion or error messages through the port.

## Tests

| Test file | Coverage |
| --- | --- |
| `test/upload_batch_split_test.dart` | `splitUploadFileBatches` |
| `test/upload_cancel_all_test.dart` | `cancelAll` tag scoping and completed-task handling |
| `test/upload_path_security_test.dart` | Path traversal rejection |
