#!/usr/bin/python3
#SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2019 Alberto Pianon <pianon@array.eu>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

import panflute as pf

import sys

# {parameter_name: default}
parm_defaults = {
    'inlineHeaderLevel': 0, # values below 2 do not have any effect
    'inlineHeaderDelim': '.',
    'inlineHeaderStyle': 'emph',
    'inlineHeaderNumStyle': 'plain',
    'inlineHeaderParStyle': 'Customlist',
    'inlineHeaderParStyleStart': 'start'
}
# parameter inlineHeaders can be set only as header attribute

style_classes = {
    'plain': pf.Span, 'normal': pf.Span, 'standard': pf.Span,
    'emph': pf.Emph, 'emphasis': pf.Emph, 'italic': pf.Emph,
    'bold': pf.Strong, 'strong': pf.Strong,
}


def get_parms(elem, doc):
    '''get parameters in the following order:
    1) header attribute, f.e.: # My Header {#sec:mine inlineHeaderDelim=":"}
    2) document metadata (YAML), f.e.: inlineHeaderDelim: ":"
    3) default (see parm_defaults)
    '''
    global parm_defaults
    parms = {}
    for key, default_value in parm_defaults.items():
        if hasattr(elem, 'attributes') and elem.attributes.get(key) != None:
            # 1) header attribute
            parms[key] = elem.attributes.get(key)
        elif doc.get_metadata(key):
            # 3) document metadata
            parms[key] = doc.get_metadata(key)
        else:
            # 4) default
            parms[key] = default_value
    return parms


def get_style_elem(style):
    global style_classes
    return style_classes.get(style)() if style_classes.get(style) else pf.Span()
    #default: plain


def create_elem(text, style):
    elem = get_style_elem(style)
    text_subelems = pf.convert_text(
        text.replace("\t", "&#x09;"), # necessary to preserve possible tabs
        input_format="html", # otherwise it may detect "false" markdown syntax
        extra_args=["--preserve-tabs",]
    )
    if text_subelems and text_subelems[0].content:
        for e in text_subelems[0].content:
            elem.content.append(e)
    return elem


def create_inlineheader(elem, doc, parms, delim=True):
    '''transform the header to an inline header, applying the emphasis
    (italic) or strong (bold) style, depending on the parameters
    '''
    secHeaderDelim = doc.get_metadata('secHeaderDelim')
    numberSections = doc.get_metadata('numberSections')
    sectionsDepth = int(doc.get_metadata('sectionsDepth'))
    chapDelim = doc.get_metadata('chapDelim')
    inlineHeaderStyle = parms['inlineHeaderStyle']
    inlineHeaderNumStyle = parms['inlineHeaderNumStyle']
    inlineHeaderDelim = parms['inlineHeaderDelim']

    header_str = pf.stringify(elem)
    if (numberSections and secHeaderDelim and
        secHeaderDelim != chapDelim and
        secHeaderDelim in header_str
    ):
        # apply different styles for section number and for section title
        inline_header = pf.Span()
        s = header_str.split(secHeaderDelim)
        sec_number = s[0]+secHeaderDelim
        sec_title = secHeaderDelim.join(s[1:])

        if sec_title and delim:
            sec_title += inlineHeaderDelim
        sec_number_elem = get_style_elem(inlineHeaderNumStyle)
        sec_number_elem.content.append(pf.Str(sec_number))
        sec_title_elem = create_elem(sec_title, inlineHeaderStyle)
        inline_header.content.append(sec_number_elem)
        if sec_title_elem.content:
            inline_header.content.append(sec_title_elem)
            inline_header.content.append(pf.Space())

    else:
        # apply one style for the entire header text
        inline_header = get_style_elem(inlineHeaderStyle)
        for e in elem.content:
            inline_header.content.append(e)
        if inline_header.content:
            if sectionsDepth == -1 or elem.level <= sectionsDepth:
                inline_header.content.append(pf.Str(inlineHeaderDelim))
                inline_header.content.append(pf.Space())
            else:
                inline_header.content.append(pf.Str(secHeaderDelim))

    return inline_header


def skip_comments(elem):
    '''skip comment blocks (f.e. <--! my comment --> ) between header and
    paragraph or between paragraphs or other elements that go together in the
    same section
    '''
    if elem:
        elem = elem.next
    while isinstance(elem, pf.RawBlock):
        elem = elem.next
        elem.parent.content.pop(elem.index-1)
    if elem:
        elem = elem.prev
    return elem


def process_next(
    elem, parms,
    parent_level, inline_header_level,
    inline_header=None, inline_header_identifier=''
):
    '''process next element, adding inline header (if required) and custom style
    '''
    if not elem or not elem.next:
        return None
    NewClass = elem.next.__class__
    new = NewClass()
    if inline_header and inline_header.content:
        new.content.append(inline_header)
    for e in elem.next.content:
        new.content.append(e)
    if inline_header:
        style_suffix = ' '+parms['inlineHeaderParStyleStart']
    elif NewClass == pf.OrderedList: # TODO: keep it for when the pandoc issue will be resolved
        style_suffix = ' list'
    else:
        style_suffix = ''
    newDiv = pf.Div(new,
        attributes={'custom-style': '{} {}{}'.format(
            parms['inlineHeaderParStyle'],
            inline_header_level - parent_level,
            style_suffix
        )},
        identifier=inline_header_identifier
    )
    elem.parent.content.insert(elem.index+2, newDiv)
    for i in range(0, 2):
        elem = elem.next
        if i == 1 or inline_header:
            elem.parent.content.pop(elem.index-1)
    return elem


def action(elem, doc):
    parms = get_parms(elem, doc)
    if (
        isinstance(elem, pf.Header)
        and
        ((hasattr(elem, 'attributes') and elem.attributes.get('inlineHeaders'))
          or
          elem.level == int(parms['inlineHeaderLevel'])-1
        )
    ):
        parent_level = elem.level
        elem = elem.next
        while elem:
            if not isinstance(elem, pf.Header):
                elem = elem.next
                continue
            elif elem.level <= parent_level:
                break
            elem = skip_comments(elem)
            if not elem:
                break

            inline_header_level = elem.level
            inline_header_identifier = elem.identifier
            if isinstance(elem.next, pf.Para):
                inline_header = create_inlineheader(elem, doc, parms)
                elem = skip_comments(elem)
                elem = process_next(
                    elem, parms,
                    parent_level, inline_header_level,
                    inline_header, inline_header_identifier)
                while elem and (
                    isinstance(elem.next, pf.Para)
                    or isinstance(elem.next, pf.OrderedList)
                        # setting style for OrderedList(s) does not have any
                        # effect in practice because of this bug:
                        # https://github.com/jgm/pandoc/issues/4697
                        # we keep it anyway hoping that the bug will be solved
                ):
                    elem = skip_comments(elem)
                    elem = process_next(
                        elem, parms, parent_level, inline_header_level
                    )
            else: # replace only header
                inline_header = create_inlineheader(elem,doc,parms,delim=False)
                newDiv = pf.Div(pf.Para(inline_header),
                    attributes={'custom-style': '{} {}{}'.format(
                        parms['inlineHeaderParStyle'],
                        inline_header_level - parent_level,
                        ' header'
                    )},
                    identifier=inline_header_identifier
                )
                elem.parent.content.insert(elem.index+1, newDiv)
                elem = elem.next
                elem.parent.content.pop(elem.index-1)
                elem = elem.next



def prepare(doc):
    chapDelim = doc.get_metadata('chapDelim')
    secHeaderDelim = doc.get_metadata('secHeaderDelim')
    if chapDelim and secHeaderDelim and chapDelim == secHeaderDelim:
        sys.stderr.write(
            "[inline-headers]: secHeaderDelim '%s' is equal to chapDelim, "
            "cannot apply a separate numbering style for inline headers\n"
            % secHeaderDelim
        )


if __name__ == '__main__':
    pf.toJSONFilter(action, prepare=prepare)
