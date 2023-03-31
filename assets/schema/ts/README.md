


## TypeScript to JSON Schema Generator  📘

This Readme is for the people who want to use typescript code for generating JSON schema. 


## Workflow

The entry point to the whole process is one script file `generate.js` that converts typescript code into a JSON schema file as output. 
The script makes use of [ts-schema-generator](https://www.npmjs.com/package/ts-json-schema-generator) behind the scene to parse and generate the schema file. 
The properties used for the schema generation are listed below. 
    
    path: "./src/coreSchema.ts",  
    tsconfig: "./tsconfig.json",  
    type: "properties",   
    expose: "export",  
    topRef: false,  
    skipTypeCheck: false,  
    strictTuples: true
   
The script reads the given file from **path** property and converts all exported types and interfaces to a JSON format. We can specify which interface should be treated as root object by using **type** property. 
More information about available properties can be found on the library's github page. 

Please follow these steps to run the scripts

 - Make sure you have node installed.
 - Install ts-json-schema-generator from [here](https://github.com/vega/ts-json-schema-generator).
 - Run the following command on the command prompt.

		node generate.js

## Folder Structure

> src/styles

All the common styles and properties are stored under this directory. 

> src/widgets

This directory contains files for each widget. Any new widget can be created by adding a file under this directory and then exporting that widget via ***Widgets*** interface from inside `src/coreSchema.ts`. 

> src/actionSchema.ts

This file contains interfaces for all the available actions. 

> src/widgetSchema.ts

This file contains some basic properties for building a widget and exports container/parent widgets. e.g. View, Flex, Row, Column etc.

> src/coreSchema.ts

The coreSchema file is the only file thats provided to the schema generation script and it exports all the members and properties that we want to show in the JSON schema file.


## Schema Generation from Code
Suppose you have a type or interface and you can add different properties to your type. for example

    type Box = {  
	  height: number;  
	  width: number;  
	  color?: string;  
	}
Now if we convert this type to a JSON schema, its translated like this

    "Box": {  
	  "type": "object",
	  "required": [  
		  "height",  
		  "width",  
	  ],
	  "properties": {  
		  "height": {  
		    "type": "number"  
		  },  
		  "width": {  
		    "type": "number"  
		  }
		  "color": {  
		    "type": "string"  
		  }
		}   
	},

Notice how a required field comes out as required in the generated schema as well while the rest of properties remain optional.
Next we can learn how to add different properties and description to our generated objects. We will use decorators and multiline comments to add more properties to the generated objects. 

    export interface TextStyles {  
	  /**  
	   * Default built-in style for this text 
	   **/  
	   font: string;  
	  /**  
		* Default font size for this text
		* @minimum 6  
	   **/  
	   fontSize: number;
	}   

the generated schema for the interface **TextStyles** comes out like this.

    "TextStyles": {
	    "type": "object",  
	    "properties": {  
	      "font": {  
		      "type": "string",  
		      "description": "Default built-in style for this text"  
	      },  
	      "fontSize": {  
		      "type": "number",  
		      "description": "Default font size for this text",  
		      "minimum": 6  
	      }  
    }}
Notice how multiline comment is converted into description and `@minimum` decorator adds minimum value condition to the `fontSize` property. More information on available decorators can be found [here](https://github.com/YousefED/typescript-json-schema/blob/master/api.md).
The whole schema generation process is handled by the script itself but the user needs to correctly export required types/interfaces in order to make them appear in generated schema.
