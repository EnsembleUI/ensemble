const { exec } = require('child_process');

// Common parameters available across scripts and modules
const commonParameters = ['platform'];

// Modules (called with `enable` command)
const modules = [
    {
        name: 'camera',
        path: 'scripts/modules/enable_camera.dart',
        parameters: ['camera_description']
    },
    {
        name: 'files',
        path: 'scripts/modules/enable_files.dart',
        parameters: ['photo_library_description', 'music_description']
    },
    {
        name: 'contacts',
        path: 'scripts/modules/enable_contacts.dart',
        parameters: ['contacts_description']
    },
    {
        name: 'connect',
        path: 'scripts/modules/enable_connect.dart',
        parameters: ['camera_description'],
    },
    {
        name: 'location',
        path: 'scripts/modules/enable_location.dart',
        parameters: ['in_use_location_description', 'always_use_location_description', 'google_maps', 'google_maps_api_key']
    },
    {
        name: 'deeplink',
        path: 'scripts/modules/enable_deeplink.dart',
        parameters: ['branch_live_key', 'branch_test_key', 'use_test_key', 'scheme', 'links']
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
        parameters: ['storePassword', 'keyPassword', 'keyAlias']
    },
    {
        name: 'getShaKeys',
        path: 'scripts/get_sha_keys.dart',
    }
];

// find the script object
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
            if (scriptObj.parameters.includes(key) || commonParameters.includes(key)) {
                return `${key}=${value}`;
            }

            return null;
        })
        .filter(arg => arg !== null)
        .join(' ');
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
function runScriptsSequentially(scripts, argsArray) {
    let index = 0;

    function next(err) {
        if (err) {
            console.error('Stopping execution due to an error.');
            process.exit(1);
        }

        if (index < scripts.length) {
            const scriptName = scripts[index++];
            const scriptObj = findScript(scriptName);

            if (!scriptObj) {
                console.error(`Error: Script "${scriptName}" not found.`);
                return process.exit(1);
            }

            runScript(scriptObj, argsArray, next);
        } else {
            process.exit(0);
        }
    }

    next();
}

function main() {
    const [firstArg, ...restArgs] = process.argv.slice(2);

    if (firstArg === 'enable') {
        const { scripts, argsArray } = parseArguments(restArgs);
        runScriptsSequentially(scripts, argsArray);
    } else {
        const scriptObj = findScript(firstArg);

        if (scriptObj) {
            const { argsArray } = parseArguments(restArgs);
            runScript(scriptObj, argsArray, (err) => {
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
