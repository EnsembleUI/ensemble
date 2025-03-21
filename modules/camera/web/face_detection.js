// Face detection initialization
window.initFaceDetection = async function () {
    if (!window.faceapi) {
        console.log('Loading face-api.js...');
        await new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    if (!window.faceDetectionModels) {
        try {
            const modelBaseUrl = 'https://raw.githubusercontent.com/justadudewhohacks/face-api.js/master/weights/';

            console.log('Loading face detection models...');

            // Load all required models for face detection
            await Promise.all([
                faceapi.nets.tinyFaceDetector.load(modelBaseUrl),
                faceapi.nets.faceLandmark68Net.load(modelBaseUrl),
                faceapi.nets.faceLandmark68TinyNet.load(modelBaseUrl)
            ]);

            console.log('All face detection models loaded successfully');
            window.faceDetectionModels = true;
        } catch (error) {
            console.error('Error loading face detection models: ' + error);
            throw error;
        }
    }
};

// Load the landmark model once during app initialization.
async function loadLandmarkModel() {
    // Constant for landmark model URL.
    const LANDMARK_MODEL_URL = 'https://raw.githubusercontent.com/justadudewhohacks/face-api.js/master/weights/';

    if (!window.faceapi.nets.faceLandmark68TinyNet.isLoaded) {
        console.info('Loading landmark model...');
        try {
            await window.faceapi.nets.faceLandmark68TinyNet.load(LANDMARK_MODEL_URL);
        } catch (error) {
            console.error('Failed to load landmark model.', error);
            throw error;
        }
    }
}

// Performs quality checks on the detected face using landmarks.
// Returns an object with { passed: boolean, message: string }
function performQualityChecks(landmarks, box, videoWidth, videoHeight, accuracyConfig) {
    const LANDMARK_VISIBILITY_THRESHOLD = accuracyConfig.landmarkRatio;
    const FRAME_MARGIN = accuracyConfig.frameMargin;
    const TILT_ANGLE_THRESHOLD = accuracyConfig.tiltAngleThreshold; // in degrees
    const HORIZONTAL_CENTER_TOLERANCE = accuracyConfig.horizontalCenterTolerance; // as a proportion of face width
    const EAR_THRESHOLD = accuracyConfig.earThreshold;
    const MIN_FACE_WIDTH_RATIO = accuracyConfig.minFaceWidthRatio;
    const MAX_FACE_WIDTH_RATIO = accuracyConfig.maxFaceWidthRatio;
    const QUALITY_PASS_THRESHOLD = accuracyConfig.qualityPassThreshold;
    const YAW_LOWER_THRESHOLD = accuracyConfig.yawLowerThreshold;
    const YAW_UPPER_THRESHOLD = accuracyConfig.yawUpperThreshold;

    let issues = [];
    let passes = 0;
    const totalChecks = 8;

    // 1. Landmark Visibility
    const visibleCount = landmarks.positions.filter(
        (p) => p.x >= 0 && p.x <= videoWidth && p.y >= 0 && p.y <= videoHeight
    ).length;
    if (visibleCount / landmarks.positions.length < LANDMARK_VISIBILITY_THRESHOLD) {
        issues.push('Some facial features are out of frame.');
    } else {
        passes++;
    }

    // 2. Essential Features Presence
    const leftEye = landmarks.getLeftEye();
    const rightEye = landmarks.getRightEye();
    const nose = landmarks.getNose();
    const mouth = landmarks.getMouth();
    const jaw = landmarks.getJawOutline();
    if (!leftEye.length || !rightEye.length || !nose.length || !mouth.length || !jaw.length) {
        issues.push('Essential facial features missing.');
    } else {
        passes++;
    }

    // 3. Face Centered in Frame
    const normX = box.x / videoWidth;
    const normY = box.y / videoHeight;
    const normW = box.width / videoWidth;
    const normH = box.height / videoHeight;
    if (
        normX < FRAME_MARGIN ||
        normY < FRAME_MARGIN ||
        normX + normW > 1 - FRAME_MARGIN ||
        normY + normH > 1 - FRAME_MARGIN
    ) {
        issues.push('Face is too close to the edge.');
    } else {
        passes++;
    }

    // 4. Face Alignment (Roll)
    const distance = (p1, p2) => Math.hypot(p1.x - p2.x, p1.y - p2.y);
    const leftCenter = {
        x: leftEye.reduce((sum, p) => sum + p.x, 0) / leftEye.length,
        y: leftEye.reduce((sum, p) => sum + p.y, 0) / leftEye.length,
    };
    const rightCenter = {
        x: rightEye.reduce((sum, p) => sum + p.x, 0) / rightEye.length,
        y: rightEye.reduce((sum, p) => sum + p.y, 0) / rightEye.length,
    };
    const dx = rightCenter.x - leftCenter.x;
    const dy = rightCenter.y - leftCenter.y;
    const tiltAngle = Math.abs(Math.atan2(dy, dx) * (180 / Math.PI));
    if (tiltAngle > TILT_ANGLE_THRESHOLD) {
        issues.push('Keep your face straight.');
    } else {
        passes++;
    }

    // 5. Horizontal Centering (using nose tip)
    const faceCenterX = box.x + box.width / 2;
    const noseTip = nose[Math.floor(nose.length / 2)];
    if (Math.abs(noseTip.x - faceCenterX) > box.width * HORIZONTAL_CENTER_TOLERANCE) {
        issues.push('Center your face horizontally.');
    } else {
        passes++;
    }

    // 6. Eye Openness (EAR)
    const getEAR = (eye) => {
        const A = distance(eye[1], eye[5]);
        const B = distance(eye[2], eye[4]);
        const C = distance(eye[0], eye[3]);
        return (A + B) / (2 * C);
    };
    const leftEAR = getEAR(leftEye);
    const rightEAR = getEAR(rightEye);
    if (leftEAR < EAR_THRESHOLD || rightEAR < EAR_THRESHOLD) {
        issues.push('Eyes appear closed.');
    } else {
        passes++;
    }

    // 7. Face Size
    const faceWidthRatio = box.width / videoWidth;
    if (faceWidthRatio < MIN_FACE_WIDTH_RATIO || faceWidthRatio > MAX_FACE_WIDTH_RATIO) {
        issues.push(faceWidthRatio < MIN_FACE_WIDTH_RATIO ? 'Move closer to the camera.' : 'Move further from the camera.');
    } else {
        passes++;
    }

    // 8. Head Pose (Yaw)
    const nosePoint = nose[Math.floor(nose.length / 2)];
    const dLeft = distance(nosePoint, leftCenter);
    const dRight = distance(nosePoint, rightCenter);
    const yawRatio = dLeft / dRight;
    if (yawRatio < YAW_LOWER_THRESHOLD || yawRatio > YAW_UPPER_THRESHOLD) {
        issues.push('Face is not oriented forward.');
    } else {
        passes++;
    }

    const qualityScore = passes / totalChecks;
    if (qualityScore >= QUALITY_PASS_THRESHOLD) {
        return {
            passed: true,
            message: 'Face positioned ideally.'
        };
    }
    return { passed: false, message: issues[0] };
}

// face detection
window.detectFace = async function (videoElement, accurateMode = false, accuracyConfig) {
    const DETECTION_THRESHOLD = accuracyConfig['detectionThreshold'];
    const INTERSECTION_RATIO_THRESHOLD = accuracyConfig['intersectionRatioThreshold'];
    const EXTRA_HEIGHT_FACTOR = accuracyConfig['extraHeightFactor'];

    const INPUT_SIZE = accuracyConfig.inputSize;

    if (!videoElement || videoElement.readyState !== 4) {
        return { detected: false, message: 'Video element is not ready.' };
    }
    ;
    let detection;

    try {
        // In accurate mode, load the landmark model.
        if (accurateMode) {
            try {
                await loadLandmarkModel();
            } catch (err) {
                console.warn('Accurate mode disabled: using basic detection.');
                accurateMode = false;
            }
        }

        // Perform face detection.
        detection = accurateMode
            ? await faceapi
                .detectSingleFace(
                    videoElement,
                    new faceapi.TinyFaceDetectorOptions({ inputSize: INPUT_SIZE, scoreThreshold: DETECTION_THRESHOLD })
                )
                .withFaceLandmarks()
            : await faceapi.detectSingleFace(
                videoElement,
                new faceapi.TinyFaceDetectorOptions({ inputSize: INPUT_SIZE, scoreThreshold: DETECTION_THRESHOLD })
            );

        if (!detection) {
            return { detected: false, message: 'No face detected.' };
        }

        // Retrieve bounding box.
        const box = detection.detection?.box || detection.box;
        if (!box) {
            console.error('No bounding box found.');
            return { detected: false, message: 'Detection error.' };
        }

        const videoWidth = videoElement.videoWidth;
        const videoHeight = videoElement.videoHeight;

        // Check if face is fully visible.
        const intersectionX = Math.max(0, Math.min(box.x + box.width, videoWidth) - Math.max(box.x, 0));
        const intersectionY = Math.max(0, Math.min(box.y + box.height, videoHeight) - Math.max(box.y, 0));
        if ((intersectionX * intersectionY) / (box.width * box.height) < INTERSECTION_RATIO_THRESHOLD) {
            return { detected: false, message: 'Face is not fully visible.' };
        }

        // Normalize coordinates and add extra height for hair.
        const extraHeight = box.height * EXTRA_HEIGHT_FACTOR;
        const normalized = {
            left: box.x / videoWidth,
            top: Math.max(0, box.y - extraHeight) / videoHeight,
            width: box.width / videoWidth,
            height: (box.height + extraHeight) / videoHeight,
        };

        // In fast mode, return detection without quality checks.
        if (!accurateMode || !detection.landmarks) {
            return { detected: true, ...normalized, message: 'Face detected.' };
        }

        // In accurate mode, perform quality checks.
        const quality = performQualityChecks(detection.landmarks, box, videoWidth, videoHeight, accuracyConfig);
        if (quality.passed) {
            return { detected: true, ...normalized, message: quality.message };
        }
        return { detected: false, ...normalized, message: quality.message };
    } catch (e) {
        console.error('Face detection error:', e);
        return { detected: false, message: 'Detection error. Please try again.' };
    }
};

