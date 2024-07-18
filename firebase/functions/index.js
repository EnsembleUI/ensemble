const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp({
  storageBucket: "ensemble-web-studio.appspot.com",
});

const config = functions.config();
const firestore = admin.firestore();

const codemagicHeader = {
  headers: {
    "Content-type": "application/json",
    "x-auth-token": config.codemagic.token,
  },
};

exports.invokeBuild = functions.https.onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "*");

  if (request.method === "OPTIONS") {
    // Preflight request. Reply successfully:
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST");
    response.set("Access-Control-Allow-Headers", "*");
    response.status(204).send("");
    return;
  }

  try {
    const { appId, buildType } = request.body;
    const { buildConfig, fontsConfig } = await fetchDataFromFirestore(appId);

    const { variables, isValid } = getEnvVariables(
      buildConfig?.data() ?? null,
      fontsConfig?.data() ?? null,
      appId,
      response,
      buildType
    );

    if (isValid) {
      if (validateBuildType(buildType)) {
        const buildId = await startBuild(buildType, variables, "main");

        const data = {
          invokedAt: new Date(),
          buildType,
          buildId,
        };

        await firestore
          .collection("apps")
          .doc(appId)
          .collection("buildLogs")
          .add(data);

        response.status(200).send({ status: "Success", buildId });
      } else {
        response.status(400).send({
          status: "error",
          message: "Invalid buildType.",
        });
      }
    }
  } catch (error) {
    console.error("Error:", error);
    response.status(500).send({ status: "Internal Server Error" });
  }
});

exports.devInvokeBuild = functions.https.onRequest(
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Headers", "*");

    if (request.method === "OPTIONS") {
      // Preflight request. Reply successfully:
      response.set("Access-Control-Allow-Origin", "*");
      response.set("Access-Control-Allow-Methods", "POST");
      response.set("Access-Control-Allow-Headers", "*");
      response.status(204).send("");
      return;
    }

    try {
      const { appId, buildType } = request.body;
      const { buildConfig, fontsConfig } = await fetchDataFromFirestore(appId);

      const { variables, isValid } = getEnvVariables(
        buildConfig?.data() ?? null,
        fontsConfig?.data() ?? null,
        appId,
        response,
        buildType
      );

      if (isValid) {
        if (validateBuildType(buildType)) {
          const buildId = await startBuild(
            buildType,
            variables,
            "fix/optimizations"
          );

          const data = {
            invokedAt: new Date(),
            buildType,
            buildId,
          };

          await firestore
            .collection("apps")
            .doc(appId)
            .collection("buildLogs")
            .add(data);

          response.status(200).send({ status: "Success", buildId });
        } else {
          response.status(400).send({
            status: "error",
            message: "Invalid buildType.",
          });
        }
      }
    } catch (error) {
      console.error("Error:", error);
      response.status(500).send({ status: "Internal Server Error" });
    }
  }
);

function convertToStandardHexColor(hexColor) {
  hexColor = hexColor.trim().replace(/^#/, "");

  // Check if the color code starts with "0x"
  if (hexColor.startsWith("0x")) {
    hexColor = hexColor.substring(2);
  }

  // Check if the color code is in short format (e.g., #abc)
  if (hexColor.length === 3) {
    hexColor = hexColor.replace(
      /^([a-f0-9])([a-f0-9])([a-f0-9])$/i,
      function (m, r, g, b) {
        return r + r + g + g + b + b;
      }
    );
  }

  // Check if the color code is in RGB format (e.g., rgb(255, 255, 255))
  if (hexColor.startsWith("rgb(")) {
    var rgbValues = hexColor.substring(4, hexColor.length - 1).split(",");
    hexColor = rgbValues
      .map(function (value) {
        return parseInt(value.trim()).toString(16).padStart(2, "0");
      })
      .join("");
  }

  // Check if the color code is in RGBA format (e.g., rgba(255, 255, 255, 0.5))
  if (hexColor.startsWith("rgba(")) {
    var rgbaValues = hexColor.substring(5, hexColor.length - 1).split(",");
    hexColor = rgbaValues
      .slice(0, 3)
      .map(function (value) {
        return parseInt(value.trim()).toString(16).padStart(2, "0");
      })
      .join("");
  }

  // Check if the color code has exactly 6 characters and consists of hexadecimal characters
  if (hexColor.length === 6 && hexColor.match(/^[a-f0-9]{6}$/i)) {
    return "#" + hexColor;
  }

  // If the input is "ffffff" without any prefix or formatting, return it directly
  if (hexColor.length === 6 && hexColor.match(/^[a-f0-9]{6}$/i)) {
    return "#" + hexColor;
  }

  // Pad the color code with zeros if it's less than 6 characters long
  hexColor = hexColor.padEnd(6, "0");

  // Return the standard hex color code
  return "#" + hexColor;
}

async function fetchDataFromFirestore(appId) {
  const buildConfigRef = firestore
    .collection("apps")
    .doc(appId)
    .collection("artifacts")
    .doc("buildConfig");
  const fontsConfigRef = firestore
    .collection("apps")
    .doc(appId)
    .collection("artifacts")
    .doc("fontsConfig");

  const buildConfig = await buildConfigRef.get();
  const fontsConfig = await fontsConfigRef.get();

  return {
    buildConfig,
    fontsConfig,
  };
}

function getEnvVariables(buildConfig, fontsConfig, appId, response, buildType) {
  console.log(buildConfig);
  console.log(fontsConfig);
  console.log(appId);

  const {
    androidAppName,
    iOSAppName,
    splashHasIcon,
    generateKeystoreAutomatically,
    splashHasBGImage,
    getLogoFromFirebase,
    keyAlias,
    keyPassword,
    keystorePassword,
    version,
    playStoreCredentials,
    auth0Scheme,
    auth0Domain,
    branchIOUseTestKey,
    androidGoogleMapsApiKey,
    iOSGoogleMapsApiKey,
    webGoogleMapsApiKey,
    hasFileManager,
    hasConnect,
    hasContacts,
    hasAuth,
    hasCamera,
    hasLocation,
    hasDeeplink,
    hasNotification,
    hasGoogleMaps,
    androidPackageName,
    iOSPackageName,
    googlePlayApiKey,
    googlePlayTrack,
    webDescription,
    webTitle,
    webBaseHref,
    appStoreConnectApiKey,
    appStoreConnectIssuerId,
    appStoreConnectKeyIdentifier,
    splashColor,
    googleIOSClientId,
    googleAndroidClientId,
    googleWebClientId,
    googleServerClientId,
    locationDescription,
    musicDescription,
    photoLibraryDescription,
    contactsDescription,
    cameraDescription,
    inUseLocationDescription,
    alwaysUseLocationDescription,
    branchIOScheme,
    branchIOLinks,
    branchIOLiveKey,
    branchIOTestKey,
    notificationAppId,
    notificationApiKey,
    notificationProjectId,
    notificationSenderId,
  } = buildConfig;

  const validationErrors = {};

  function addError(key, message) {
    if (!validationErrors[key]) {
      validationErrors[key] = [];
    }
    validationErrors[key].push(message);
  }

  function validateRequiredField(value, fieldName, errorMessage) {
    if (!value) {
      addError(fieldName, errorMessage);
    }
  }

  function validateBoolean(value, fieldName) {
    if (typeof value !== "boolean") {
      addError(fieldName, `${fieldName} must be a boolean value.`);
    }
  }

  function validatePackageName(packageName, platform) {
    const packageNameRegex = /^[a-zA-Z][a-zA-Z\d_]*(\.[a-zA-Z][a-zA-Z\d_]*)+$/;
    if (!packageNameRegex.test(packageName)) {
      addError(
        `${platform}PackageName`,
        `Invalid ${platform} package name format.`
      );
    }
  }

  function validateVersion(version) {
    const versionRegex = /^\d+\.\d+\.\d+\+\d+$/;
    if (!versionRegex.test(version)) {
      addError(
        "version",
        "Invalid version format. Version must be in the format X.Y.Z+buildNumber (e.g., 1.0.0+1)."
      );
    }
  }

  function validateColor(color) {
    const colorRegex =
      /^(#|0x)?([a-fA-F0-9]{3}|[a-fA-F0-9]{6}|rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)|rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*(0|1|0?\.\d+)\s*\))$/;
    if (!colorRegex.test(color)) {
      addError(
        "splashColor",
        "Invalid color format. Color must be in the format #RRGGBB."
      );
    }
  }

  function validateBranchIO() {
    if (hasDeeplink) {
      if (!branchIOScheme) {
        addError(
          "branchIOScheme",
          "Branch.io scheme is required if deeplink is enabled."
        );
      }
      if (
        !branchIOLinks ||
        !Array.isArray(branchIOLinks) ||
        branchIOLinks.length === 0
      ) {
        addError(
          "branchIOLinks",
          "Branch.io links must be a non-empty array of valid URLs if deeplink is enabled."
        );
      }
      if (!branchIOLiveKey) {
        addError(
          "branchIOLiveKey",
          "Branch.io live key is required if deeplink is enabled."
        );
      }
      if (!branchIOTestKey) {
        addError(
          "branchIOTestKey",
          "Branch.io test key is required if deeplink is enabled."
        );
      }
    }
  }

  if (!buildType.includes("sha")) {
    validateRequiredField(version, "version", "Version is required.");

    validateVersion(version);
    validateColor(splashColor ?? "#ffffff");
  }

  validateBranchIO();

  if (buildType.includes("apk") || buildType.includes("aab")) {
    validateRequiredField(
      androidAppName,
      "androidAppName",
      "Android app name is required."
    );
    validateRequiredField(
      androidPackageName,
      "androidPackageName",
      "Android package name is required."
    );
    validatePackageName(androidPackageName, "android");
  }

  if (buildType.includes("ipa")) {
    validateRequiredField(
      iOSPackageName,
      "iOSPackageName",
      "iOS package name is required."
    );
    validateRequiredField(
      iOSAppName,
      "iOSAppName",
      "iOS app name is required."
    );
    validatePackageName(iOSPackageName, "iOS");

    validateRequiredField(
      appStoreConnectApiKey,
      "appStoreConnectApiKey",
      "App Store Connect API Key is required."
    );
    validateRequiredField(
      appStoreConnectIssuerId,
      "appStoreConnectIssuerId",
      "App Store Connect Issuer Id is required."
    );
    validateRequiredField(
      appStoreConnectKeyIdentifier,
      "appStoreConnectKeyIdentifier",
      "App Store Connect key identifier is required."
    );
  }

  if (buildType.includes("web")) {
    validateRequiredField(webTitle, "webTitle", "Web title is required.");
  }

  if (buildType.includes("project")) {
    validateRequiredField(
      androidAppName,
      "androidAppName",
      "Android app name is required."
    );
    validateRequiredField(
      androidPackageName,
      "androidPackageName",
      "Android package name is required."
    );
    validatePackageName(androidPackageName, "android");

    validateRequiredField(
      iOSPackageName,
      "iOSPackageName",
      "iOS package name is required."
    );
    validateRequiredField(
      iOSAppName,
      "iOSAppName",
      "iOS app name is required."
    );
    validatePackageName(iOSPackageName, "iOS");

    validateRequiredField(
      appStoreConnectApiKey,
      "appStoreConnectApiKey",
      "App Store Connect API Key is required."
    );
    validateRequiredField(
      appStoreConnectIssuerId,
      "appStoreConnectIssuerId",
      "App Store Connect Issuer Id is required."
    );
    validateRequiredField(
      appStoreConnectKeyIdentifier,
      "appStoreConnectKeyIdentifier",
      "App Store Connect key identifier is required."
    );
  }

  if (buildType.includes("sha")) {
    validateRequiredField(
      androidPackageName,
      "androidPackageName",
      "Android package name is required."
    );
    validatePackageName(androidPackageName, "android");
  }

  // validateBoolean(splashHasIcon, "splashHasIcon");
  // validateBoolean(splashHasBGImage, "splashHasBGImage");
  // validateBoolean(generateKeystoreAutomatically, "generateKeystoreAutomatically");
  // validateBoolean(getLogoFromFirebase, "getLogoFromFirebase");
  // validateBoolean(hasFileManager, "hasFileManager");
  // validateBoolean(hasConnect, "hasConnect");
  // validateBoolean(hasContacts, "hasContacts");
  // validateBoolean(hasAuth, "hasAuth");
  // validateBoolean(hasCamera, "hasCamera");
  // validateBoolean(hasLocation, "hasLocation");
  // validateBoolean(hasDeeplink, "hasDeeplink");
  // validateBoolean(hasDeeplink, "branchIOScheme");

  if (Object.keys(validationErrors).length > 0) {
    response.status(400).json({ status: "error", message: validationErrors });

    return { variables: undefined, isValid: false };
  } else {
    const variables = {
      GET_LOGO_FROM_FIREBASE: getLogoFromFirebase ?? true,
      VERSION: version ?? "",
      GENERATE_KEYSTORE: generateKeystoreAutomatically ?? true,
      SPLASH_HAS_BG_IMAGE: splashHasBGImage ?? false,
      SPLASH_HAS_ICON: splashHasIcon ?? true,
      PLAY_STORE_CREDENTIALS: playStoreCredentials ?? "",
      KEY_ALIAS: keyAlias ?? "",
      KEY_PASSWORD: keyPassword ?? "",
      KEYSTORE_PASSWORD: keystorePassword ?? "",
      AUTH0_SCHEME: auth0Scheme ?? "",
      AUTH0_DOMAIN: auth0Domain ?? "",
      ANDROID_GOOGLE_MAPS_API_KEY: androidGoogleMapsApiKey ?? "",
      WEB_GOOGLE_MAPS_API_KEY: webGoogleMapsApiKey ?? "",
      IOS_GOOGLE_MAPS_API_KEY: iOSGoogleMapsApiKey ?? "",
      HAS_FILE_MANAGER: hasFileManager ?? false,
      HAS_CAMERA: hasCamera ?? false,
      HAS_CONNECT: hasConnect ?? false,
      HAS_CONTACTS: hasContacts ?? false,
      HAS_LOCATION: hasLocation ?? false,
      HAS_DEEPLINK: hasDeeplink ?? false,
      HAS_NOTIFICATION: hasNotification ?? false,
      HAS_GOOGLE_MAPS: hasGoogleMaps ?? false,
      HAS_AUTH: hasAuth ?? false,
      BRANCH_IO_USE_TEST_KEY: branchIOUseTestKey ?? false,
      GOOGLE_IOS_CLIENT_ID: googleIOSClientId ?? "",
      GOOGLE_ANDROID_CLIENT_ID: googleAndroidClientId ?? "",
      GOOGLE_WEB_CLIENT_ID: googleWebClientId ?? "",
      GOOGLE_SERVER_CLIENT_ID: googleServerClientId ?? "",
      ANDROID_PACKAGE_NAME: androidPackageName ?? "",
      ANDROID_APP_NAME: androidAppName ?? "",
      IOS_APP_NAME: iOSAppName ?? "",
      APP_ID: appId,
      IOS_PACKAGE_NAME: iOSPackageName ?? "",
      WEB_DESCRIPTION: webDescription ?? "A Ensemble Application",
      WEB_TITLE: webTitle ?? "",
      WEB_BASE_HREF: webBaseHref ?? "/",
      GOOGLE_PLAY_API_KEY: googlePlayApiKey ?? "",
      GOOGLE_PLAY_TRACK: googlePlayTrack ?? "production",
      APP_STORE_CONNECT_PRIVATE_KEY: appStoreConnectApiKey ?? "",
      APP_STORE_CONNECT_ISSUER_ID: appStoreConnectIssuerId ?? "",
      APP_STORE_CONNECT_KEY_IDENTIFIER: appStoreConnectKeyIdentifier ?? "",
      LOCATION_DESCRIPTION: locationDescription ?? "",
      MUSIC_DESCRIPTION: musicDescription ?? "",
      PHOTO_LIBRARY_DESCRIPTION: photoLibraryDescription ?? "",
      CONTACTS_DESCRIPTION: contactsDescription ?? "",
      CAMERA_DESCRIPTION: cameraDescription ?? "",
      IN_USE_LOCATION_DESCRIPTION: inUseLocationDescription ?? "",
      ALWAYS_USE_LOCATION_DESCRIPTION: alwaysUseLocationDescription ?? "",
      NOTIFICATION_APP_ID: notificationAppId ?? "",
      NOTIFICATION_API_KEY: notificationApiKey ?? "",
      NOTIFICATION_PROJECT_ID: notificationProjectId ?? "",
      NOTIFICATION_SENDER_ID: notificationSenderId ?? "",
      BRANCH_IO_SCHEME: branchIOScheme,
      BRANCH_IO_LINKS: branchIOLinks,
      BRANCH_IO_LIVE_KEY: branchIOLiveKey,
      BRANCH_IO_TEST_KEY: branchIOTestKey,
      SPLASH_COLOR: convertToStandardHexColor(splashColor ?? "#ffffff"),
      FONTS: JSON.stringify(fontsConfig ?? "") ?? "",
    };

    return { variables, isValid: true };
  }
}

function validateBuildType(buildType) {
  const validBuildTypes = [
    "build-project",
    "build-apk",
    "build-ipa",
    "build-aab",
    "build-web-canvas-kit",
    "build-web-html",
    "build-web-wasm",
    "build-aab-and-ipa",
    "build-apk-and-aab",
    "deploy-ipa",
    "deploy-aab",
    "get-sha-key",
    "deploy-aab-and-ipa",
  ];
  return buildType && validBuildTypes.includes(buildType);
}

async function startBuild(buildType, envVariables, branch) {
  var res = await axios.post(
    "https://api.codemagic.io/builds",
    {
      workflowId: buildType,
      appId: config.codemagic.app_id,
      branch: branch,
      environment: {
        variables: envVariables,
        groups: ["CREDS"],
      },
    },
    codemagicHeader
  );

  var { buildId } = res.data;

  return buildId;
}

exports.updateBuildConfig = functions.https.onRequest(
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Headers", "*");

    if (request.method === "OPTIONS") {
      // Preflight request. Reply successfully:
      response.set("Access-Control-Allow-Origin", "*");
      response.set("Access-Control-Allow-Methods", "POST");
      response.set("Access-Control-Allow-Headers", "*");
      response.status(204).send("");
      return;
    }

    try {
      if (request.method !== "POST") {
        return response.status(405).end();
      }

      const { appId, parameter, value } = request.body;
      let data = {};

      data[parameter] = value;

      const result = await firestore
        .collection("apps")
        .doc(appId)
        .collection("artifacts")
        .doc("buildConfig")
        .set(data, { merge: true });

      response.status(200).send({ status: "Success", data: result });
    } catch (error) {
      console.error("Error:", error);
      response.status(500).send({ status: "Internal Server Error" });
    }
  }
);

exports.addFont = functions.https.onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "*");

  if (request.method === "OPTIONS") {
    // Preflight request. Reply successfully:
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST");
    response.set("Access-Control-Allow-Headers", "*");
    response.status(204).send("");
    return;
  }

  try {
    if (request.method !== "POST") {
      return response.status(405).end();
    }

    const { appId, fontFamily, weight, name, type, fileName } = request.body;

    const fontsConfigRef = firestore
      .collection("apps")
      .doc(appId)
      .collection("artifacts")
      .doc("fontsConfig");

    const fontsConfig = await fontsConfigRef.get();
    let fontsData = fontsConfig.data() || {};

    console.log(fontsData);

    if (!fontsData[fontFamily]) {
      fontsData[fontFamily] = {};
    }

    fontsData[fontFamily][name] = { weight, fileName, type };

    console.log(fontsData);

    const result = await firestore
      .collection("apps")
      .doc(appId)
      .collection("artifacts")
      .doc("fontsConfig")
      .set(fontsData, { merge: true });

    response.status(200).send({ status: "Success", data: result });
  } catch (error) {
    console.error("Error:", error);
    response.status(500).send({ status: "Internal Server Error" });
  }
});

exports.deleteFont = functions.https.onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "*");

  if (request.method === "OPTIONS") {
    // Preflight request. Reply successfully:
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST");
    response.set("Access-Control-Allow-Headers", "*");
    response.status(204).send("");
    return;
  }

  try {
    if (request.method !== "POST") {
      return response.status(405).end();
    }

    const { appId, fontFamily, fontName } = request.body;

    const fontsConfigRef = firestore
      .collection("apps")
      .doc(appId)
      .collection("artifacts")
      .doc("fontsConfig");

    const fontsConfig = await fontsConfigRef.get();
    let fontsData = fontsConfig.data();

    delete fontsData[fontFamily][fontName];

    console.log(fontsData);

    const result = await firestore
      .collection("apps")
      .doc(appId)
      .collection("artifacts")
      .doc("fontsConfig")
      .update(fontsData, { merge: true });

    response.status(200).send({ status: "Success", data: result });
  } catch (error) {
    console.error("Error:", error);
    response.status(500).send({ status: "Internal Server Error" });
  }
});

exports.getFonts = functions.https.onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "*");

  console.log(request.method);
  console.log(request.body);

  if (request.method === "OPTIONS") {
    // Preflight request. Reply successfully:
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "*");
    response.set("Access-Control-Allow-Headers", "*");
    response.status(204).send("");
    return;
  }

  try {
    const { appId } = request.body;

    const fontsConfigRef = firestore
      .collection("apps")
      .doc(appId)
      .collection("artifacts")
      .doc("fontsConfig");

    const fontsConfig = await fontsConfigRef.get();

    response.status(200).send({ status: "Success", fonts: fontsConfig.data() });
  } catch (error) {
    console.error("Error:", error);
    response.status(500).send({ status: "Internal Server Error" });
  }
});

exports.getBuildConfig = functions.https.onRequest(
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Headers", "*");

    console.log(request.method);
    console.log(request.body);

    if (request.method === "OPTIONS") {
      // Preflight request. Reply successfully:
      response.set("Access-Control-Allow-Origin", "*");
      response.set("Access-Control-Allow-Methods", "*");
      response.set("Access-Control-Allow-Headers", "*");
      response.status(204).send("");
      return;
    }

    try {
      const { appId } = request.body;

      const buildConfigRef = firestore
        .collection("apps")
        .doc(appId)
        .collection("artifacts")
        .doc("buildConfig");

      const buildConfig = await buildConfigRef.get();

      response
        .status(200)
        .send({ status: "Success", buildConfig: buildConfig.data() });
    } catch (error) {
      console.error("Error:", error);
      response.status(500).send({ status: "Internal Server Error" });
    }
  }
);
