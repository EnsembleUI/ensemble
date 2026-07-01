# Update Icon Libraries

## Remix

- Download the latest remix icons font ttf file from here: [Remix Icons](https://github.com/Remix-Design/RemixIcon/tree/master/fonts)
- Convert the ttf file to ttx (make sure you have fontTools installed)
  - run this command: `python -m fontTools.ttx remixicon.ttf`
- Now run `python remix.py`

it will generate a json and a dart file
remove the icons starting with a number
move this dart file to lib folder

## FontAwesome

- Download the latest fontAwesome dart file from here: [FontAwesome Flutter](https://github.com/fluttercommunity/font_awesome_flutter/blob/master/lib/font_awesome_flutter.dart)
- Run `python fontawesome.py`

it will generate a json and a dart file
move this dart file to lib folder

## Material

- Download the latest material icon ttf file from here: [Material Icons](https://github.com/google/material-design-icons/tree/master/font)
- run `python material.py`

it will generate a json and a dart file
move this dart file to lib folder
this file still might have a few issues, fix those manually
