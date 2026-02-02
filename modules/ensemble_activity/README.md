# Ensemble Activity

This ensemble activity module handles motion sensor (direction, movement patterns) functionality for tracking user activity and movement.

## Features

### Motion Sensors
- Accelerometer data (x, y, z axes)
- Gyroscope data (rotation rates)
- Magnetometer data (compass direction)
- Combined motion data streams
- Configurable update intervals

## Usage

The module provides actions that can be used in Ensemble YAML configurations:

- `getMotionData`: Get motion sensor data (accelerometer, gyroscope, magnetometer)
    - `id`: Optional identifier for the motion data stream
    - `options`: Optional options for the motion data stream
        - `recurring`: Whether to get motion data recurringly
        - `sensorType`: The type of sensor to get data from (accelerometer, gyroscope, magnetometer, all)
        - `updateInterval`: The interval in milliseconds to get motion data (default is 1000 milliseconds)
        - `onDataReceived`: The action to execute when motion data is received
        - `onError`: The action to execute when an error occurs
    - Example:
    - ```yaml
        getMotionData:
            id: motion_stream_1
            options:
                recurring: true
                sensorType: all
                updateInterval: 1000
                onDataReceived:
                    executeCode:
                        body: |-
                            console.log(event.data);
                    onError:
                        showToast:
                            message: "Error: ${event.error}"
        ```
- `stopMotionData`: Stop motion sensor data stream
    - `id`: Optional identifier for the motion data stream
    - Example:
    - ```yaml
        stopMotionData:
            id: motion_stream_1
        ```