### 
    A port of Christopher Diggin's Jigsaw C# 4.0 project:
    

    Christopher Diggin's nice article explaining how to build a grammar 
    is on the CodeProject's site:
    http:#www.codeproject.com/KB/recipes/programminglanguagetoools.aspx

    Kibleur Christophe, December 2011.

    Note:
    =====

    Using cache is set inside the NodeRule.__init__ method

###

Array::isEmpty ?= -> @length is 0

isString = (s) -> (typeof s is 'string') or (s instanceof String)

###
================================================================================
                            GRAMMAR CLASS
            A class handling all the possible parsers
================================================================================
###

class Grammar
	and: (other) -> @Seq [ @, other ]
	or: (other) -> @Choice [ @, other ]
	
	Node: (name, rule) ->
		n = new NodeRule rule
		n.setName name
		return n

	At: (rule) -> new AtRule rule
	Not: (rule) -> new NotRule rule
	Choice: (rules) -> new ChoiceRule rules
	Seq: (rules) -> new SeqRule rules
	Opt: (rules) -> new OptRule rules
	ZeroOrMore: (r) -> new ZeroOrMoreRule r
	OneOrMore: (r) -> new PlusRule r
	MatchString: (s) -> new StringRule s
	Delay: -> new DelayRule
	Char: (c) -> new CharRule isString(c) and ((v) -> v is c) or c
	CharSet: (s) -> @Char (c) -> c in s
	CharRange: (min, max) -> @Char (c) -> min[0] <= c <= (max[0] or min[1]) # CharRange('az') or CharRange('a', 'z')
	Regex: (re) -> new RegexRule re
	AnyChar: -> @Char -> true
	AdvanceWhileNot: (r) ->
		unless r?
			throw new Error 'Cannot build this AdvanceWhileNot without a parser'

		return @ZeroOrMore @Seq [ @Not(r), @AnyChar() ]

###
================================================================================
                            NODE CLASS
            The grammar nodes are used by your ParserState instance
================================================================================
###

class Node
	# @begin: the start position within the string
	# @label: the name of the node
	# @inputs: the input string
	# @theend: where we stop
	constructor: (@begin, @label = '?', @inputs) ->
		@theend = @inputs.length
		@nodes = []

	length: -> Math.max @theend - @begin, 0

	isLeaf: -> @nodes.isEmpty()

	# Text associated with the parse result.
	text: -> @inputs[@begin...@theend]

	withLabel: (label) -> @getNode label
    
	# Returns the nth child node.
	nthChild: (n) -> @nodes[n]

	# Returns all child nodes with the given label
	getNodes: (label) -> @nodes.filter (n) -> n.label is label
		
	# Returns the first child node with the given label.
	getNode: (label) -> return n for n in @nodes when n.label is label

	count: -> @nodes.length

	descendants: -> c for c in n.descendants() for n in @nodes

	toString: -> "#{@label} -> '#{@text()}'"
	toRepr: -> "Node #{@label} Text: '#{@text()}'"

###
================================================================================
                            PARSERSTATE CLASS
        The ParserState is used inside the NodeRule class, it keeps an array
        of nodes (ParserState.nodes).
================================================================================
###

class ParserState
	constructor: (@inputs, @pos, @nodes = []) ->
		@cache = {}

	current: -> @inputs[@pos..]

	assign: ({ @inputs, @pos, @nodes }) ->

	clone: -> new ParserState @inputs, @pos, @nodes
    
	restoreAfter: (action) ->
		old_state = @clone()
		action()
		@assign old_state

	cacheResult: (rule, pos, node) ->
		@cache[pos]       ?= {}
		@cache[pos][rule] ?= node

	getCachedResult: (rule) ->
		n = @pos

		return [ false, null ] unless @cache[n]?

		node = @cache[n][rule]

		return [ false, null ] unless node?
		return [ true,  node ]

	toString: -> "ParserState pos: #{@pos}, len: #{@inputs.length}"
    
###
================================================================================
                            RULES CLASS
        All the following classes derive from the Rule base class.
        Each one should implement the internalMatch method.
================================================================================
###

class Rule extends Grammar
	constructor: (rules) ->
		super()
		@_name        = 'no_name'
		@children     = []
		@is_recursive = false

		if rules instanceof Array
			@children = rules
		else
			@children.push rules

    # Getters & Setters  
	name: -> @_name
 
	setName: (@_name) -> @

	child: -> @children[0]

	callAction: (param) -> @action?.match param

	childInString: -> (c for c in @children).join ', '
    
	internalMatch: (something) -> new Error 'internalMatch() must be overriden!'

	matchTest: (something) -> "Matching #{@} against '#{something}' ===> #{@match something}"

	match: (something) ->
		if something instanceof ParserState
			@internalMatch something
		else
			@match new ParserState something, 0

	parse: (input) ->
		thestate = new ParserState input, 0
		res = @match thestate

		unless res?
			console.log "Rule #{@name()} failed to match"

		return thestate.nodes

	toString: -> 'Rule Generic'
	toRepr: -> "#{@name()}"

###
================================================================================
                            DERIVED RULES CLASSES
================================================================================
###

class AtRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		old    = @clone()
		result = @child().match thestate
		thestate.assign old
		return result
    
	toString: -> "At: #{@name()}"
    
class NotRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		old = @clone()

		if @child().match thestate
			thestate.assign old
			return false

		return true

	toString: -> "Not: #{@child()}"

class NodeRule extends Rule
	constructor: ->
		super
		@_name = 'NodeRule'
		@useCache = true

	internalMatch: (thestate) ->
		if @useCache
			@internalMatchWithCaching thestate
		else
			@internalMatchWithoutCaching thestate

	internalMatchWithCaching: (thestate) ->
		start = thestate.pos

        # Remember getCachedResult returns a tuple [a,b]
        # a is a bool, b is a Node (or None)
		[ res, node ] = thestate.getCachedResult @

		# Check if the result has been cached to eventually retrieve it
		if res
			return false unless node?
			thestate.pos = node.theend
			thestate.nodes.push node
			return true
        
		# Result has not been cached
		node = new Node thestate.pos, @name(), thestate.inputs
		oldNodes = thestate.nodes
		thestate.nodes = []

		res = @child().match thestate

		if res
			node.theend = thestate.pos
			node.nodes  = thestate.nodes

			oldNodes.push node

			thestate.cacheResult @, start, node
			thestate.nodes = oldNodes
			return true
		else
			thestate.nodes = oldNodes
			thestate.cacheResult @, start, null
			return false
   
	internalMatchWithoutCaching: (thestate) ->
		node = new Node thestate.pos, @name(), thestate.inputs
		oldNodes = thestate.nodes
		thestate.nodes = []
		
		res = @child().match thestate

		if res
			node.theend = thestate.pos
			node.nodes  = thestate.nodes
			oldNodes.push node
			thestate.nodes = oldNodes
			return true
		else
			thestate.nodes = oldNodes
			return false

	toString: -> "Node: #{@child()}"

class StringRule extends Rule
	constructor: (@s) -> super()

	internalMatch: (thestate) ->
		return false unless thestate.inputs[thestate.pos..].startsWith @s

		thestate.pos += @s.length
		return true

	toString: -> "String: '#{@s}'"

class ChoiceRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		old = thestate.clone()

		for r in @children
			if r.match thestate
				return true

			thestate.assign old

		return false

	toString: -> "Choice: #{@childInString()}"

class SeqRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		old = thestate.clone()

		for r in @children
			if not r.match thestate
				thestate.assign old
				return false

		return true
				
	toString: -> "Sequence: #{@childInString()}"

class OptRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		@child().match thestate
		return true

	toString: -> "Opt: #{@childInString()}"

class ZeroOrMoreRule extends Rule
	constructor: -> super

	internalMatch: (thestate) ->
		loop
			break unless @child().match thestate

		return true

	toString: -> "ZeroOrMore: #{@children}"

class PlusRule extends Rule
	constructor: -> super

	# used for OneOrMore
	internalMatch: (thestate) ->
		return false unless @child().match thestate

		loop
			break unless @child().match thestate

		return true

	toString: -> "Plus: #{@childInString()}"

class EndRule extends Rule
	constructor: -> super

	internalMatch: (thestate) -> thestate.pos is thestate.inputs.length
    
	toString: -> 'EndRule'

class CharRule extends Rule
	constructor: (@predicate) -> super()
		
	internalMatch: (thestate) ->
		return false if thestate.pos >= thestate.inputs.length

		a = thestate.inputs[thestate.pos]

		return false unless @predicate thestate.inputs[thestate.pos]
        
		thestate.pos += 1
		return true

	toString: -> "Char: #{@predicate}"

class RegexRule extends Rule
	# XXX: in the future: default to non-consuming regexps
	constructor: (@reg, @consume = true) ->
		super()
		try
			# XXX: we can do this nicer in the future
			@reg = eval(@reg + 'g')
			@reg = eval(@reg + 'y')

	internalMatch: (thestate) ->
		@reg.lastIndex = thestate.pos
		m = @reg.exec thestate.inputs # note: requires //g

		# NOTE: regexes can match anywhere forward from thestate.pos
		return false unless m?
		
		if @consume
			thestate.pos = m.index + m[0].length

		return true

	toString: -> "RegExp: #{@reg}"

class DelayRule extends Rule
	constructor: ->
		super()
		@my_rule = null
		@children = []
		@name 'Delayed'

	set: (@my_rule) ->

	internalMatch: (parser_state) ->
		if @children.isEmpty()
			@children.push @my_rule

		return @child().match parser_state

	toString: -> 'RecursiveRule2'

module.exports = Grammar
