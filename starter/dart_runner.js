const { exec } = require('child_process');
const readline = require('readline');

// Common parameters available across scripts and modules
const commonParameters = [
    { key: 'platform', question: 'Which platform are you targeting? (e.g., ios, android, web): ', required: true }
];

// Modules (called with `enable` command)
const modules = [
    {
        name: 'camera',
        path: 'scripts/modules/enable_camera.dart',
        parameters: [
            { key: 'camera_description', question: 'Please provide a camera usage description for iOS: ', required: true, condition: (args) => args.platform === 'ios' }
        ]
    },
    {
        name: 'files',
        path: 'scripts/modules/enable_files.dart',
        parameters: [
            { key: 'photo_library_description', question: 'Please provide a description for accessing the photo library: ', required: true, condition: (args) => args.platform === 'ios' },
            { key: 'music_description', question: 'Please provide a description for accessing music files: ', required: true, condition: (args) => args.platform === 'ios' }
        ]
    },
    {
        name: 'contacts',
        path: 'scripts/modules/enable_contacts.dart',
        parameters: [
            { key: 'contacts_description', question: 'Please provide a description for accessing contacts: ', required: true, condition: (args) => args.platform === 'ios' }
        ]
    },
    {
        name: 'connect',
        path: 'scripts/modules/enable_connect.dart',
        parameters: [
            { key: 'camera_description', question: 'Please provide a camera usage description: ', required: true, condition: (args) => args.platform === 'ios' }
        ]
    },
    {
        name: 'location',
        path: 'scripts/modules/enable_location.dart',
        parameters: [
            { key: 'in_use_location_description', question: 'Please provide a description for using location services while the app is in use: ', required: true, condition: (args) => args.platform === 'ios' },
            { key: 'always_use_location_description', question: 'Please provide a description for using location services always: ', required: true, condition: (args) => args.platform === 'ios' },
            { key: 'google_maps', question: 'Are you enabling Google Maps? (yes/no): ', required: true },
            { key: 'google_maps_api_key', question: 'Please provide your Google Maps API key: ', required: true, condition: (args) => args.google_maps === 'yes' }
        ]
    },
    {
        name: 'deeplink',
        path: 'scripts/modules/enable_deeplink.dart',
        parameters: [
            { key: 'branch_live_key', question: 'Please provide the live Branch.io key: ', required: true },
            { key: 'branch_test_key', question: 'Please provide the test Branch.io key: ', required: false },
            { key: 'use_test_key', question: 'Are you using the test key? (yes/no): ', required: true },
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
        parameters: []
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

// Create readline interface for asking questions
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function askQuestion(query) {
    return new Promise(resolve => rl.question(query, resolve));
}

// Check for missing arguments and ask for them
async function checkAndAskForMissingArgs(scriptObj, argsArray) {
    const providedArgs = argsArray.map(arg => arg.split('=')[0]);
    const args = Object.fromEntries(argsArray.map(arg => arg.split('=')));

    const allParameters = [
        ...commonParameters,
        ...scriptObj.parameters
    ];

    for (const param of allParameters) {
        const conditionMet = param.condition ? param.condition(args) : true;

        if (!providedArgs.includes(param.key) && conditionMet) {
            const answer = await askQuestion(param.question);
            argsArray.push(`${param.key}=${answer}`);
            args[param.key] = answer;
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
async function runScriptsSequentially(scripts, argsArray) {
    let index = 0;

    async function next(err) {
        if (err) {
            console.error('Stopping execution due to an error.');
            rl.close();
            process.exit(1);
        }

        if (index < scripts.length) {
            const scriptName = scripts[index++];
            const scriptObj = findScript(scriptName);

            if (!scriptObj) {
                console.error(`Error: Script "${scriptName}" not found.`);
                rl.close();
                return process.exit(1);
            }

            // Check and prompt for missing arguments
            const updatedArgsArray = await checkAndAskForMissingArgs(scriptObj, argsArray);

            runScript(scriptObj, updatedArgsArray, next);
        } else {
            rl.close();
            process.exit(0);
        }
    }

    await next();
}

async function main() {
    const [firstArg, ...restArgs] = process.argv.slice(2);

    if (firstArg === 'enable') {
        const { scripts, argsArray } = parseArguments(restArgs);
        await runScriptsSequentially(scripts, argsArray);
    } else {
        const scriptObj = findScript(firstArg);

        if (scriptObj) {
            const { argsArray } = parseArguments(restArgs);
            const updatedArgsArray = await checkAndAskForMissingArgs(scriptObj, argsArray);
            runScript(scriptObj, updatedArgsArray, (err) => {
                rl.close();
                if (err) {
                    process.exit(1);
                } else {
                    process.exit(0);
                }
            });
        } else {
            console.error(`Error: Command "${firstArg}" not found.`);
            process.exit(1);
        }
    }
}

main();
