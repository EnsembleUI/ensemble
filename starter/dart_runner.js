import { exec } from 'child_process';
import inquirer from 'inquirer';
import { modules, scripts, commonParameters } from './modules.js';

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
