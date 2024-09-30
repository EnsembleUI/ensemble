const { exec } = require('child_process');

const scriptsList = [
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
    }
];

const commonParameters = ['platform'];

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

// Generate Dart arguments
function generateArgsForScript(scriptObj, argsArray) {
    return argsArray
        .map(arg => {
            const [key, value] = arg.split('=');
            if (commonParameters.includes(key) || scriptObj.parameters.includes(key)) {
                const quotedValue = value.includes(' ') ? `"${value}"` : value;
                return `--${key} ${quotedValue}`;
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
            return callback(new Error(stderr));
        }
        console.log(stdout);
        callback();
    });
}

// Function to run multiple scripts in sequence
function runScriptsSequentially(scripts, argsArray) {
    let index = 0;

    function next() {
        if (index < scripts.length) {
            const scriptName = scripts[index++];
            const scriptObj = scriptsList.find(s => s.name === scriptName);

            if (!scriptObj) {
                console.error(`Error: Script "${scriptName}" not found.`);
                return next();
            }

            runScript(scriptObj, argsArray, (err) => {
                if (!err) next();
            });
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
        const scriptObj = scriptsList.find(script => script.path === firstArg);

        if (scriptObj) {
            const { argsArray } = parseArguments(restArgs);
            runScript(scriptObj, argsArray);
        } else {
            console.error(`Error: Path "${firstArg}" not found.`);
            process.exit(1);
        }
    }
}

main();
