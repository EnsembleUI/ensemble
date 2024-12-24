import { exec } from 'child_process';
import { commonParameters } from './modules';
import { ArgumentParseResult, Script } from './interfaces';
import {
  checkAndAskForMissingArgs,
  findScript,
  logError,
  selectModules,
} from './utils';

const parseArguments = (args: string[]): ArgumentParseResult => {
  const scripts: string[] = [];
  const argsArray: string[] = [];
  for (const arg of args) {
    if (arg.includes('=')) {
      const [key, value] = arg.split('=');
      argsArray.push(`${key}="${value.replace(/"/g, '\\"')}"`);
    } else {
      scripts.push(arg);
    }
  }
  return { scripts, argsArray };
};

const generateArgsForScript = (
  scriptObj: Script,
  argsArray: string[]
): string => {
  const allowedKeys = new Set([
    ...scriptObj.parameters.map((p) => p.key),
    ...commonParameters.map((p) => p.key),
  ]);
  return argsArray
    .filter((arg) => allowedKeys.has(arg.split('=')[0]))
    .join(' ');
};

const executeCommand = (command: string): Promise<void> => {
  console.log(`Executing: ${command}`);
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        logError(`Command failed: ${command}`, error);
        return reject(error);
      }
      if (stderr) console.error(`[stderr] ${stderr}`);
      if (stdout) console.log(`[stdout] ${stdout}`);
      resolve();
    });
  });
};

const runScript = async (
  scriptObj: Script,
  argsArray: string[]
): Promise<void> => {
  const dartArgs = generateArgsForScript(scriptObj, argsArray);
  const command = `dart run ${scriptObj.path} ${dartArgs}`;
  await executeCommand(command);
};

const runScriptsSequentially = async (list: Script[], argsArray: string[]) => {
  for (const s of list) await runScript(s, argsArray);
};

(async () => {
  try {
    const [firstArg, ...restArgs] = process.argv.slice(2);
    const bypass = restArgs.includes('bypass-questions=true');

    if (firstArg === 'enable') {
      const { scripts: toRun, argsArray } = parseArguments(restArgs);
      const selected =
        toRun.length > 0 ? toRun.map(findScript) : await selectModules();
      const updated = bypass
        ? argsArray
        : await checkAndAskForMissingArgs(selected, argsArray);
      await runScriptsSequentially(selected, updated);
    } else {
      const scriptObj = findScript(firstArg);
      const { argsArray } = parseArguments(restArgs);
      const updated = bypass
        ? argsArray
        : await checkAndAskForMissingArgs([scriptObj], argsArray);
      await runScript(scriptObj, updated);
    }
  } catch (error) {
    logError('An error occurred', error);
    process.exit(1);
  }
})();
