import * as fs from "fs-extra";
import * as path from "path";
import { parseDocument, isMap, YAMLMap } from "yaml";

const modulesDir = path.join(__dirname, "modules");
const newTag = process.argv[2]; // Get the new tag from command line arguments

if (!newTag) {
  console.error("Please provide the new tag as a command line argument.");
  process.exit(1);
}

async function updatePubspecRefs(dir: string, tag: string) {
  const files = await fs.readdir(dir);

  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = await fs.lstat(filePath);

    if (stat.isDirectory()) {
      await updatePubspecRefs(filePath, tag); // Recursively process subdirectories
    } else if (file === "pubspec.yaml") {
      await processPubspecFile(filePath, tag);
    }
  }
}

async function processPubspecFile(pubspecPath: string, tag: string) {
  try {
    const fileContent = await fs.readFile(pubspecPath, "utf8");
    const doc = parseDocument(fileContent);

    let updated = false;
    const dependencies = doc.get("dependencies") as YAMLMap | undefined;
    const devDependencies = doc.get("dev_dependencies") as YAMLMap | undefined;

    if (dependencies) {
      updated = updateDependencies(dependencies, tag) || updated;
    }
    if (devDependencies) {
      updated = updateDependencies(devDependencies, tag) || updated;
    }

    if (updated) {
      const newYamlContent = String(doc);
      await fs.writeFile(pubspecPath, newYamlContent, "utf8");
      console.log(`Updated ${pubspecPath} to tag ${tag}`);
    }
  } catch (error) {
    if (error instanceof Error) {
      console.error(`Failed to update ${pubspecPath}:`, error.message);
    } else {
      console.error(`Failed to update ${pubspecPath}:`, error);
    }
  }
}

function updateDependencies(dependencies: YAMLMap, tag: string): boolean {
  let updated = false;
  const targetUrl = "https://github.com/EnsembleUI/ensemble.git";

  for (const item of dependencies.items) {
    const key = item.key;
    const value = item.value;

    if (isMap(value) && value.has("git")) {
      const git = value.get("git");
      if (isMap(git) && git.get("url") === targetUrl && git.has("ref")) {
        git.set("ref", tag);
        updated = true;
      }
    }
  }

  return updated;
}

updatePubspecRefs(modulesDir, newTag).catch((error) =>
  console.error("Error updating pubspec refs:", error)
);
