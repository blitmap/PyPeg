Array::popn ?= (n = 1) -> @pop() for _ in [ 0 ... Math.max n, 0 ]

range = (start = 0, stop, step = 1) ->
	if arguments.length < 2
		stop  = start
		start = 0
		
	return (i for i in [ start ... stop ] by step)

class FactorEvaluator
	constructor: -> @reset()

	reset: ->
		@inner_func = {}
		@Values = []

		# define aliases statically
		@Functions =
			'bi@' : 'bi_at'
			'+'   : 'add'
			'-'   : 'sub'
			'*'   : 'mul'
			'/'   : 'div'
			'eq?' : 'eq'
			'='   : 'eq'
			'.'   : 'println'
			
		same = """
			abs add
			bi
			call clear count
			div dup
			each even
			gteq
			if
			keep
			len list lteq
			map mul
			n
			pop
			reduce
			sub sum swap
			times
			upper
			"""

		@Functions[v] = v for v in same.split /\s+/

	fct_add: ->
		[ a, b ] = @Values.popn 2
		@Values.push a + b

	fct_sub: ->
		[ a, b ] = @Values.popn 2
		@Values.push b - a

	fct_mul: ->
		[ a, b ] = @Values.popn 2
		@Values.push a * b

	fct_div: ->
		[ a, b ] = @Values.popn 2
		@Values.push b / a

	fct_eq: ->
		[ a, b ] = @Values.popn 2
		@Values.push a is b

	fct_gteq: ->
		[ a, b ] = @Values.popn 2
		@Values.push b >= a

	fct_lteq: ->
		[ a, b ] = @Values.popn 2
		@Values.push b <= a

	fct_abs: ->
		x = @Values.pop()
		@Values.push Math.abs x

	fct_println: ->
		x = @Values.pop()
		@Values.push x

	fct_pop: ->
		@Values.pop()
	
	fct_call: ->
		quotation = @Values.pop()
		#> "Quotation:",quotation.nodes[0]
		@eval_me quotation.nodes[0]

	fct_clear: ->
		@Values = []
	
	fct_dup: ->
		val = @Values.pop()
		@Values.push(val)
		@Values.push(val)
	
	fct_count: ->
		@Values.push @Values.length
   
	fct_even: ->
		val = @Values.pop()
		@Values.push( val % 2 )
   
	fct_if: ->
		ffalse = @Values.pop()
		ftrue  = @Values.pop()
		truth  = @Values.pop()
		if truth
			@Values.push(ftrue)
		else
			@Values.push(ffalse)
		@fct_call()
 
	fct_n: ->
		n = @Values.pop()
		@Values.push(range(n))
   
	fct_reduce: ->
		func	 = @Values.pop()
		elements = @Values.pop()
		results = []
		for element in elements
			newstack = new FactorEvaluator()
			newstack.eval_me(Terms.parse(func))
			if newstack.Values.pop()
				results.push(element)
		@Values.push(results)

	fct_swap: -> @Values.push @Values.popn(2)...
#		a = @Values.pop()
#		b = @Values.pop()
#		@Values.push(a)
#		@Values.push(b)
	
	fct_list: ->
		quot = @Values.pop()
		stk  = @Values # keep track of the old Stack

		newlist = []
		@Values = []

		@eval_me quot.nodes[0]
		for el in @Values
			newlist.push(el)
		stk.push(newlist)
		@Values = stk
		stk = null
   
	fct_map: ->
		quot	= @Values.pop()
		thelist = @Values.pop()
		new_list = []
		for el in thelist
			@Values.push( el )
			@Values.push(quot)
			@fct_call()
			new_list.push(@Values.pop())
		@Values.push(new_list)
	
	fct_keep: ->
		@fct_swap()
		@fct_dup()
		last_el = @Values.pop()
		@fct_swap()
		@fct_call()
		@Values.push( last_el )

	fct_len: ->
		k = @Values.pop()
		@Values.push k.length

	fct_upper: ->
		k = @Values.pop()
		@Values.push k.toUpperCase()

	fct_sum: ->
		l = @Values.pop()
		@Values.push(l)
		s=0
		for el in l
			s += el
		@Values.push( s )

	fct_each: ->
		# (List quot each)
		quot	 = @Values.pop()
		myList   = @Values.pop()
		newstack = new FactorEvaluator()

		for elem in myList
			newstack.pushList([elem,quot]) # remember it is backward ?
			newstack.fct_call()
			s = newstack.Values.pop()
			@push s

	fct_times: ->
		quot   = @Values.pop()
		ntimes = int(@Values.pop())
		#for i in range(ntimes): #[0:ntimes]:
		for i in [0 ... ntimes]
			@Values.push( quot )
			@fct_call()

	get_last: ->
		x = null

		if @Values.length > 0
			x = @Values.pop()
			@Values.push(x)
		else
			x = "<<<EMPTY STACK>>>"
		return x

	push: (x) ->
		@Values.push(x)
	
	pushList: (aList) ->
		for el in aList
			@Values.push(el)

	fct_bi: ->
		#bi ( x p q - )  Apply p to x, then apply q to x
		[ q, p, x ] = @Values.popn 3
#		q   = @Values.pop()
#		p   = @Values.pop()
#		x   = @Values.pop()

		for elem in [p,q]
			newstack = new FactorEvaluator()
			newstack.pushList [x, elem] # remember it is backward ?
			newstack.fct_call()
			s = newstack.Values.pop()
			@push(s)

	fct_bi_at: ->
		#bi ( x y quot - )  Apply quot to x, then apply quot to y
		[ q, x, y ] = @Values.popn 3
#		q   = @Values.pop()
#		x   = @Values.pop()
#		y   = @Values.pop()

		for elem in [x,y]
			newstack = new FactorEvaluator()
			newstack.pushList([elem,q]) # remember it is backward ?
			newstack.fct_call()
			s = newstack.Values.pop()
			@push(s)
	##  
	## == EVALUATION == 
	## 

	eval_atom_entity: (n) ->
		if n.label in ['Int', 'Float']
			return float(n.text())
		else if n.label is 'String'
			return n.text()[1:-1]
		else
			return "<<NOT EVALUATED>>"

	eval_me: (n) ->
		options =
			Int:       @clbck_int_push,
			Float:     @clbck_float_push,
			String:    @clbck_str_push,
			Quotation: @clbck_quot_push,
			CList:     @clbck_clist,
			Terms:     @clbck_terms,
			Atom:      @clbck_terms,
			Term:      @clbck_term,
			Symbol:    @clbck_symbol,
			Define:    @clbck_define,
			Default:   @clbck_default

		## Emulate a switch/case with the options dictionnary
		test_value = n.label
		if test_value in options.keys()
			options[n.label](n)
		else
			options["Default"](n)

	# Callbacks
	clbck_int_push: (n) ->
		@Values.push( int(n.text()) )

	clbck_float_push: (n) ->
		@Values.push( float(n.text()) )

	clbck_str_push: (n) ->
		@Values.push n.text()[1...-1]

	clbck_quot_push: (n) ->
		@Values.push n

	clbck_clist: (n) ->
		k = []
		for el in n.getNode('CListTerms').nodes
			conv = @eval_atom_entity(el.nodes[0])
			k.push( conv )
		@Values.push(k)

	clbck_terms: (n) ->
		for t in n.nodes
			@eval_me(t)

	clbck_term: (n) ->
		@eval_me(n.nodes[0])

	clbck_symbol: (n) ->
		to_do = n.text()
		if to_do in @inner_func.keys()
			@Values.push( @inner_func[to_do] )
			@fct_call()
		else
			method = @Functions["fct_#{n.text()}"]
			if method instanceof Function
				return method()

	clbck_define: (n) ->
		z = n.getNode 'Quotation'
		@inner_func[ n.getNode("Symbol").text() ] = z

	clbck_default: (n) -> console.log "Cannot evaluate Node of type #{n.label}"

module.export = FactorEvaluator
