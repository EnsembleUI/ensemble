# Ensemble Activity

The Ensemble Activity module provides access to device motion and activity sensors for tracking user movement and orientation. It supports real-time streaming and one-time reads of motion data, with optional sensor selection.

---

## Features

### Motion Sensors
- Accelerometer (x, y, z axes)
- Gyroscope (rotation rates)
- Magnetometer (compass / magnetic field)
- Pedometer
  - Step count since stream start
  - Pedestrian status (walking, stopped, etc.)
  - Distance estimation

### Streaming Capabilities
- Combined or single-sensor streams
- Broadcast streams (multiple listeners supported)
- Explicit start / stop lifecycle
- Automatic cleanup on cancel

### Permissions
- Automatically requests **Activity Recognition** permission when using:
  - `pedometer`
  - `all`
- Emits an error if permission is denied

---

## Motion Data Model

Each emitted event contains a `MotionData` object:

```json
{
  "accelerometer": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "gyroscope": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "magnetometer": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "pedometer": {
    "steps": 120,
    "status": "walking",
    "stepsOnStart": 3450,
    "distanceMeters": 90.0
  },
  "timestamp": "2026-02-07T10:30:00.000Z"
}
```

> Only the requested sensors will be populated. Others may be `null`.

---

## Available Actions (YAML)

### `getMotionData`

Starts a motion sensor stream or retrieves motion data.

#### Parameters

| Field | Type | Description |
|------|------|------------|
| `id` | string (optional) | Identifier for the motion stream |
| `options.recurring` | boolean | If `true`, keeps streaming until stopped |
| `options.sensorType` | string | `accelerometer`, `gyroscope`, `magnetometer`, `pedometer`, `all` |
| `options.updateInterval` | number | Update interval in milliseconds (default: 1000) |
| `options.onDataReceived` | action | Executed when motion data is emitted |
| `options.onError` | action | Executed when an error occurs |

#### Notes
- If a stream with the same `id` is already running, the existing stream is reused
- For `pedometer` and `all`, activity permission is requested automatically
- Pedometer steps are reset when the stream starts

---

### Example: All Sensors (Recurring)

```yaml
getMotionData:
  id: motion_all
  options:
    recurring: true
    sensorType: all
    updateInterval: 1000
    onDataReceived:
      executeCode:
        body: |-
          console.log('All motion:', event.data);
    onError:
      executeCode:
        body: |-
          console.log('Motion error:', event.error);
```

---

### Example: Pedometer Only

```yaml
getMotionData:
  id: pedometer_stream
  options:
    recurring: true
    sensorType: pedometer
    updateInterval: 1000
    onDataReceived:
      executeCode:
        body: |-
          if (event.data.pedometer) {
            console.log(
              'Steps:',
              event.data.pedometer.steps,
              'Distance:',
              event.data.pedometer.distanceMeters
            );
          }
```

---

### One-Time Motion Read

Returns the first available motion event and automatically stops the stream.

```yaml
getMotionData:
  options:
    sensorType: accelerometer
    onDataReceived:
      executeCode:
        body: |-
          console.log('Single accelerometer read:', event.data);
```

---

## `stopMotionData`

Stops a running motion stream and releases all sensor subscriptions.

### Parameters

| Field | Type | Description |
|------|------|------------|
| `id` | string (optional) | ID of the motion stream to stop |

### Behavior
- Cancels all active sensor subscriptions
- Stops pedometer tracking
- Resets internal state (steps and cached sensor values)
- Closes the motion stream controller

### Example

```yaml
stopMotionData:
  id: motion_all
```

---

## Lifecycle Notes

- Multiple sensors are merged into a single stream
- A new `MotionData` event is emitted whenever any sensor updates
- Calling `stopMotionData` fully resets the activity state
- Cancelling the stream from the UI automatically stops motion tracking

---

## Platform Notes

- **Android**
  - Requires `ACTIVITY_RECOGNITION` permission for pedometer
- **iOS**
  - Uses Core Motion pedometer APIs
  - Distance is estimated using a fixed step length of `0.75 meters`
