// main.js

const tsj = require("ts-json-schema-generator");
const fs = require("fs");

/** @type {import('ts-json-schema-generator/dist/src/Config').Config} */
const config = {
    path: "./coreSchema.ts",
    tsconfig: "./tsconfig.json",
   
    type: "Screen", // Or <type-name> if you want to generate schema for that one type only,
    expose: "all",
    strictTuples: true,
    skipTypeCheck: false

};

const output_path = "./output/ensemble_schema.json";

const schema = tsj.createGenerator(config).createSchema(config.type);
const schemaString = JSON.stringify(schema, null, 2);
fs.writeFile(output_path, schemaString, (err) => {
    if (err) throw err;
});