import 'dart:io';
import '../utils.dart';
import '../utils/firebase_utils.dart';

void main(List<String> arguments) async {
  try {
    // Parse and validate arguments
    List<String> platforms = getPlatforms(arguments);
    String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');
    String moengageAppId =
        getArgumentValue(arguments, 'moengage_workspace_id', required: true) ??
            '';
    String enableConsoleLogs =
        getArgumentValue(arguments, 'enableConsoleLogs') ?? 'true';

    final statements = {
      'moduleStatements': [
        "import 'package:ensemble_moengage/moengage.dart';",
        'GetIt.I.registerSingleton<MoEngageModule>(MoEngageImpl());',
        "import 'dart:io';",
        "import 'package:flutter/foundation.dart';",
      ],
      'useStatements': [
        'static const useMoEngage = true;',
      ],
    };

    // Update Firebase configuration
    updateFirebaseInitialization(platforms, arguments);
    updateFirebaseConfig(platforms, arguments);

    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update pubspec.yaml
    final pubspecDependencies = [
      {
        'statement': '''
ensemble_moengage:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/moengage''',
        'regex':
            r'#\s*ensemble_moengage:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/moengage',
      }
    ];
    updatePubspec(pubspecDependencies);

    // Update MoEngage module registration with workspaceId and logs
    String modulesContent = readFileContent(ensembleModulesFilePath);
    modulesContent = modulesContent.replaceAll(
        'GetIt.I.registerSingleton<MoEngageModule>(MoEngageImpl());',
        'GetIt.I.registerSingleton<MoEngageModule>(MoEngageImpl(workspaceId: \'$moengageAppId\', enableLogs: $enableConsoleLogs));');
    writeFileContent(ensembleModulesFilePath, modulesContent);

    // Update ensemble.properties file
    updatePropertiesFile("moengageWorkspaceId", moengageAppId);

    // Platform specific updates
    if (platforms.contains('android')) {
      await _updateAndroidConfiguration(arguments);
    }

    if (platforms.contains('ios')) {
      // Get all updates
      final updates = [
        getMoEngageImportUpdate(),
        getMoEngageInitUpdate(moengageAppId),
        getMoEngageFunctionsUpdate(),
      ];

      updateAppDelegate(updates);
    }

    print(
        'MoEngage module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}

Future<void> _updateAndroidConfiguration(List<String> arguments) async {
  final packageId = getPropertyValue('appId');
  final kotlinPath = getKotlinPath(packageId);

  // Create Kotlin files
  await _createKotlinFiles(kotlinPath, packageId);

  // update gradle files
  _updateGradleFile();

  // Update AndroidManifest.xml
  await modifyAndroidManifest(permissions: [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'
  ], applicationAttributes: {
    'android:name': '.MyApplication'
  }, intentFilters: [
    {
      'identifier': '<!-- MoEngage Deep Linking -->',
      'content': '''
<!-- MoEngage Deep Linking -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:host="moenagesample.com"
                    android:scheme="moengage" />
            </intent-filter>'''
    }
  ], services: [
    {
      'identifier': 'com.moengage.firebase.MoEFireBaseMessagingService',
      'content': '''
<service
                android:name="com.moengage.firebase.MoEFireBaseMessagingService"
                android:exported="false">
                <intent-filter>
                    <action android:name="com.google.firebase.MESSAGING_EVENT" />
                </intent-filter>
            </service>'''
    }
  ], activities: [
    {
      'identifier': 'com.moengage.pushbase.activities.PushTracker',
      'content': '''
<activity
                android:name="com.moengage.pushbase.activities.PushTracker"
                android:launchMode="singleInstance"
                tools:replace="android:launchMode" />'''
    }
  ]);
}

Future<void> _createKotlinFiles(String kotlinPath, String packageId) async {
  await createKotlinFile('$kotlinPath/CustomPushListener.kt',
      _getCustomPushListenerContent(packageId));

  await createKotlinFile(
      '$kotlinPath/MyApplication.kt', _getMyApplicationContent(packageId));

  await createKotlinFile(
      '$kotlinPath/MainActivity.kt', _getMainActivityContent(packageId));
}

Future<void> _updateGradleFile() async {
  // Add MoEngage specific dependencies
  addImplementationDependency(
      "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
  addImplementationDependency(
      "implementation 'com.moengage:moe-android-sdk:12.8.01'");
  addImplementationDependency(
      "implementation 'com.google.firebase:firebase-messaging:23.4.1'");
  addImplementationDependency(
      "implementation 'androidx.lifecycle:lifecycle-process:2.7.0'");
  addImplementationDependency("implementation 'androidx.core:core:1.6.0'");
  addImplementationDependency(
      "implementation 'androidx.appcompat:appcompat:1.3.1'");
  addImplementationDependency(
      "implementation 'com.github.bumptech.glide:glide:4.9.0'");
}

// Kotlin file content templates
String _getCustomPushListenerContent(String packageId) => '''
package $packageId

import android.app.Activity
import android.os.Bundle
import com.moengage.core.internal.logger.Logger
import com.moengage.core.model.AccountMeta
import com.moengage.plugin.base.push.PluginPushCallback

class CustomPushListener(accountMeta: AccountMeta) : PluginPushCallback(accountMeta) {
    private val tag = "CustomPushListener"

    override fun onNotificationClick(activity: Activity, payload: Bundle): Boolean {
        Logger.print { "\$tag onNotificationClick() : " }
        return super.onNotificationClick(activity, payload)
    }
}''';

String _getMyApplicationContent(String packageId) => '''
package $packageId

import com.moengage.core.DataCenter
import com.moengage.core.LogLevel
import com.moengage.core.MoEngage
import com.moengage.core.config.LogConfig
import com.moengage.core.config.FcmConfig
import com.moengage.core.config.MoEngageEnvironmentConfig
import com.moengage.core.config.NotificationConfig
import com.moengage.core.config.PushKitConfig
import com.moengage.core.model.AccountMeta
import com.moengage.core.model.SdkState
import com.moengage.core.model.environment.MoEngageEnvironment
import com.moengage.flutter.MoEInitializer
import com.moengage.pushbase.MoEPushHelper
import android.app.Application

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    
        val moEngage = MoEngage.Builder(this, BuildConfig.MOENGAGE_WORKSPACE_ID, DataCenter.DATA_CENTER_1)
            .configureFcm(FcmConfig(true))
            .configurePushKit(PushKitConfig(true))
            .configureMoEngageEnvironment(MoEngageEnvironmentConfig(MoEngageEnvironment.DEFAULT))
            .configureNotificationMetaData(
                NotificationConfig(
                    R.mipmap.ic_launcher,
                    R.mipmap.ic_launcher,
                    notificationColor = -1,
                    isMultipleNotificationInDrawerEnabled = false,
                    isBuildingBackStackEnabled = true,
                    isLargeIconDisplayEnabled = true
                )
            )

        MoEInitializer.initialiseDefaultInstance(this, moEngage)
    }
}''';

String _getMainActivityContent(String packageId) => '''
package $packageId

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import com.moengage.flutter.MoEFlutterHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        processIntent(intent)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        Log.d(TAG, "onConfigurationChanged(): \${newConfig.orientation}")
        MoEFlutterHelper.getInstance().onConfigurationChanged()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        processIntent(intent)
    }

    private fun processIntent(intent: Intent?) {
        if (intent == null) return
        Log.d(TAG, "processIntent(): \${intent.data}")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
}''';

// Get MoEngage import pattern updates
Map<String, String> getMoEngageImportUpdate() {
  return {
    'pattern': r'import\s+UIKit\s*\nimport\s+Flutter\s*\n',
    'replacement': '''import UIKit
import Flutter
import moengage_flutter_ios
import MoEngageSDK
import MoEngageInApps
import MoEngageMessaging

'''
  };
}

// Get MoEngage initialization pattern updates
Map<String, String> getMoEngageInitUpdate(String moengageAppId) {
  return {
    'pattern':
        r'if\s+#available\(iOS\s+10\.0,\s*\*\)\s*{\s*\n\s*UNUserNotificationCenter\.current\(\)\.delegate\s*=\s*self\s+as\s+UNUserNotificationCenterDelegate\s*\n\s*}',
    'replacement': '''// MoEngage initialization
    let sdkConfig = MoEngageSDKConfig(withAppID: "$moengageAppId")
    sdkConfig.appGroupID = "group.com.alphadevs.MoEngage.NotificationServices"
    sdkConfig.consoleLogConfig = MoEngageConsoleLogConfig(isLoggingEnabled: true, loglevel: .verbose)

    MoEngageSDKCore.sharedInstance.enableAllLogs()
    MoEngageInitializer.sharedInstance.initializeDefaultInstance(sdkConfig, launchOptions: launchOptions)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }'''
  };
}

// Get MoEngage functions pattern updates
Map<String, String> getMoEngageFunctionsUpdate() {
  return {
    'pattern':
        r'override\s+func\s+application\(\s*_\s+app:\s*UIApplication,\s*open\s+url:\s*URL,\s*options:\s*\[UIApplication\.OpenURLOptionsKey\s*:\s*Any\]\s*=\s*\[:\]\)\s*->\s*Bool\s*{\s*\n\s*//\s*Calling\s+flutter\s+method\s*"urlOpened"\s*from\s*iOS\s*\n\s*methodChannel\?\.invokeMethod\("urlOpened",\s*arguments:\s*url\.absoluteString\)\s*\n\s*return\s+true\s*\n\s*}\s*\n}',
    'replacement':
        '''override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Calling flutter method "urlOpened" from iOS
    methodChannel?.invokeMethod("urlOpened", arguments: url.absoluteString)
    return true
  }

  // MoEngage notification handling functions
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      MoEngageSDKMessaging.sharedInstance.setPushToken(deviceToken)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.alert, .sound])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
      MoEngageSDKMessaging.sharedInstance.userNotificationCenter(center, didReceive: response)
      completionHandler()
  }

  override func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
      print("Opening Universal link", userActivityType)
      return false
  }
}'''
  };
}