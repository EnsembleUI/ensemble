import prompts from 'prompts';
import { Parameter, Script } from './interfaces';
import { commonParameters, modules, scripts } from './modules';

export const findScript = (name: string): Script => {
  const script =
    scripts.find((s) => s.name === name) ||
    modules.find((m) => m.name === name);
  if (!script) throw new Error(`Script/module "${name}" not found.`);
  return script;
};

export const logError = (message: string, error?: unknown) => {
  console.error(`[Error] ${message}`);
  if (error instanceof Error) console.error(`[Details] ${error.message}`);
};

export const selectModules = async (): Promise<Script[]> => {
  const { selectedModules } = await prompts({
    type: 'multiselect',
    name: 'selectedModules',
    message: 'Please select the modules you want to enable:',
    choices: modules.map((m) => ({ title: m.name, value: m.name })),
  });
  return selectedModules.map(findScript);
};

const askForMissingArgs = async (
  params: Parameter[],
  args: Record<string, string>,
  providedArgs: string[],
  isCI: boolean
): Promise<Record<string, string>> => {
  const questions: prompts.PromptObject[] = params
    .filter((param) => {
      const required =
        typeof param.required === 'function'
          ? param.required(args)
          : param.required;
      return (
        required &&
        !providedArgs.includes(param.key) &&
        !args[param.key] &&
        !isCI
      );
    })
    .map((param) => ({
      type: param.choices ? 'select' : 'text',
      name: param.key,
      message: param.question,
      choices: param.choices?.map((choice) => ({
        title: choice,
        value: choice,
      })),
      validate: (value: any) =>
        value ? true : `Parameter "${param.key}" is required.`,
    }));

  const answers = await prompts(questions);
  return Object.fromEntries(
    Object.entries(answers).map(([key, value]) => [
      key,
      value === 'yes' ? 'true' : value === 'no' ? 'false' : value,
    ])
  );
};

export const checkAndAskForMissingArgs = async (
  selected: Script[],
  argsArray: string[]
): Promise<string[]> => {
  const providedArgs = argsArray.map((a) => a.split('=')[0]);
  const args = Object.fromEntries(
    argsArray.map((arg) => {
      const i = arg.indexOf('=');
      return [arg.slice(0, i), arg.slice(i + 1).replace(/"/g, '')];
    })
  );
  const isCI = process.env.CI === 'true';

  const commonAnswers = await askForMissingArgs(
    commonParameters,
    args,
    providedArgs,
    isCI
  );
  Object.assign(args, commonAnswers);

  const allParams = selected.flatMap((s) => s.parameters);
  const moduleAnswers = await askForMissingArgs(
    allParams,
    args,
    providedArgs,
    isCI
  );
  Object.assign(args, moduleAnswers);

  return argsArray.concat(
    ...Object.entries({ ...commonAnswers, ...moduleAnswers }).map(
      ([k, v]) => `${k}="${v}"`
    )
  );
};
