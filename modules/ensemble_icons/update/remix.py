import json
import xml.etree.ElementTree as ET

def parse_ttx_file(file_path, output_file):
    objects = []
    
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()

        for cmap_format in root.findall(".//cmap/cmap_format_4"):
            for map_element in cmap_format.findall("map"):
                code = map_element.get("code")
                name = map_element.get("name")
                objects.append({"code": code, "name": name})

        with open(output_file, "w") as json_file:
            json.dump(objects, json_file, indent=4)

        print("JSON file created successfully:", output_file)

    except ET.ParseError as e:
        print("Error parsing XML:", e)
    except IOError as e:
        print("Error writing JSON file:", e)

def fix_json(json_file):
    try:
        with open(json_file, "r") as f:
            data = json.load(f)
        
        unique_data = {}
        for item in data:
            unique_data[item["name"]] = item
        
        with open(json_file, "w") as f:
            json.dump(list(unique_data.values()), f, indent=4)
        
        print("JSON file fixed successfully:", json_file)
    
    except IOError as e:
        print("Error fixing JSON file:", e)

def generate_dart_file(json_file, dart_file):
    try:
        with open(json_file, "r") as f:
            data = json.load(f)

        with open(dart_file, "w") as f:
            f.write("import 'package:flutter/cupertino.dart';\n\n")
            f.write("/// this class should be generated\n")
            f.write("class Remix {\n")
            f.write("  static final Map<String, IconData> iconMap = {\n")
            for item in data:
                name = item["name"].replace("-", "_").replace(" ", "_")
                f.write(f"    '{name}': Remix.{name},\n")
            f.write("  };\n\n")
            f.write("  static const _ff = 'Remix';\n")
            f.write("  static const _fp = 'ensemble_icons';\n\n")

            for item in data:
                code = item["code"].replace("0x", "")
                name = item["name"].replace("-", "_").replace(" ", "_")
                f.write(f"  static const IconData {name} = IconData(0x{code}, fontFamily: _ff, fontPackage: _fp);\n")
        
            f.write("}\n")

        print("Dart file created successfully:", dart_file)

    except FileNotFoundError:
        print("Error: JSON file not found.")
    except Exception as e:
        print("An error occurred:", str(e))

def reverse_engineer_icons(ttx_file_path, output_json_path, dart_file_path):
    parse_ttx_file(ttx_file_path, output_json_path)
    fix_json(output_json_path)
    generate_dart_file(output_json_path, dart_file_path)

# Example usage:
ttx_file_path = "remixicon.ttx"
output_json_path = "remix.json"
dart_file_path = "remixicon.dart"
reverse_engineer_icons(ttx_file_path, output_json_path, dart_file_path)
