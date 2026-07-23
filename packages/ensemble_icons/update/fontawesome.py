import re
import json

def extract_icons_from_dart_file(file_path):
    icon_data = []
    with open(file_path, 'r') as file:
        dart_code = file.read()
        matches = re.findall(r'static const IconData (\w+) = IconData\w+\((0[xX][0-9a-fA-F]+)\);', dart_code)
        for match in matches:
            icon_name = match[0]
            unicode_value = match[1]
            icon_data.append({
                'name': icon_name,
                'code': unicode_value,
            })
    return icon_data

def generate_dart_file(icons, dart_file):
    try:
        with open(dart_file, "w") as f:
            f.write("import 'package:flutter/cupertino.dart';\n")
            f.write("import 'package:font_awesome_flutter/font_awesome_flutter.dart';\n\n")
            f.write("/// this class should be generated\n")
            f.write("/// Icons based on font awesome 6.5.1 & font_awesome_flutter v10.7.0\n")
            f.write("class FontAwesome {\n")
            f.write("  static final Map<String, IconData> iconMap = {\n")
            for item in icons:
                name = item["name"].replace("-", "_").replace(" ", "_")
                f.write(f"    '{name}': FontAwesomeIcons.{name},\n")
            f.write("  };\n")
            f.write("}\n")

        print("Dart file created successfully:", dart_file)

    except Exception as e:
        print("An error occurred:", str(e))

# Example usage:
file_path = "font.dart"
icons = extract_icons_from_dart_file(file_path)

# Saving to JSON file
output_file = "icons.json"
with open(output_file, 'w') as json_file:
    json.dump(icons, json_file, indent=4)

# Generate Dart file
dart_file_path = "fontAwesomeIcon.dart"
generate_dart_file(icons, dart_file_path)
