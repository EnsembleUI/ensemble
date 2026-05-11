# Ensemble File Manager

`ensemble_file_manager` is the native implementation behind Ensemble's
`pickFiles` action and image-saving hook. It wires the Ensemble runtime to
`file_picker` for user-selected files and to `vision_gallery_saver` for saving
generated images, while keeping the public API exposed through Ensemble's
`FileManager` interface.

## Features

- Pick one or more files from the platform file picker.
- Restrict file selection with `allowedExtensions` when using the files source.
- Pick gallery media as images, videos, or mixed media based on source and
  extension options.
- Return selected file metadata into Ensemble data context under the action
  `id`.
- Save generated image bytes to the platform gallery/DCIM integration used by
  Ensemble's save-file and screenshot actions.

## Getting started

This package is normally enabled from the Starter app module scripts. The script
adds the package dependency, registers `FileManagerImpl`, and inserts platform
permissions/settings:

```bash
cd starter
dart scripts/modules/enable_files.dart platform=android,ios
```

For manual setup, add the package and register the implementation before the app
uses file actions:

```yaml
dependencies:
  ensemble_file_manager:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/file_manager
```

```dart
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble_file_manager/file_manager.dart';
import 'package:get_it/get_it.dart';

GetIt.I.registerSingleton<FileManager>(FileManagerImpl());
```

If the implementation is not registered, Ensemble uses `FileManagerStub` and file
actions fail with a configuration error.

## Usage

### Pick files from an Ensemble screen

```yaml
Button:
  label: Select PDF files
  onTap:
    pickFiles:
      id: selectedFiles
      source: files
      allowedExtensions:
        - pdf
      allowMultiple: true
      onComplete:
        showToast:
          message: ${selectedFiles.files[0].name}
      onError:
        showToast:
          message: Could not select files
```

After a successful pick, the action stores a `FileData` object under the action
`id`. Access selected files as `${selectedFiles.files}`. Each file is serialized
with:

| Field | Description |
| --- | --- |
| `name` | Original file name reported by the picker. |
| `extension` | File extension reported by the picker. |
| `size` | File size in bytes. |
| `path` | Native file path when available. This is `null` on web. |
| `bytes` | In-memory bytes when the picker supplies them. |
| `mediaType` | Inferred media type: `image`, `video`, `audio`, or `unknown`. |

### Source and extension behavior

- `source: files` or an omitted source uses `FileType.custom` only when
  `allowedExtensions` is set; otherwise it allows any file type.
- `source: gallery` maps any image extension (`jpg`, `jpeg`, `png`, `gif`,
  `bmp`) to the image picker. If no image extension is present, any video
  extension (`mp4`, `avi`, `mkv`, `flv`, `wmv`) maps to the video picker.
  Without a recognized extension list, gallery picks mixed media.
- `allowCompression` defaults to `true`; `allowMultiple` defaults to `false`.
- Cancelling the picker returns no files and runs `onError` when provided.

## Platform notes

The enable script adds the storage/media permissions used by Android and the
photo library/document settings used by iOS. Review generated platform files when
your app needs a narrower permission set; the script accepts a `permissions`
argument for Android permission selection.

On web, selected files do not expose a local path. Use file metadata and bytes
instead of assuming `${file.path}` is present.
