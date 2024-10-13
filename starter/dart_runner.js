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
        parameters: []
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
        parameters: []
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
function findScript(name) {
    return scripts.find(script => script.name === name) ||
        modules.find(module => module.name === name);
}

// Parse arguments into script names and key-value pairs
function parseArguments(args) {
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
}

// Generate Dart arguments, filtering only allowed parameters
function generateArgsForScript(scriptObj, argsArray) {
    return argsArray
        .map(arg => {
            const [key, value] = arg.split('=');

            // Only include arguments that are in the scriptObj's parameters or common parameters
            const allowedKeys = scriptObj.parameters.map(p => p.key).concat(commonParameters.map(p => p.key));
            if (allowedKeys.includes(key)) {
                return `${key}=${value}`;
            }

            return null;
        })
        .filter(arg => arg !== null)
        .join(' ');
}

// Check for missing arguments and ask for them
async function checkAndAskForMissingArgs(modules, argsArray) {
    const providedArgs = argsArray.map(arg => arg.split('=')[0]);
    let args = Object.fromEntries(argsArray.map(arg => arg.split('=')));
    const askedParameters = new Set();
    let prompts = [];

    // Detect CI environment
    const isCI = process.env.CI === 'true';

    // Ask for missing common parameters
    for (const param of commonParameters) {
        if (!providedArgs.includes(param.key)) {
            // If in CI, throw error if required params are missing
            if (isCI) {
                throw new Error(`Missing required parameter "${param.key}".`);
            }

            prompts.push({
                type: param.type || 'input',
                name: param.key,
                message: param.question,
                choices: param.choices || []
            });
            askedParameters.add(param.key);
        }
    }

    // Prompt for missing common parameters
    if (prompts.length > 0 && !isCI) {
        const commonAnswers = await inquirer.prompt(prompts);
        Object.entries(commonAnswers).forEach(([key, value]) => {
            if (Array.isArray(value)) {
                value = value.join(',');
            }
            argsArray.push(`${key}=${value}`);
            args[key] = value;
        });
    }

    // Reset prompts for module-specific parameters
    prompts = [];
    const allParameters = modules.flatMap(module => module.parameters);

    // Loop through each module parameter and check if it's required and missing
    for (const param of allParameters) {
        if (askedParameters.has(param.key) || providedArgs.includes(param.key)) continue;

        const isRequired = typeof param.required === 'function' ? param.required(args) : param.required;

        if (isRequired) {
            if (isCI) {
                throw new Error(`Missing required parameter "${param.key}" for CI environment.`);
            }

            const promptType = param.type || 'input';
            prompts.push({
                type: promptType,
                name: param.key,
                message: param.question,
                choices: param.choices || [],
            });
            askedParameters.add(param.key);
        }
    }

    // If there are required parameters that haven't been provided, ask for them
    if (prompts.length > 0 && !isCI) {
        const moduleAnswers = await inquirer.prompt(prompts);

        // Transform 'yes'/'no' to true/false
        const transformedAnswers = Object.entries(moduleAnswers).reduce((acc, [key, value]) => {
            if (value === 'yes') value = true;
            if (value === 'no') value = false;
            acc[key] = value;
            return acc;
        }, {});

        Object.entries(transformedAnswers).forEach(([key, value]) => {
            argsArray.push(`${key}=${value}`);
            args[key] = value;
        });
    }

    // Throw an error if required arguments are still missing
    for (const param of allParameters) {
        const isRequired = typeof param.required === 'function' ? param.required(args) : param.required;

        if (isRequired && !providedArgs.includes(param.key) && !args[param.key]) {
            throw new Error(`Missing required parameter "${param.key}".`);
        }
    }

    return argsArray;
}

// Execute a Dart script
function runScript(scriptObj, argsArray, callback = () => { }) {
    const dartArgs = generateArgsForScript(scriptObj, argsArray);
    const command = `dart run ${scriptObj.path} ${dartArgs}`;
    console.log(`Running: ${command}`);

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error running ${scriptObj.name}: ${error.message}`);
            return callback(error);
        }
        if (stderr) {
            console.error(`Stderr from ${scriptObj.name}: ${stderr}`);
        }
        console.log(stdout);
        callback();
    });
}

// Function to run multiple Dart scripts in sequence (for modules)
async function runScriptsSequentially(scriptsToRun, argsArray) {
    let index = 0;

    async function next(err) {
        if (err) {
            console.error('Stopping execution due to an error.');
            process.exit(1);
        }

        if (index < scriptsToRun.length) {
            const scriptObj = scriptsToRun[index++];

            runScript(scriptObj, argsArray, next);
        } else {
            process.exit(0);
        }
    }

    await next();
}

// Select modules interactively
async function selectModules() {
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
}

// Main function
async function main() {
    try {
        const [firstArg, ...restArgs] = process.argv.slice(2);

        if (firstArg === 'enable') {
            const { scripts: scriptsToRun, argsArray } = parseArguments(restArgs);
            let selectedModules;

            if (scriptsToRun.length === 0) {
                selectedModules = await selectModules();
            } else {
                selectedModules = scriptsToRun.map(findScript);
            }

            // Ask for missing arguments for all selected modules
            const updatedArgsArray = await checkAndAskForMissingArgs(selectedModules, argsArray);

            // Execute scripts sequentially
            await runScriptsSequentially(selectedModules, updatedArgsArray);
        } else {
            const scriptObj = findScript(firstArg);

            if (scriptObj) {
                const { argsArray } = parseArguments(restArgs);
                const updatedArgsArray = await checkAndAskForMissingArgs([scriptObj], argsArray);
                runScript(scriptObj, updatedArgsArray, (err) => {
                    if (err) {
                        process.exit(1);
                    } else {
                        process.exit(0);
                    }
                });
            } else {
                throw new Error(`Command "${firstArg}" not found.`);
            }
        }
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

main();
