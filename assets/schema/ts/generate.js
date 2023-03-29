const tsj = require("ts-json-schema-generator");
const fs = require("fs");
const config = {
  path: "./src/coreSchema.ts",
  tsconfig: "./tsconfig.json",
  type: "properties",
  expose: "export",
  topRef: false,

  skipTypeCheck: false,
  strictTuples: true,
  // jsDoc: "extended",
  // encodeRefs: true,
};

const output_path = "./output/ensemble_schema.json";
const schema = tsj.createGenerator(config).createSchema(config.type);
const schemaString = JSON.stringify(schema, null, 2);
// const result = schemaString.replaceAll("anyOf", "oneOf");

fs.writeFile(output_path, schemaString, (err) => {
  if (err) throw err;
});
