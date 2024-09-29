const { exec } = require('child_process');

const scriptPath = process.argv[2];

const argsArray = process.argv.slice(3);

// Convert the key=value pairs into --key value format for Dart
const dartArgs = argsArray.map(arg => {
    const [key, value] = arg.split('=');

    const quotedValue = value.includes(' ') ? `"${value}"` : value;

    return `--${key} ${quotedValue}`;
}).join(' ');

// Construct the Dart command
const command = `dart run ${scriptPath} ${dartArgs}`;

exec(command, (error, stdout, stderr) => {
    if (error) {
        console.error(`Error: ${error.message}`);
        return;
    }
    if (stderr) {
        console.error(`Stderr: ${stderr}`);
        return;
    }
    console.log(stdout);
});
