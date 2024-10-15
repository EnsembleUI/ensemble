import { exec } from 'child_process';
import inquirer from 'inquirer';

// Common parameters available across scripts and modules
const commonParameters = [
    {
        key: 'platform',
        question: 'Which platform(s) are you targeting?',
        type: 'checkbox',
        choices: ['ios', 'android', 'web'],
        required: true,
    }
];

// Modules (called with `enable` command)
const modules = [
    {
        name: 'camera',
        path: 'scripts/modules/enable_camera.dart',
        parameters: [
            { key: 'qrcode_enabled', question: 'Do you want to enable QR code scanning? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'camera_description', question: 'Please provide a camera usage description for iOS: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'files',
        path: 'scripts/modules/enable_files.dart',
        parameters: [
            { key: 'photo_library_description', question: 'Please provide a description for accessing the photo library: ', required: (args) => args.platform.includes('ios') },
            { key: 'music_description', question: 'Please provide a description for accessing music files: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'contacts',
        path: 'scripts/modules/enable_contacts.dart',
        parameters: [
            { key: 'contacts_description', question: 'Please provide a description for accessing contacts: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'connect',
        path: 'scripts/modules/enable_connect.dart',
        parameters: [
            { key: 'camera_description', question: 'Please provide a camera usage description: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'location',
        path: 'scripts/modules/enable_location.dart',
        parameters: [
            { key: 'in_use_location_description', question: 'Please provide a description for using location services while the app is in use: ', required: (args) => args.platform.includes('ios') },
            { key: 'always_use_location_description', question: 'Please provide a description for using location services always: ', required: (args) => args.platform.includes('ios') },
            { key: 'google_maps', question: 'Are you enabling Google Maps? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'google_maps_api_key_ios', question: 'Please provide your Google Maps API key for iOS ', required: (args) => args.google_maps === true && args.platform.includes('ios') },
            { key: 'google_maps_api_key_android', question: 'Please provide your Google Maps API key for Android ', required: (args) => args.google_maps === true && args.platform.includes('android') },
            { key: 'google_maps_api_key_web', question: 'Please provide your Google Maps API key for Web ', required: (args) => args.google_maps === true && args.platform.includes('web') }
        ]
    },
    {
        name: 'deeplink',
        path: 'scripts/modules/enable_deeplink.dart',
        parameters: [
            { key: 'branch_live_key', question: 'Please provide the live Branch.io key: ', required: true },
            { key: 'branch_test_key', question: 'Please provide the test Branch.io key: ', required: true },
            { key: 'use_test_key', question: 'Are you using the test key? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'scheme', question: 'Please provide the URI scheme for deeplinking: ', required: true },
            { key: 'links', question: 'Please provide a comma-separated list of deeplink URLs: ', required: true }
        ]
    },
    {
        name: 'firebaseAnalytics',
        path: 'scripts/modules/enable_firebase_analytics.dart',
        parameters: [
            { key: 'android_api_key', question: 'Please provide your Firebase Android API key: ', required: (args) => args.platform.includes('android') },
            { key: 'android_app_id', question: 'Please provide your Firebase Android App ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_messaging_sender_id', question: 'Please provide your Firebase Android Messaging Sender ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_project_id', question: 'Please provide your Firebase Android Project ID: ', required: (args) => args.platform.includes('android') },
            { key: 'ios_api_key', question: 'Please provide your Firebase iOS API key: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_app_id', question: 'Please provide your Firebase iOS App ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_messaging_sender_id', question: 'Please provide your Firebase iOS Messaging Sender ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_project_id', question: 'Please provide your Firebase iOS Project ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'web_api_key', question: 'Please provide your Firebase Web API key: ', required: (args) => args.platform.includes('web') },
            { key: 'web_app_id', question: 'Please provide your Firebase Web App ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_auth_domain', question: 'Please provide your Firebase Web Auth Domain: ', required: (args) => args.platform.includes('web') },
            { key: 'web_messaging_sender_id', question: 'Please provide your Firebase Web Messaging Sender ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_project_id', question: 'Please provide your Firebase Web Project ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_storage_bucket', question: 'Please provide your Firebase Web Storage Bucket: ', required: (args) => args.platform.includes('web') },
            { key: 'web_measurement_id', question: 'Please provide your Firebase Web Measurement ID: ', required: (args) => args.platform.includes('web') },
            { key: 'enable_console_logs', question: 'Do you want to enable Firebase console logs? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true }
        ]
    },
    {
        name: 'notifications',
        path: 'scripts/modules/enable_notifications.dart',
        parameters: [
            { key: 'android_api_key', question: 'Please provide your Firebase Android API key: ', required: (args) => args.platform.includes('android') },
            { key: 'android_app_id', question: 'Please provide your Firebase Android App ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_messaging_sender_id', question: 'Please provide your Firebase Android Messaging Sender ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_project_id', question: 'Please provide your Firebase Android Project ID: ', required: (args) => args.platform.includes('android') },
            { key: 'ios_api_key', question: 'Please provide your Firebase iOS API key: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_app_id', question: 'Please provide your Firebase iOS App ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_messaging_sender_id', question: 'Please provide your Firebase iOS Messaging Sender ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_project_id', question: 'Please provide your Firebase iOS Project ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'web_api_key', question: 'Please provide your Firebase Web API key: ', required: (args) => args.platform.includes('web') },
            { key: 'web_app_id', question: 'Please provide your Firebase Web App ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_auth_domain', question: 'Please provide your Firebase Web Auth Domain: ', required: (args) => args.platform.includes('web') },
            { key: 'web_messaging_sender_id', question: 'Please provide your Firebase Web Messaging Sender ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_project_id', question: 'Please provide your Firebase Web Project ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_storage_bucket', question: 'Please provide your Firebase Web Storage Bucket: ', required: (args) => args.platform.includes('web') },
            { key: 'web_measurement_id', question: 'Please provide your Firebase Web Measurement ID: ', required: (args) => args.platform.includes('web') }
        ]
    },
    {
        name: 'bracket',
        path: 'scripts/modules/enable_bracket.dart',
        parameters: []
    },
    {
        name: 'networkInfo',
        path: 'scripts/modules/enable_network_info.dart',
        parameters: []
    },
    {
        name: 'chat',
        path: 'scripts/modules/enable_chat.dart',
        parameters: []
    },
    {
        name: 'auth',
        path: 'scripts/modules/enable_auth.dart',
        parameters: [
            { key: 'ios_client_id', question: 'Please provide your iOS client ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'android_client_id', question: 'Please provide your Android client ID: ', required: (args) => args.platform.includes('android') },
            { key: 'web_client_id', question: 'Please provide your Web client ID: ', required: (args) => args.platform.includes('web') },
            { key: 'server_client_id', question: 'Please provide your server client ID: ', required: true }
        ]
    }
];

// Custom Scripts (standalone Dart scripts)
const scripts = [
    {
        name: 'generateKeystore',
        path: 'scripts/generate_keystore.dart',
        parameters: [
            { key: 'storePassword', question: 'Please provide the store password: ', required: true },
            { key: 'keyPassword', question: 'Please provide the key password: ', required: true },
            { key: 'keyAlias', question: 'Please provide the key alias: ', required: true }
        ]
    },
    {
        name: 'getShaKeys',
        path: 'scripts/get_sha_keys.dart',
        parameters: []
    }
];

// Find the script object by name
const findScript = (name) =>
    scripts.find(script => script.name === name) || modules.find(module => module.name === name);

// Parse arguments into script names and key-value pairs
const parseArguments = (args) => {
    const scripts = [];
    const argsArray = [];

    args.forEach(arg => {
        if (arg.includes('=')) {
            argsArray.push(arg);
        } else {
            scripts.push(arg);
        }
    });

    return { scripts, argsArray };
};

// Generate Dart arguments, filtering only allowed parameters
const generateArgsForScript = (scriptObj, argsArray) => {
    const allowedKeys = new Set([
        ...scriptObj.parameters.map(p => p.key),
        ...commonParameters.map(p => p.key)
    ]);

    return argsArray
        .filter(arg => allowedKeys.has(arg.split('=')[0]))
        .join(' ');
};

// Helper function to ask missing arguments
const askForMissingArgs = async (params, args, providedArgs, isCI) => {
    const prompts = [];

    for (const param of params) {
        const isRequired = typeof param.required === 'function' ? param.required(args) : param.required;

        if (isRequired && !providedArgs.includes(param.key) && !args[param.key]) {
            if (isCI) {
                throw new Error(`Missing required parameter "${param.key}".`);
            }
            prompts.push({
                type: param.type || 'input',
                name: param.key,
                message: param.question,
                choices: param.choices || [],
            });
        }
    }

    if (prompts.length > 0 && !isCI) {
        const answers = await inquirer.prompt(prompts);
        return Object.entries(answers).reduce((acc, [key, value]) => {
            acc[key] = value === 'yes' ? 'true' : value === 'no' ? 'false' : value;
            return acc;
        }, {});
    }

    return {};
};

// Check for missing arguments and ask for them
const checkAndAskForMissingArgs = async (modules, argsArray) => {
    const providedArgs = argsArray.map(arg => arg.split('=')[0]);
    let args = Object.fromEntries(argsArray.map(arg => arg.split('=')));

    const isCI = process.env.CI === 'true';

    const commonAnswers = await askForMissingArgs(commonParameters, args, providedArgs, isCI);
    Object.assign(args, commonAnswers);

    const allModuleParams = modules.flatMap(module => module.parameters);
    const moduleAnswers = await askForMissingArgs(allModuleParams, args, providedArgs, isCI);
    Object.assign(args, moduleAnswers);

    return argsArray.concat(
        ...Object.entries({ ...commonAnswers, ...moduleAnswers }).map(([key, value]) => `${key}=${value}`)
    );
};

// Centralized error handling
const handleError = (error, message = 'An error occurred') => {
    console.error(`${message}: ${error.message}`);
    process.exitCode = 1;
};

// Execute a Dart script
const runScript = (scriptObj, argsArray) => {
    return new Promise((resolve, reject) => {
        const dartArgs = generateArgsForScript(scriptObj, argsArray);
        const command = `dart run ${scriptObj.path} ${dartArgs}`;
        console.log(`Running: ${command}`);

        exec(command, (error, stdout, stderr) => {
            if (error) {
                handleError(error, `Error running ${scriptObj.name}`);
                return reject(error);
            }
            if (stderr) {
                console.error(`Stderr from ${scriptObj.name}: ${stderr}`);
            }
            console.log(stdout);

            // Automatically format the Dart files after the script runs
            exec('dart format .', (formatError, formatStdout, formatStderr) => {
                if (formatError) {
                    handleError(formatError, 'Error running dart format');
                    return reject(formatError);
                }
                if (formatStderr) {
                    console.error(`Stderr from dart format: ${formatStderr}`);
                }
                console.log(`Formatting result: ${formatStdout}`);
                resolve();
            });
        });
    });
};

// Run multiple Dart scripts sequentially
const runScriptsSequentially = (scriptsToRun, argsArray) =>
    scriptsToRun.reduce(
        (promiseChain, scriptObj) => promiseChain.then(() => runScript(scriptObj, argsArray)),
        Promise.resolve()
    );

// Select modules interactively
const selectModules = async () => {
    const choices = modules.map(module => ({ name: module.name, value: module.name }));

    const { selectedModules } = await inquirer.prompt([
        {
            type: 'checkbox',
            name: 'selectedModules',
            message: 'Please select the modules you want to enable:',
            choices,
        }
    ]);

    return selectedModules.map(name => findScript(name));
};

// Main function
const main = async () => {
    try {
        const [firstArg, ...restArgs] = process.argv.slice(2);
        const bypass = restArgs.includes('bypass-questions');

        if (firstArg === 'enable') {
            const { scripts: scriptsToRun, argsArray } = parseArguments(restArgs);
            let selectedModules;

            if (scriptsToRun.length === 0) {
                selectedModules = await selectModules();
            } else {
                selectedModules = scriptsToRun.map(findScript);
            }

            // Ask for missing arguments for all selected modules
            const updatedArgsArray = !bypass
                ? await checkAndAskForMissingArgs(selectedModules, argsArray)
                : argsArray;

            await runScriptsSequentially(selectedModules, updatedArgsArray);
        } else {
            const scriptObj = findScript(firstArg);

            if (scriptObj) {
                const { argsArray } = parseArguments(restArgs);

                // Ask for missing arguments for standalone script
                const updatedArgsArray = !bypass
                    ? await checkAndAskForMissingArgs([scriptObj], argsArray)
                    : argsArray;

                runScript(scriptObj, updatedArgsArray)
                    .then(() => process.exit(0))
                    .catch(() => process.exit(1));
            } else {
                throw new Error(`Command "${firstArg}" not found.`);
            }
        }
    } catch (error) {
        handleError(error);
    }
};

main();
