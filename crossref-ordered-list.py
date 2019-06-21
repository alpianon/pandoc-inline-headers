#!/usr/bin/python3

import panflute as pf

import sys

def upperRoman(number):
    roman_digit_map = [
        (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
        (100, 'C'),  (90, 'XC'),  (50, 'L'),  (40, 'XL'),
        (10, 'X'),   (9, 'IX'),   (5, 'V'),   (4, 'IV'),
        (1, 'I'),
    ]
    roman_number = ''
    i = 0
    while  number > 0:
        x = 0
        count = number // roman_digit_map[i][0]
        while x < count:
            roman_number += roman_digit_map[i][1]
            number -= roman_digit_map[i][0]
            x = x + 1
        i += 1
    return roman_number

def lowerRoman(number):
    return upperRoman(number).lower()

def lowerAlpha(number):
    return ' abcdefghijklmnopqrstuvwxyz'[number]

def upperAlpha(number):
    return ' ABCDEFGHIJKLMNOPQRSTUVWXYZ'[number]

number_formats = {
    'Decimal': str,
    'LowerAlpha': lowerAlpha,
    'UpperAlpha': upperAlpha,
    'LowerRoman': lowerRoman,
    'UpperRoman': upperRoman,
}

curlevel = 0
curid = ''

def action(elem, doc):
    global curlevel, curid
    numberSections = doc.get_metadata('numberSections')
    sectionsDepth = doc.get_metadata('sectionsDepth')
    sectionsDepth = int(sectionsDepth) if sectionsDepth else 0
    if not numberSections:
        return None
    if isinstance(elem, pf.Header):
        curlevel = elem.level
        curid = elem.identifier
    elif isinstance(elem, pf.OrderedList):
        ordered_list = elem
        if ordered_list.style not in [style for style in number_formats]:
            return None
        format_number = number_formats[ordered_list.style]
        for idx, list_item in enumerate(ordered_list.content):
            number = format_number(idx+1)
            elem.parent.content.insert(
                elem.index+1,
                pf.Header(
                    (
                        pf.Str(number)
                        if (curlevel >= sectionsDepth and sectionsDepth != -1)
                        else pf.Str("")
                    ),
                    level=curlevel+1,
                    identifier=curid+":"+number,
                    attributes={'label': number},
                ),
            )
            elem = elem.next
            elem.parent.content.insert(
                elem.index+1,
                pf.Para()
            )
            elem = elem.next
            if list_item.content:
                elem.content = list_item.content[0].content
        while len(ordered_list.content) > 0:
            ordered_list.content.pop(0)

if __name__ == '__main__':
    pf.toJSONFilter(action)
