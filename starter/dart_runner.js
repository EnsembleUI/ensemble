const { exec } = require('child_process');

// Get the Dart script path from the third argument
const scriptPath = process.argv[2];

// Get the key-value arguments starting from the fourth argument
const argsArray = process.argv.slice(3);

// Convert the key=value pairs into --key value format for Dart
const dartArgs = argsArray.map(arg => {
    const [key, value] = arg.split('=');
    return `--${key} ${value}`;
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
