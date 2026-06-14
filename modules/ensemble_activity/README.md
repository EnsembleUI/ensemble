# Ensemble Activity

The Ensemble Activity module provides access to device motion and activity sensors for tracking user movement, orientation, and walking activity.

It supports:
- Real-time streaming
- One-time motion reads
- Selective sensor subscription
- Automatic lifecycle management

## Features

### Motion Sensors

Supported sensors:
- Accelerometer — device acceleration on X/Y/Z axes
- Gyroscope — rotation rate on X/Y/Z axes
- Magnetometer — magnetic field / compass direction
- Pedometer
  - Step count since stream start
  - Walking status (walking, stopped, etc.)
  - Estimated distance in meters

### Streaming Capabilities

- Subscribe to one or multiple sensors
- Merged motion stream for all selected sensors
- Broadcast stream (multiple listeners supported)
- Explicit start / stop lifecycle
- Automatic cleanup when stopped or cancelled

### Permissions

Activity Recognition permission is automatically requested when the pedometer sensor is included. If permission is denied, the stream emits an error event.

## Motion Data Model

Each emitted event contains a MotionData object:

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

Notes:
- Only requested sensors are populated
- Non-requested sensors may be null

## Available Actions

### getMotionData

Starts a motion stream or performs a single motion read.

**Parameters**

| Field | Type | Description |
|-------|------|-------------|
| id | string (optional) | Identifier for the motion stream |
| options.sensors | string[] | List of sensors to subscribe to |
| options.updateInterval | number | Update interval in milliseconds |
| options.recurring | boolean (optional) | Defaults to true |
| options.onDataReceived | action | Executed when motion data is emitted |
| options.onError | action | Executed when an error occurs |

**Sensor Values**

Valid sensor names:
- accelerometer
- gyroscope
- magnetometer
- pedometer

**Behavior**

- If a stream with the same id already exists, the existing stream is reused
- If recurring is set to false, returns one motion event and stops automatically
- Step counter resets when stream starts

**Examples**

Streaming Motion Data:

```yaml
getMotionData:
  id: motion_stream
  options:
    sensors:
      - accelerometer
      - gyroscope
      - magnetometer
    updateInterval: 1000
    onDataReceived:
      executeCode:
        body: |-
          console.log('Motion data:', event.data);
    onError:
      executeCode:
        body: |-
          console.log('Motion error:', event.error);
```

Pedometer Tracking:

```yaml
getMotionData:
  id: pedometer_stream
  options:
    sensors:
      - pedometer
    updateInterval: 1000
    onDataReceived:
      executeCode:
        body: |-
          var p = event.data && event.data.pedometer;
          if (p) {
            console.log('Steps:', p.steps, 'Distance:', p.distanceMeters);
          }
```

One-Time Motion Read:

```yaml
getMotionData:
  options:
    recurring: false
    sensors:
      - accelerometer
    onDataReceived:
      executeCode:
        body: |-
          console.log('Single read:', event.data);
```

### stopMotionData

Stops an active motion stream and releases sensor subscriptions.

**Parameters**

| Field | Type | Description |
|-------|------|-------------|
| id | string (optional) | ID of the stream to stop |

**Behavior**

- Cancels active sensor subscriptions
- Stops pedometer tracking
- Clears cached motion values
- Fully closes the motion stream

**Example**

```yaml
stopMotionData:
  id: motion_stream
```

## Lifecycle Notes

- Multiple sensors are merged into one stream
- A new MotionData event is emitted whenever any sensor updates
- Calling stopMotionData fully resets motion state
- UI cancellation automatically stops tracking

## Platform Notes

**Android**
- Requires ACTIVITY_RECOGNITION permission for pedometer

**iOS**
- Uses Core Motion pedometer APIs
- Distance estimated using approximately 0.75 m step length
