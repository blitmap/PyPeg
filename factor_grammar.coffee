Grammar = require './peg'

g = new Grammar

WS              = g.Regex /\s*/
Digit           = g.Regex /\d/
Letter          = g.Regex /[a-zA-Z]/
FirstSymbolChar = Letter.or g.CharSet '~@#?$%^&*-_=+:<>,./'
NextSymbolChar  = FirstSymbolChar.or Digit
Symbol          = g.Node 'Symbol', FirstSymbolChar.and g.ZeroOrMore NextSymbolChar
AString         = g.Node 'String', g.Char('"').and g.AdvanceWhileNot(g.Char('"')).and g.Char '"'
Float           = g.Node 'Float', g.Regex /\-?\d+?\.\d+/
Integ           = g.Node 'Int', g.Regex /-?\d+/
Atom            = g.Node 'Atom', Integ.or Float.or AString.or Symbol
Term            = g.Delay()
Terms           = g.Node 'Terms', g.ZeroOrMore Term #  Our Entry Point
CListTerm       = g.Delay()
CListTerms      = g.Node 'CListTerms', g.ZeroOrMore CListTerm
Quotation       = g.Node 'Quotation', g.Char('[').and WS.and Terms.and WS.and g.Char ']'
CList           = g.Node 'CList', g.Char('{').and WS.and CListTerms.and WS.and g.Char '}'
Define          = g.Node 'Define', g.MatchString('def').and WS.and Symbol.and WS.and Quotation

CListTerm.set (Define.or Atom.or Quotation).and WS
Term.set (Define.or Atom.or Quotation.or CList).and WS

module.exports = Terms

return unless require.main is module

res = Terms.parse '5 10 div .'
#res= Terms.parse('def neg [0 swap -]')

for el in res
    console.log el
    for sel in el.nodes
        console.log "\tSUB: #{sel}"
        for ssel in sel.nodes
            console.log "\t\tSUBSUB: #{ssel}"
            for sssel in ssel.nodes
            	console.log "\t\t\tSUBSUBSUB: #{sssel}"

console.log ''
console.log "RESULT: #{res}"
