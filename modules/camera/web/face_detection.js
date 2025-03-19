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

// Face detection function
// Face detection function with enhanced quality checks
window.detectFace = async function (videoElement, accurateMode = false) {
    if (!videoElement || videoElement.readyState !== 4)
        return { detected: false, message: 'Video not ready' };
    try {
        const detectionThreshold = accurateMode ? 0.6 : 0.5;
        let detection = await faceapi.detectSingleFace(
            videoElement,
            new faceapi.TinyFaceDetectorOptions({
                inputSize: 224,
                scoreThreshold: detectionThreshold
            })
        );
        if (!detection) {
            return { detected: false, message: 'No face detected' };
        }

        if (accurateMode) {
            try {
                if (window.faceapi.nets && !window.faceapi.nets.faceLandmark68TinyNet.isLoaded) {
                    console.log('Loading facial landmark model...');
                    try {
                        await window.faceapi.nets.faceLandmark68TinyNet.load('https://raw.githubusercontent.com/justadudewhohacks/face-api.js/master/weights/');
                    } catch (modelError) {
                        console.error('Error loading facial landmark model:', modelError);
                        accurateMode = false;
                    }
                }
                if (accurateMode) {
                    const landmarkDetection = await faceapi
                        .detectSingleFace(
                            videoElement,
                            new faceapi.TinyFaceDetectorOptions({
                                inputSize: 224,
                                scoreThreshold: detectionThreshold
                            })
                        )
                        .withFaceLandmarks(true);

                    if (landmarkDetection && landmarkDetection.landmarks) {
                        detection = landmarkDetection;
                    } else {
                        console.log('Failed to get facial landmarks, falling back to basic detection');
                        accurateMode = false;
                    }
                }
            } catch (e) {
                console.error('Error in landmark detection, falling back to basic detection:', e);
                accurateMode = false;
            }
        }

        if (detection) {
            const videoWidth = videoElement.videoWidth;
            const videoHeight = videoElement.videoHeight;

            // Get the detection box and adjust it (add extra height for hair)
            let box;
            if (detection.detection && detection.detection.box) {
                box = detection.detection.box;
            } else if (detection.box) {
                box = detection.box;
            } else {
                console.error('Face detection box not found in detection object');
                return { detected: false, message: 'Face detection issues' };
            }

            // --- Added check for full face visibility ---
            const intersectionX = Math.max(0, Math.min(box.x + box.width, videoWidth) - Math.max(box.x, 0));
            const intersectionY = Math.max(0, Math.min(box.y + box.height, videoHeight) - Math.max(box.y, 0));
            const intersectionArea = intersectionX * intersectionY;
            const boxArea = box.width * box.height;
            if (intersectionArea / boxArea < 0.9) {
                return {
                    detected: false,
                    message: 'Face not fully visible. Please position your face completely in view.'
                };
            }
            // ------------------------------------------

            const extraHeightForHair = box.height * 0.3;
            const adjustedY = Math.max(0, box.y - extraHeightForHair);
            const normalizedX = box.x / videoWidth;
            const normalizedY = adjustedY / videoHeight;
            const normalizedWidth = box.width / videoWidth;
            const normalizedHeight = (box.height + extraHeightForHair) / videoHeight;

            // If not in accurate mode or landmarks not available, return basic detection
            if (!accurateMode || !detection.landmarks) {
                return {
                    detected: true,
                    left: normalizedX,
                    top: normalizedY,
                    width: normalizedWidth,
                    height: normalizedHeight,
                    message: 'Face detected'
                };
            } else {
                try {
                    const landmarks = detection.landmarks;
                    let statusMessage = '';
                    let qualityIssues = [];
                    let passedChecks = 0;
                    const totalChecks = 8; // Updated number of quality checks

                    // Utility: Euclidean distance between two points
                    const distance = (p1, p2) => Math.hypot(p1.x - p2.x, p1.y - p2.y);

                    // 0. Landmark Visibility: Check if at least 95% of landmarks are visible
                    const visibleLandmarkRatio = landmarks.positions.filter(p =>
                        p.x >= 0 && p.x <= videoWidth && p.y >= 0 && p.y <= videoHeight
                    ).length / landmarks.positions.length;
                    if (visibleLandmarkRatio < 0.95) {
                        qualityIssues.push('Some facial features are outside the frame');
                    } else {
                        passedChecks++;
                    }

                    // 1. Essential Facial Features: Must detect both eyes, nose, mouth, and jawline
                    const leftEye = landmarks.getLeftEye();
                    const rightEye = landmarks.getRightEye();
                    const nose = landmarks.getNose();
                    const mouth = landmarks.getMouth();
                    const jawOutline = landmarks.getJawOutline();
                    if (leftEye.length === 0 || rightEye.length === 0 ||
                        nose.length === 0 || mouth.length === 0 ||
                        jawOutline.length === 0) {
                        qualityIssues.push('Some essential facial features are not visible');
                    } else {
                        passedChecks++;
                    }

                    // 2. Face Within Frame: Ensure the detected face is not too close to the video edges
                    const margin = 0.05;
                    const isCompletelyInFrame =
                        normalizedX >= margin &&
                        normalizedY >= margin &&
                        (normalizedX + normalizedWidth) <= (1 - margin) &&
                        (normalizedY + normalizedHeight) <= (1 - margin);
                    if (!isCompletelyInFrame) {
                        qualityIssues.push('Move face away from edges');
                    } else {
                        passedChecks++;
                    }

                    // 3. Face Alignment (Roll): Check tilt angle (should be less than 6°)
                    const leftEyeCenter = {
                        x: leftEye.reduce((sum, p) => sum + p.x, 0) / leftEye.length,
                        y: leftEye.reduce((sum, p) => sum + p.y, 0) / leftEye.length
                    };
                    const rightEyeCenter = {
                        x: rightEye.reduce((sum, p) => sum + p.x, 0) / rightEye.length,
                        y: rightEye.reduce((sum, p) => sum + p.y, 0) / rightEye.length
                    };
                    const dx = rightEyeCenter.x - leftEyeCenter.x;
                    const dy = rightEyeCenter.y - leftEyeCenter.y;
                    const tiltAngle = Math.abs(Math.atan2(dy, dx) * (180 / Math.PI));
                    if (tiltAngle > 6) {
                        qualityIssues.push(`Keep face straight (tilt: ${tiltAngle.toFixed(1)}°)`);
                    } else {
                        passedChecks++;
                    }

                    // 4. Face Centering (Horizontal): Check if the nose tip is near the center horizontally
                    const faceCenterX = box.x + (box.width / 2);
                    const noseTip = nose[Math.floor(nose.length / 2)]; // Use central nose point
                    const centeredThreshold = box.width * 0.08; // 8% of face width tolerance
                    if (Math.abs(noseTip.x - faceCenterX) > centeredThreshold) {
                        qualityIssues.push('Center face horizontally');
                    } else {
                        passedChecks++;
                    }

                    // 5. Eye Openness: Use Eye Aspect Ratio (EAR)
                    const getEAR = (eye) => {
                        // EAR formula: (||p2 - p6|| + ||p3 - p5||) / (2 * ||p1 - p4||)
                        const A = distance(eye[1], eye[5]);
                        const B = distance(eye[2], eye[4]);
                        const C = distance(eye[0], eye[3]);
                        return (A + B) / (2.0 * C);
                    };
                    const leftEAR = getEAR(leftEye);
                    const rightEAR = getEAR(rightEye);
                    const minEAR = 0.25; // Threshold below which eyes are considered closed
                    if (leftEAR < minEAR || rightEAR < minEAR) {
                        qualityIssues.push('Eyes appear closed');
                    } else {
                        passedChecks++;
                    }

                    // 6. Face Size: Check if the face occupies a reasonable portion of the frame
                    const minFaceWidthRatio = 0.18;
                    const maxFaceWidthRatio = 0.82;
                    const faceWidthRatio = box.width / videoWidth;
                    if (faceWidthRatio < minFaceWidthRatio || faceWidthRatio > maxFaceWidthRatio) {
                        qualityIssues.push(faceWidthRatio < minFaceWidthRatio ?
                            'Move closer to camera' : 'Move further from camera');
                    } else {
                        passedChecks++;
                    }

                    // 7. Head Pose (Yaw): Check if the face is oriented toward the camera
                    // Compare distances from a central nose point to each eye's center.
                    const nosePoint = nose[Math.floor(nose.length / 2)];
                    const dLeft = distance(nosePoint, leftEyeCenter);
                    const dRight = distance(nosePoint, rightEyeCenter);
                    const yawRatio = dLeft / dRight;
                    if (yawRatio < 0.85 || yawRatio > 1.15) {
                        qualityIssues.push('Face not facing forward');
                    } else {
                        passedChecks++;
                    }

                    // Calculate quality score and determine if detection passes
                    const qualityScore = passedChecks / totalChecks;
                    const qualityThreshold = 0.8;

                    if (qualityScore >= qualityThreshold) {
                        return {
                            detected: true,
                            left: normalizedX,
                            top: normalizedY,
                            width: normalizedWidth,
                            height: normalizedHeight,
                            message: qualityScore > 0.9 ?
                                'Perfect! Face properly positioned' :
                                'Good! Face positioned well enough'
                        };
                    } else {
                        statusMessage = qualityIssues.length > 0 ? qualityIssues[0] : 'Improve face positioning';
                        return {
                            detected: false,
                            message: statusMessage,
                            left: normalizedX,
                            top: normalizedY,
                            width: normalizedWidth,
                            height: normalizedHeight
                        };
                    }
                } catch (checkError) {
                    console.error('Error in accurate mode quality checks:', checkError);
                    return {
                        detected: false,
                        message: 'Detection error, please try again',
                        left: normalizedX,
                        top: normalizedY,
                        width: normalizedWidth,
                        height: normalizedHeight
                    };
                }
            }
        }
        return { detected: false, message: 'Face not properly detected' };
    } catch (e) {
        console.error('Face detection error: ' + e);
        return { detected: false, message: 'Error: ' + e };
    }
};


// Image capture function
window.captureImage = function (videoElement) {
    if (!videoElement || videoElement.readyState !== 4) return null;

    const canvas = document.createElement('canvas');
    canvas.width = videoElement.videoWidth;
    canvas.height = videoElement.videoHeight;
    canvas.getContext('2d').drawImage(videoElement, 0, 0);
    return canvas.toDataURL('image/jpeg');
};
