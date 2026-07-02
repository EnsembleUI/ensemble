from fontTools import ttLib
import functools
from pathlib import Path
import json
import re

_PUA_CODEPOINTS = [
    range(0xE000, 0xF8FF + 1),
    range(0xF0000, 0xFFFFD + 1),
    range(0x100000, 0x10FFFD + 1)
]

def _is_pua(codepoint):
    return any(r for r in _PUA_CODEPOINTS if codepoint in r)

def _cmap(ttfont):
    def _cmap_reducer(acc, u):
        acc.update(u)
        return acc

    unicode_cmaps = (t.cmap for t in ttfont['cmap'].tables if t.isUnicode())
    return functools.reduce(_cmap_reducer, unicode_cmaps, {})

def _LookupSubtablesOfType(lookup_list, lookup_type):
    # Direct matches
    for lookup in lookup_list.Lookup:
        if lookup.LookupType == lookup_type:
            for subtable in lookup.SubTable:
                yield subtable

def _ligatures(ttfont):
    lookup_list = ttfont['GSUB'].table.LookupList

    # Direct ligatures
    for subtable in _LookupSubtablesOfType(lookup_list, 4):
        yield subtable.ligatures

    # Extensions
    for ext_subtable in _LookupSubtablesOfType(lookup_list, 7):
        if ext_subtable.ExtensionLookupType == 4:
            yield ext_subtable.ExtSubTable.ligatures

def enumerate_icons(font_file: Path):
    """Yields (icon name, codepoint) tuples for icon font."""
    with ttLib.TTFont(font_file) as ttfont:
        cmap = _cmap(ttfont)
        rev_cmap = {v: k for k, v in cmap.items()}

        for lig_root in _ligatures(ttfont):
            for first_glyph_name, ligatures in lig_root.items():
                for ligature in ligatures:
                    glyph_names = (first_glyph_name,) + tuple(ligature.Component)
                    icon_name = ''.join(chr(rev_cmap[n]) for n in glyph_names)
                    codepoint = rev_cmap[ligature.LigGlyph]
                    if not _is_pua(codepoint):
                        continue
                    yield (icon_name, codepoint)

def generate_icon_data(font_file_path):
    icons_and_codepoints = enumerate_icons(font_file_path)
    icon_data = [{"name": replace_numbers_with_words(name), "code": code} for name, code in icons_and_codepoints]
    return icon_data

def save_to_json(data, output_file):
    with open(output_file, 'w') as json_file:
        json.dump(data, json_file, indent=4)

def replace_numbers_with_words(name):
    # Replace numbers with words in the icon name
    return re.sub(r'(\d+)', lambda x: _replace_number_with_word(x.group()), name)

def _replace_number_with_word(number_str):
    numbers_as_words = {
        '0': 'zero_',
        '1': 'one_',
        '2': 'two_',
        '3': 'three_',
        '4': 'four_',
        '5': 'five_',
        '6': 'six_',
        '7': 'seven_',
        '8': 'eight_',
        '9': 'nine_',
        '10': 'ten_',
        '11': 'eleven_',
        '12': 'twelve_',
        '13': 'thirteen_',
        '14': 'fourteen_',
        '15': 'fifteen_',
        '16': 'sixteen_',
        '17': 'seventeen_',
        '18': 'eighteen_',
        '19': 'nineteen_',
        '20': 'twenty_',
        '21': 'twenty_one',
        '22': 'twenty_two',
        '23': 'twenty_three',
        '24': 'twenty_four',
        '25': 'twenty_five',
        '26': 'twenty_six',
        '27': 'twenty_seven',
        '28': 'twenty_eight',
        '29': 'twenty_nine',
        '30': 'thirty_',
        '123': 'onetwothree',
        '360': 'threesixty',
        '60': 'sixty_',
    }
    return numbers_as_words.get(number_str, number_str)

def generate_dart_file(json_file, dart_file):
    try:
        with open(json_file, "r") as f:
            data = json.load(f)

        with open(dart_file, "w") as f:
            f.write("import 'package:flutter/material.dart';\n\n")
            f.write("/// this class should be generated\n")
            f.write("class MaterialIcons {\n")
            f.write("  static final Map<String, IconData> iconMap = {\n")
            for item in data:
                name = item["name"].replace("-", "_").replace(" ", "_")
                f.write(f"    '{name}': Icons.{name},\n")
            f.write("  };\n")
            f.write("}\n")

        print("Dart file created successfully:", dart_file)

    except FileNotFoundError:
        print("Error: JSON file not found.")
    except Exception as e:
        print("An error occurred:", str(e))

font_file_path = Path("MaterialIcons.ttf")  # Replace with the actual path to your font file
output_file = "icon_data.json"

icon_data = generate_icon_data(font_file_path)
save_to_json(icon_data, output_file)

print(f"Icon data has been saved to {output_file}.")

json_file_path = "icon_data.json"
dart_file_path = "materialIcon.dart"
generate_dart_file(json_file_path, dart_file_path)
