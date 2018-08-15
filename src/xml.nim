# xml
# Copyright Huy Doan
# Pure Nim XML parser

import strformat, strutils


const NameIdentChars = IdentChars + {':', '-', '.'}

type
  XmlParserException* = object of Exception

  TokenKind* = enum
    TAG_BEGIN
    TAG_END
    NAME
    SIMPLE_TAG_CLOSE
    TAG_CLOSE
    STRING
    TEXT
    EQUALS
    CDATA_BEGIN
    CDATA_END

  XmlToken* = object
    kind*: TokenKind
    text*: string

template error(message: string) =
  raise newException(XmlParserException, message)

proc token(kind: TokenKind, text = ""): XmlToken =
  result.kind = kind
  result.text = text

template skip_until(c: char) =
  while(input[pos] != c):
    inc(pos)

template skip_until(s: string) =
  let length = s.len
  while(input[pos..<pos+length] != s):
    inc(pos)
  inc(pos, length)


iterator tokens*(input: string): XmlToken {.inline.} =
  ## This iterator yield tokens that extracted from `input`
  var
    pos: int
    length = input.len
    is_cdata = false
    is_text = false

  var ch = input[pos]

  while pos < length and input[pos] != '\0':
    let ch = input[pos]
    if ch in Whitespace:
      inc(pos)
      continue
    case ch
    of '<':
      if not is_cdata:
        inc(pos)
        case input[pos]:
        of '?':
          # skips prologue
          skip_until('>')
          # print out prologue
          #echo input[0..pos]
          inc(pos)
        of '!':
          inc(pos)
          if input[pos..pos+6] == "[CDATA[":
            # CDATA
            is_cdata = true
            is_text = true
            yield token(CDATA_BEGIN)
            inc(pos, 6)
          elif input[pos..pos+1] == "--":
            # skips comment
            let comment_start = pos-2
            skip_until("-->")
            # print out full of comment
            #echo input[comment_start..<pos]
          else:
            error(fmt"text expected, found ""{input[pos]}"" at {pos}")
        of '/':
          yield token(TAG_CLOSE)
          is_text = false
        else:
          dec(pos)
          yield token(TAG_BEGIN)
          is_text = false
        inc(pos)
    of ']':
      if input[pos..pos+2] != "]]>":
        error(fmt"cdata end ""]]>"" expected, found {input[pos..pos+2]} at {pos}")
      is_text =  true
      is_cdata = false
      yield token(CDATA_END)
      inc(pos, 3)
    of '\'', '"':
      inc(pos)
      var next_ch = input.find(ch, pos)
      if next_ch == -1:
        error(fmt"unable to find matching string quote last found {pos}") 
      yield token(STRING, input[pos..<next_ch])
      pos = next_ch+1
    of '>':
      inc(pos)
      is_text = true
      yield token(TAG_END)
    of '=':
      inc(pos)
      yield token(EQUALS)
    of '/':
      if input[pos+1] == '>':
        yield token(SIMPLE_TAG_CLOSE)
        inc(pos, 2)
    else:
      if(is_text):
        var text_end = 0
        if is_cdata:
          text_end = input.find("]]>", pos)
        else:
          text_end = input.find('<', pos)
        if text_end == -1:
          error(fmt"unable to find ending point of text, started at {pos}")
        yield token(TEXT, input[pos..<text_end])
        pos = text_end
        is_text = false
      else:
        var
          name = ""
          name_start = pos
        var c = input[pos]
        if c in IdentStartChars:
          while c in NameIdentChars:
            name.add(c)
            inc(pos)
            c = input[pos]
          yield token(NAME, name)
          if not (c in NameIdentChars):
            dec(pos)
        inc(pos)

proc tokens*(input: string): seq[XmlToken] =
  result = @[]
  for token in input.tokens:
    result.add(token)

when isMainModule:
  let xml = """<?xml version="1.0" encoding="UTF-8"?>
<!-- example -->
<classes>
    <simple-closed/>
    <note><![CDATA[This text is CDATA<>]]></note>
    <class name="Klient">
        <attr type="int">id</attr>
        <attr type="String">imie</attr>
        <attr type="String">nazwisko</attr>
        <attr type="Date">dataUr</attr>
    </class>
    <class name="Wizyta">
        <attr type="int">id</attr>
        <attr type="Klient">klient</attr>
        <attr type="Date">data</attr>
    </class>
</classes>
"""
  assert tokens(xml).len == 106
  for t in  xml.tokens:
    echo t

