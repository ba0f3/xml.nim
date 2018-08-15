import pegs, xml

const example = """<?xml version="1.0" encoding="UTF-8"?>
<classes>
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

var matches: seq[string] = @[]
doAssert(example.match(grammar, matches))

for m in matches:
  echo m
