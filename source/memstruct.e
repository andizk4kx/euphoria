include common.e
include emit.e
include error.e
include fwdref.e
include global.e
include msgtext.e
include parser.e
include platform.e
include reswords.e
include scanner.e
include symtab.e

include std/dll.e
include std/stack.e

integer is_union = 0
symtab_pointer last_sym = 0
symtab_index mem_struct

integer mem_pack = 0
stack pack_stack = stack:new()

export procedure MemUnion_declaration( integer scope )
	is_union = 1
	MemStruct_declaration( scope )
	is_union = 0
end procedure

function primitive_size( integer primitive )
	switch primitive do
		case MS_CHAR then
			return 1
		case MS_SHORT then
			return 2
		case MS_INT then
			return sizeof( C_INT )
		case MS_LONG then
			return sizeof( C_LONG )
		case MS_LONGLONG then
			return sizeof( C_LONGLONG )
		case MS_OBJECT then
			return sizeof( C_POINTER )
		case MS_FLOAT then
			return 4
		case MS_DOUBLE then
			return 8
		case MS_EUDOUBLE then
			ifdef E32 then
				return 8
			elsifdef E64 then
				-- same as long double
				return 16
			end ifdef
	end switch
end function

constant
	MULTI_CHAR          = { MS_CHAR },
	MULTI_SHORT         = { MS_SHORT },
	MULTI_INT           = { MS_INT },
	MULTI_LONG          = { MS_LONG },
	MULTI_LONG_INT      = { MS_LONG, MS_INT },
	MULTI_LONG_LONG     = { MS_LONG, MS_LONG },
	MULTI_LONG_LONG_INT = { MS_LONG, MS_LONG, MS_INT },
	MULTI_LONG_DOUBLE   = { MS_LONG, MS_DOUBLE },
	$

enum
	MULTI_PARSE_SIGNED,
	MULTI_PARSE_ID,
	MULTI_PARSE_SYM
	

enum
	MEMSTRUCT_THISLINE,
	MEMSTRUCT_BP,
	MEMSTRUCT_LINE_NUMBER,
	MEMSTRUCT_CURRENT_FILE_NO,
	$

function get_line_info()
	return { ThisLine, bp, line_number, current_file_no }
end function

procedure set_line_info( sequence line_info )
	if length( line_info ) then
		ThisLine        = line_info[MEMSTRUCT_THISLINE]
		bp              = line_info[MEMSTRUCT_BP]
		line_number     = line_info[MEMSTRUCT_LINE_NUMBER]
		current_file_no = line_info[MEMSTRUCT_CURRENT_FILE_NO]
	end if
end procedure

function multi_part_memtype( token tok, integer terminator = MS_AS )
	integer tid = tok[T_ID]
	integer sym = tok[T_SYM]
	integer signed = tid != MS_UNSIGNED
	integer sign_specified = 1
	sequence parts = {}
	if signed and tid != MS_SIGNED then
		putback( tok )
		sign_specified = 0
	end if
	
	for i = 1 to 4 do
		-- 3 is the most we can have, and then we better his an MS_AS...
		tok = next_token()
		tid = tok[T_ID]
		
		switch tid do
			case MS_CHAR, MS_SHORT, MS_INT then
				parts &= tid
				sym = tok[T_SYM]
				exit
			case MS_LONG then
				parts &= tid
				sym = tok[T_SYM]
			
			case MS_DOUBLE then
				if sign_specified then
					CompileErr( FP_NOT_SIGNED )
				end if
				parts &= tid
				sym = tok[T_SYM]
				exit
				
			case MS_FLOAT then
				if sign_specified or length( parts ) then
					CompileErr( FP_NOT_SIGNED )
				end if
				parts &= tid
				sym = tok[T_SYM]
				exit
			case else
				
				if tid = terminator then
					putback( tok )
					exit
				end if
				
				if sign_specified and not length( parts ) then
					CompileErr( EXPECTED_PRIMITIVE_MEMSTRUCT_TYPE )
				end if
				parts &= tid
				sym = tok[T_SYM]
				exit
		end switch
	end for
	
	-- validate...
	switch parts do
		case MULTI_CHAR, MULTI_SHORT, MULTI_INT then
			tid = parts[$]
		
		case MULTI_LONG, MULTI_LONG_INT then
			tok = MS_LONG
			
		case MULTI_LONG_LONG, MULTI_LONG_LONG_INT then
			tid = MS_LONGLONG
			sym = ms_longlong_sym
			
		case MULTI_LONG_DOUBLE then
			if not sign_specified then
				tid = MS_LONGDOUBLE
				sym = ms_longdouble_sym
			else
				-- error!
				CompileErr( FP_NOT_SIGNED )
			end if
		
	end switch
	return { signed, tid, sym }
end function

--**
-- Special parser for sizeof().  Handles multi-part primitive
-- memstruct types.
-- 
-- Returns: 1 if the argument was parsed and emitted, otherwise,
--          returns 0, which means that normal argument parsing
--          should occur.
export function parse_sizeof()
	tok_match( LEFT_ROUND )
	enter_memstruct( 1 )
	integer parsed = 1
	
	token tok = next_token()
	switch tok[T_ID] do
		case MS_SIGNED, MS_UNSIGNED, MS_LONG then
			
			sequence multi = multi_part_memtype( tok, RIGHT_ROUND )
			emit_opnd( multi[MULTI_PARSE_SYM] )
			
		case MS_INT, MS_CHAR, MS_SHORT, MS_DOUBLE, MS_FLOAT, MS_EUDOUBLE,
			MEMSTRUCT, MEMTYPE, MEMUNION then
			
			emit_opnd( tok[T_SYM] )
		
		case OBJECT, MS_OBJECT, MS_POINTER then
				ifdef EU_EX then
					-- some extra stuff gets put in the eu backend
					-- at the beginning of the SymTab
					emit_opnd( 157 )
				elsedef
					-- WARNING: Magic number from the keylist!
					emit_opnd( 152 )
				end ifdef
		case else
			if SymTab[tok[T_SYM]][S_SCOPE] = SC_UNDEFINED then
				integer ref = new_forward_reference( MEMSTRUCT, tok[T_SYM], SIZEOF )
				emit_opnd( -ref )
			else
				putback( tok )
				parsed = 0
			end if
		
	end switch
	leave_memstruct()
	return parsed
end function

--**
-- Parse a memstruct access for a memstruct base function
-- like offsetof, addressof
export procedure parse_memstruct_func( integer op )
	tok_match( LEFT_ROUND )
	-- The funcs eat this, so it doesn't need to be real
	Push( 0 )
	enter_memstruct( 1 )
	MemStruct_access( 1, FALSE )
	leave_memstruct()
	tok_match( RIGHT_ROUND )
end procedure

--**
-- Parses one memtype declaration.
procedure parse_memtype( integer scope )
	token mem_type = next_token()
	if mem_type[T_ID] = DOLLAR then
		return
	end if
	
	sequence signed_type = multi_part_memtype( mem_type )
	
	symtab_index type_sym = signed_type[MULTI_PARSE_SYM]
	
	tok_match( MS_AS )
	
	token new_memtype = next_token()
	
	symtab_index sym = new_memtype[T_SYM]
	symtab:DefinedYet( sym )
	SymTab[sym] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[sym] ) )
	SymTab[sym][S_SCOPE]      = scope
	SymTab[sym][S_TOKEN]      = MEMTYPE
	SymTab[sym][S_MODE]       = M_NORMAL
	SymTab[sym][S_MEM_SIGNED] = signed_type[MULTI_PARSE_SIGNED]
	
	switch signed_type[MULTI_PARSE_ID] do
		case MS_SIGNED, MS_UNSIGNED, 
			MS_LONG, MS_LONGLONG,
			MS_CHAR, MS_SHORT, MS_INT, 
			MS_FLOAT, MS_DOUBLE, MS_EUDOUBLE, 
			MS_OBJECT
		then
			SymTab[sym][S_MEM_TYPE]   = signed_type[MULTI_PARSE_ID]
			SymTab[sym][S_MEM_PARENT] = type_sym
			SymTab[sym][S_MEM_SIZE]   = primitive_size( signed_type[MULTI_PARSE_ID] )
		
		case else
			
			SymTab[sym][S_MEM_PARENT] = type_sym
			SymTab[sym][S_MEM_SIZE]   = SymTab[type_sym][S_MEM_SIZE]
			
			if not TRANSLATE and SymTab[sym][S_MEM_SIZE] < 1 then
				SymTab[sym][S_MEM_SIZE] = recalculate_size( type_sym )
				-- mark it as a forward reference to have its size recalculated
				
				integer ref = new_forward_reference( MEMTYPE, sym, MEMSTRUCT_DECL )
				set_data( ref, sym )
				add_recalc( type_sym, sym )
				Show( sym ) -- creating a fwdref removes the symbol, but we just want to recalc the size later on
			end if
	end switch
end procedure

--*
-- Creates an alias for a memstruct type.  May be a primitive or
-- a memstruct.  Multiple memtypes may be declared at once, separated
-- by commas, possibly ending with a list terminating $.
export procedure MemType( integer scope )
	enter_memstruct( 1 )
	
	token tok = { COMMA, 0 }
	while tok[T_ID] = COMMA do
		parse_memtype( scope )
		tok = next_token()
	end while
	putback( tok )
	
	leave_memstruct()
end procedure

procedure DefinedYet( symtab_index sym )
	sequence name = sym_name( sym )
	symtab_pointer mem_entry = mem_struct
	
	while mem_entry with entry do
		if equal( sym_name( mem_entry ), name ) then
			CompileErr(31, {name})
		end if
	entry
		mem_entry = SymTab[mem_entry][S_MEM_NEXT]
	end while
end procedure

export procedure MemStruct_declaration( integer scope )
	token tok = next_token() -- name
	mem_struct = tok[T_SYM]
	symtab:DefinedYet( mem_struct )
	enter_memstruct( mem_struct )
	last_sym = mem_struct
	integer declaring_memstruct = mem_struct
	SymTab[mem_struct] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[mem_struct] ) )
	if is_union then
		SymTab[mem_struct][S_TOKEN] = MEMUNION
	else
		SymTab[mem_struct][S_TOKEN] = MEMSTRUCT
	end if
	SymTab[mem_struct][S_SCOPE] = scope
	
	mem_pack = 0
	
	tok = next_token()
	if tok[T_ID] = WITH then
		No_new_entry = 1
		tok = next_token()
		if compare( tok[T_SYM], "pack" ) then
			sequence actual
			if sequence( tok[T_SYM] ) then
				actual = tok[T_SYM]
			else
				actual = sym_name( tok[T_SYM] )
			end if
			CompileErr(68, {"pack", actual })
		end if
		
		No_new_entry = 0
		tok = next_token()
		if tok[T_ID] != ATOM then
			CompileErr(68, {"atom", LexName( tok[T_ID] )} )
		end if
		mem_pack = sym_obj( tok[T_SYM] )
		SymTab[mem_struct][S_MEM_PACK] = mem_pack
	else
		putback( tok )
	end if
	
	sequence line_info = get_line_info()
	
	integer pointer = 0
	integer signed  = -1
	integer long    = 0
	integer eu_type = 0
	while 1 with entry do
		integer tid = tok[T_ID]
		
		if tid = MEMTYPE then
			symtab_index memtype_sym = tok[T_SYM]
			tid = SymTab[memtype_sym][S_MEM_TYPE]
			if not tid then
				symtab_index type_sym = SymTab[memtype_sym][S_MEM_PARENT]
				tid = sym_token( type_sym )
				tok[T_SYM] = type_sym
				tok[T_ID]  = tid
			end if
		end if
		
		switch tid label "token" do
			case END then
				-- eventually, we probably need to handle ifdefs,
				-- which may be best handled by refactoring Ifdef_Statement in parser.e
				if is_union then
					tok_match( MEMUNION_DECL, END )
				else
					tok_match( MEMSTRUCT_DECL, END )
				end if
				exit
			
			case TYPE, QUALIFIED_TYPE then
				tok_match( MS_AS )
				eu_type = tok[T_SYM]
				
			case MEMSTRUCT, MEMUNION, QUALIFIED_MEMSTRUCT, QUALIFIED_MEMUNION then
				-- embedding
				MemStruct_member( tok, pointer, , line_info )
				-- reset the flags
				pointer = 0
				long    = 0
				signed  = -1
			
			case VARIABLE, QUALIFIED_VARIABLE then
				if SC_UNDEFINED = SymTab[tok[T_SYM]][S_SCOPE] then
					-- forward reference
					
					if pointer then
						integer ref = new_forward_reference( TYPE, tok[T_SYM], MEMSTRUCT )
						MemStruct_member( tok, pointer, 1, line_info )
					else
					
						token nt = next_token()
						if nt[T_ID] = MS_AS then
							-- a forward reference to a type
							integer ref = new_forward_reference( TYPE, tok[T_SYM], MEMSTRUCT )
							eu_type = -ref
							break "token"
						else
							putback( nt )
							MemStruct_member( tok, pointer, 1, line_info )
						end if
					end if
					
				else
					CompileErr( EXPECTED_VALID_MEMSTRUCT )
				end if
				-- reset the flags
				pointer = 0
				long    = 0
				signed  = -1
				
			case MS_SIGNED then
				if signed != -1 then
					-- error...multiple signed modifiers
					CompileErr( EXPECTED_VALID_MEMSTRUCT )
				end if
				signed = 1
			
			case MS_UNSIGNED then
				if signed != -1 then
					-- error...multiple signed modifiers
					CompileErr( EXPECTED_VALID_MEMSTRUCT )
				end if
				signed = 0
				
			case MS_LONG then
				token check = next_token()
				integer id = check[T_ID]
				if id = MS_INT or id = MS_LONG or id = MS_DOUBLE then
					long = 1
					tid = id
					tok = check
				else
					putback( check )
				end if
				fallthru
			case MS_CHAR, MS_SHORT, MS_INT, MS_FLOAT, MS_DOUBLE, MS_EUDOUBLE, MS_OBJECT then
				
				switch tid do
					case MS_CHAR then
						Char( eu_type, pointer, signed )
					case MS_SHORT then
						Short( eu_type, pointer, signed )
					case MS_INT then
						if long then
							Long( eu_type, pointer, signed )
						else
							Int( eu_type, pointer, signed )
						end if
					case MS_LONG then
						token int_tok = next_token()
						
						if long then
							-- this is the second long...
							if int_tok[T_ID] = MS_INT then
								-- long long int
								LongLong( eu_type, pointer, signed )
							
							elsif int_tok[T_ID] = VARIABLE
							or int_tok[T_ID] = PROCEDURE
							or int_tok[T_ID] = FUNCTION
							or int_tok[T_ID] = TYPE
							or int_tok[T_ID] = NAMESPACE
							then
								-- long long
								putback( int_tok )
								LongLong( eu_type, pointer, signed )
							else
								CompileErr( 25, { sym_name( int_tok[T_SYM] ) } )
							end if
						elsif int_tok[T_ID] = MS_DOUBLE then
							long = 1
							putback( int_tok )
							-- need to skip the part where the flags get reset
							break "token"
						else
							putback( int_tok )
							Long( eu_type, pointer, signed )
						end if
						
					case MS_FLOAT, MS_DOUBLE, MS_EUDOUBLE then
						if signed != - 1 then
							-- can't have signed modifiers here
							CompileErr( FP_NOT_SIGNED )
						end if
						
						if long and tid != MS_DOUBLE then
							-- long modifier only for doubles
							CompileErr( ONLY_DOUBLE_FP_LONG )
						elsif long then
							tid = MS_LONGDOUBLE
						end if
						
						FloatingPoint( eu_type, tid, pointer )
					
					case MS_OBJECT then
						Object( eu_type, pointer, signed )
					
					case else
						
				end switch
				symtab_index type_sym = tok[T_SYM]
				
				-- reset the flags
				pointer = 0
				long    = 0
				signed  = -1
				eu_type = 0
			
			case MS_POINTER then
				-- pointer!
				pointer = 1
				
			case else
				CompileErr( EXPECTED_VALID_MEMSTRUCT )
		end switch
	entry
		tok = next_token()
	end while
	calculate_size()
	if not TRANSLATE and SymTab[declaring_memstruct][S_MEM_SIZE] < 1 then
		-- make sure we come back to this to resize:
		integer child = declaring_memstruct
		while child with entry do
			if SymTab[child][S_MEM_SIZE] <= 0 then
				add_recalc( SymTab[child][S_MEM_STRUCT], declaring_memstruct )
			end if
		entry
			child = SymTab[child][S_MEM_NEXT]
		end while
	end if
	leave_memstruct()
end procedure


--*
-- Returns the size and offsets, or -1 if all
-- sizes have not been determined yet.
export function recalculate_size( symtab_index sym )
	mem_struct = sym
	is_union   = sym_token( sym ) = MEMUNION_DECL
	integer size = calculate_size()
	
	is_union = 0
	if size > 0 then
		SymTab[sym][S_MEM_SIZE] = size
		
		for i = 2 to length( SymTab[sym][S_MEM_RECALC] ) do
			
			symtab_index recalc_sym =  SymTab[sym][S_MEM_RECALC][i]
			
			if SymTab[recalc_sym][S_MEM_STRUCT] = sym then
				if SymTab[recalc_sym][S_MEM_ARRAY] then
					SymTab[recalc_sym][S_MEM_SIZE] = size * SymTab[recalc_sym][S_MEM_ARRAY]
				else
					SymTab[recalc_sym][S_MEM_SIZE] = size
				end if
				
			else
				SymTab[recalc_sym][S_MEM_SIZE] = recalculate_size( recalc_sym )
			end if
		end for
	end if
	return size
end function

--**
-- When parent_struct gets its size definitively calculated,
-- recalculate dependent_struct.
procedure add_recalc( symtab_index parent_struct, symtab_index dependent_struct )
	if parent_struct != dependent_struct
	and length( SymTab[parent_struct] ) >= SIZEOF_MEMSTRUCT_ENTRY
	and (atom( SymTab[parent_struct][S_MEM_RECALC] )
		or not find( dependent_struct, SymTab[parent_struct][S_MEM_RECALC] )) then
		SymTab[parent_struct][S_MEM_RECALC] &= dependent_struct
	end if
end procedure

--**
-- Return the alignment required for the memstruct passed.
-- Returs 0 if the alignment cannot yet be determined.
function calculate_alignment( symtab_index member_sym )
	integer alignment = 0
	
	if SymTab[member_sym][S_MEM_STRUCT] then
		member_sym = SymTab[member_sym][S_MEM_STRUCT]
	end if
	
	integer sym = member_sym
	if SymTab[sym][S_MEM_SIZE] = -1 then
		-- we haven't determined the size yet for this
		return -1
	end if
	
	integer sub_alignment = 0
	while sym with entry do
		if SymTab[sym][S_MEM_POINTER] then
			sub_alignment = sizeof( C_POINTER )
		elsif sym_token( sym ) = MS_MEMBER then
			sub_alignment = calculate_alignment( sym )
			if not sub_alignment then
				return -1
			end if
		else
			-- 32-bit *nix aligns double on 4-byte boundary
			if IX86 and IUNIX and sym_token( sym ) = MS_DOUBLE then
				sub_alignment = 4
			else
				if SymTab[sym][S_MEM_ARRAY] then
					sub_alignment = SymTab[sym][S_MEM_SIZE] / SymTab[sym][S_MEM_ARRAY]
				else
					sub_alignment = SymTab[sym][S_MEM_SIZE]
				end if
			end if
		end if
		if sub_alignment > alignment then
			alignment = sub_alignment
		end if
	entry
		sym = SymTab[sym][S_MEM_NEXT]
	end while
	
	if mem_pack and alignment > mem_pack then
		alignment = mem_pack
	end if
	return alignment
end function

--**
-- Calculates how much padding is needed
function calculate_padding( symtab_index member_sym, integer size, integer mem_size )
	integer padding = 0
	integer r = 0
	integer alignment = 0
	
	if SymTab[member_sym][S_MEM_POINTER] then
		if mem_pack and mem_pack < sizeof( C_POINTER ) then
			r = remainder( size, mem_pack )
			alignment = mem_pack
		else
			r = remainder( size, sizeof( C_POINTER ) )
		end if
	elsif sym_token( member_sym ) = MS_MEMBER then
		alignment = calculate_alignment( member_sym )
		if alignment = -1 then
			return -1
		elsif alignment then
			r = remainder( size, alignment )
		end if
	else
		if SymTab[member_sym][S_MEM_ARRAY] then
			mem_size /= SymTab[member_sym][S_MEM_ARRAY]
		end if
		
		-- 32-bit *nix aligns double on 4-byte boundary
		if sym_token( member_sym ) = MS_DOUBLE and IX86 and IUNIX then
			if mem_pack and mem_pack < 4 then
				r = remainder( size, mem_pack )
				alignment = mem_pack
			else
				r = remainder( size, 4 )
				alignment = 4
			end if
		else
			
			if mem_pack and mem_pack < mem_size then
				r = remainder( size, mem_pack )
				alignment = mem_pack
			else
				r = remainder( size, mem_size )
				alignment = mem_size
			end if
			
			
		end if
	end if
	
	if alignment then
		if r then
			padding = alignment - r
		end if
	end if
	return padding
end function

procedure pop_pack_stack( object x )
	mem_pack = stack:pop( pack_stack )
end procedure

--**
-- Returns the size and offsets for the memstruct, or -1 if all
-- sizes have not been determined yet.
function calculate_size()
	symtab_pointer member_sym = mem_struct
	
	
	if sym_token( member_sym ) = MEMTYPE then
		if SymTab[SymTab[member_sym][S_MEM_PARENT]][S_MEM_SIZE] < 1 then
			SymTab[SymTab[member_sym][S_MEM_PARENT]][S_MEM_SIZE] = recalculate_size( SymTab[member_sym][S_MEM_PARENT] )
		end if
		return SymTab[SymTab[member_sym][S_MEM_PARENT]][S_MEM_SIZE]
	end if
	
	integer was_union = is_union
	is_union = sym_token( member_sym ) = MEMUNION
	
	stack:push( pack_stack, mem_pack )
	mem_pack = SymTab[member_sym][S_MEM_PACK]
	
	-- clean up the stack...
	atom current_pack = delete_routine( mem_pack, routine_id( "pop_pack_stack" ) )
	
	integer size = 0
	integer indeterminate = 0
	while member_sym and not indeterminate with entry do
		integer mem_size = SymTab[member_sym][S_MEM_SIZE]
		if mem_size < 1 then
			-- might be a struct that's been recalculated
			symtab_pointer struct_type = SymTab[member_sym][S_MEM_STRUCT]
			if struct_type then
				mem_size = SymTab[struct_type][S_MEM_SIZE]
				if mem_size < 1 then
					if length( SymTab[struct_type] ) >= SIZEOF_MEMSTRUCT_ENTRY then
						mem_size = recalculate_size( struct_type )
					end if
					if mem_size < 1 then
						indeterminate = 1
						add_recalc( mem_struct, struct_type )
					end if
				end if
			else
				indeterminate = 1
			end if
		end if
		if not indeterminate then
			if not is_union then
				-- make sure we're properly aligned
				integer padding = calculate_padding( member_sym, size, mem_size )
				
				if padding < 0 then
					indeterminate = 1
				elsif padding then
					size += padding
				end if
				
				SymTab[member_sym][S_MEM_OFFSET] = size
				size += mem_size
			else
				if mem_size > size then
					size = mem_size
				end if
			end if
		end if
	entry
		member_sym = SymTab[member_sym][S_MEM_NEXT]
	end while
	
	is_union = was_union
	
	if indeterminate then
		SymTab[mem_struct][S_MEM_SIZE] = 0
		return 0
	else
		SymTab[mem_struct][S_MEM_SIZE] = size
		integer alignment = calculate_alignment( mem_struct )
		if alignment then
			integer r = remainder( size, alignment )
			if r then
				integer padding = alignment - r
				size += padding
			end if
		end if
		SymTab[mem_struct][S_MEM_SIZE] = size
		return size
	end if
end function

function read_name()
	token tok = next_token()
	switch tok[T_ID] do
		case VARIABLE, PROC, FUNC, TYPE, 
				MS_CHAR, MS_SHORT, MS_INT, MS_LONG, MS_LONGLONG, MS_OBJECT, 
				MS_FLOAT, MS_DOUBLE, MS_LONGDOUBLE, MS_EUDOUBLE,
				MS_MEMBER then
			
			DefinedYet( tok[T_SYM] )
			
			symtab_index member = NewBasicEntry( sym_name( tok[T_SYM] ), 0, SC_MEMSTRUCT, MS_MEMBER, 0, 0, 0 )
			SymTab[member] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[member] ) )
			
			return { MS_MEMBER, member }
		
		case else
			CompileErr( 68, {"identifier", LexName( tok[T_ID] )} )
	end switch
end function

function member_array( symtab_index sym )
	token tok = next_token()
	if tok[T_ID] != LEFT_SQUARE then
		putback( tok )
		return 1
	end if
	
	tok = next_token()
	object size = sym_obj( tok[T_SYM] )
	if not integer( size ) or size < 1 then
		CompileErr( 68, {"positive integer", LexName( tok[T_ID] ) } )
	end if
	
	SymTab[sym][S_MEM_ARRAY] = sym_obj( tok[T_SYM] )
	tok_match( RIGHT_SQUARE )
	return size
end function

procedure add_member( integer type_sym, token name_tok, object mem_type, integer size, integer pointer, integer signed = 0, sequence line_info = {} )
	
	symtab_index sym = name_tok[T_SYM]
	
	SymTab[last_sym][S_MEM_NEXT] = sym
	
	SymTab[sym] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[sym] ) )
	
	size *= member_array( sym )
	
	if token( mem_type ) then
		SymTab[sym][S_MEM_STRUCT] = mem_type[T_SYM]
		mem_type = MS_MEMBER
	end if
	
	if pointer then
		size = sizeof( C_POINTER )
	elsif SymTab[sym][S_MEM_STRUCT] = mem_struct then
		set_line_info( line_info )
		CompileErr( MEMBER_DIRECT_REFERENCE, { sym_name( mem_struct ), sym_name( sym ) } )
	end if
	
	if signed = -1 then
		signed = 1
	end if
	
	SymTab[sym][S_SCOPE]       = SC_MEMSTRUCT
	SymTab[sym][S_TOKEN]       = mem_type
	SymTab[sym][S_MEM_SIZE]    = size
	SymTab[sym][S_MEM_POINTER] = pointer
	SymTab[sym][S_MEM_SIGNED]  = signed
	SymTab[sym][S_MEM_PARENT]  = mem_struct
	SymTab[sym][S_MEM_TYPE]    = type_sym
	
	if type_sym < 0 then
		register_forward_type( sym, -type_sym )
	end if

	if size < 1 then
		add_recalc( SymTab[sym][S_MEM_STRUCT], sym )
	end if
	last_sym = sym
end procedure

procedure Char( integer eu_type, integer pointer, integer signed )
	add_member( eu_type, read_name(), MS_CHAR, 1, pointer, signed )
end procedure

procedure Short( integer eu_type, integer pointer, integer signed )
	add_member( eu_type, read_name(), MS_SHORT, 2, pointer, signed )
end procedure

procedure Int( integer eu_type, integer pointer, integer signed )
	add_member( eu_type, read_name(), MS_INT, sizeof( C_INT ), pointer, signed )
end procedure

procedure Long( integer eu_type, integer pointer, integer signed )
	add_member( eu_type, read_name(), MS_LONG, sizeof( C_LONG ), pointer, signed )
end procedure

procedure LongLong( integer eu_type, integer pointer, integer signed )
	add_member( eu_type, read_name(), MS_LONGLONG, sizeof( C_LONGLONG ), pointer, signed )
end procedure

procedure FloatingPoint( integer eu_type, integer fp_type, integer pointer )
	token name_tok = read_name()
	integer size
	switch fp_type do
		case MS_FLOAT then
			size = 4
		case MS_DOUBLE then
			size = 8
		case MS_LONGDOUBLE then
			-- these get padded out in structs to a full 16 bytes
			-- the data is actually only 10 bytes in size
			size = 16
		case MS_EUDOUBLE then
			ifdef E32 then
				size = 8
			elsifdef E64 then
				-- same as long double
				size = 16
			end ifdef
	end switch
	add_member( eu_type, name_tok, fp_type, size, pointer )
end procedure

procedure Object( integer eu_type, integer pointer, integer signed )
	token name_tok = read_name()
	
	add_member( eu_type, name_tok, MS_OBJECT, sizeof( E_OBJECT ), pointer, signed )
end procedure

procedure MemStruct_member( token memstruct_tok, integer pointer, integer fwd = 0, sequence line_info )
	token name_tok = read_name()
	integer size = 0
	
	if fwd then
		integer ref = new_forward_reference( MS_MEMBER, memstruct_tok[T_SYM], MEMSTRUCT_DECL )
		set_data( ref, name_tok[T_SYM] )
		SymTab[memstruct_tok[T_SYM]] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[memstruct_tok[T_SYM]] ) )
		SymTab[memstruct_tok[T_SYM]][S_SCOPE] = SC_UNDEFINED
	else
		size = SymTab[memstruct_tok[T_SYM]][S_MEM_SIZE]
	end if
	add_member( 0, name_tok, memstruct_tok, size, pointer, , line_info )
	
end procedure

export function resolve_member( sequence name, symtab_index struct_sym )
	symtab_pointer member_sym = struct_sym
	
	while member_sym with entry do
		if equal( name, sym_name( member_sym ) ) then
			return member_sym
		end if
	entry
		member_sym = SymTab[member_sym][S_MEM_NEXT]
	end while
	return 0
end function

export function resolve_members( sequence names, symtab_index struct_sym )
	symtab_pointer parent = struct_sym
	symtab_pointer sym = 0
	for i = 1 to length( names ) do
		sym = resolve_member( names[i], parent )
		if not sym then
			return 0
		end if
		parent = SymTab[sym][S_MEM_STRUCT]
	end for
	return sym
end function

function parse_symstruct( token tok )
		
	symtab_index struct_sym = tok[T_SYM]
	integer ref = 0
	if SymTab[struct_sym][S_SCOPE] = SC_UNDEFINED then
		-- a forward reference
		ref = new_forward_reference( MEMSTRUCT, struct_sym, MEMSTRUCT_ACCESS )
		
	elsif tok[T_ID] != MEMSTRUCT
	and tok[T_ID]   != QUALIFIED_MEMSTRUCT
	and tok[T_ID]   != MEMUNION
	and tok[T_ID]   != QUALIFIED_MEMUNION
	and tok[T_ID]   != MEMTYPE then
		-- something else
		CompileErr( EXPECTED_VALID_MEMSTRUCT )
	end if
	
	tok = next_token()
	if tok[T_ID] = LEFT_SQUARE then
		emit_symstruct( struct_sym, ref )
		Expr()
		tok_match( RIGHT_SQUARE )
		emit_op( MEMSTRUCT_ARRAY )
		tok = next_token()
		
		if tok[T_ID] != DOT then
			putback( tok )
			return 0
		end if
		return { struct_sym, ref }
	elsif tok[T_ID] = DOT then
		return { struct_sym, ref }
	else
		putback( tok )
		return { struct_sym, ref, 0 }
	end if
end function

procedure emit_member( integer member, integer ref, integer op, sequence names )
	if ref then
		integer m_ref = new_forward_reference( MS_MEMBER, member, op )
		add_data( ref, m_ref )
		emit_opnd( -m_ref )
		set_data( m_ref, names )
	else
		emit_opnd( member )
	end if
end procedure

procedure emit_symstruct( integer symstruct, integer ref )
	if ref then
		emit_opnd( -ref )
	else
		emit_opnd( symstruct )
	end if
end procedure

function is_pointer( symtab_index member )
	return SymTab[member][S_MEM_POINTER]
end function

--**
-- Parse the dot notation of accessing a memstruct.
export procedure MemStruct_access( symtab_index sym, integer lhs )
	-- the sym is the pointer, and just before this, we found a DOT token
	-- First, figure out which memstruct we're using
	token tok = next_token()
	
	object sym_ref = parse_symstruct( tok )
	if atom( sym_ref ) then
		-- simple array access, nothing more needed
		return
	end if
	symtab_index struct_sym = sym_ref[1]
	integer      ref        = sym_ref[2]
	mem_struct = struct_sym
	
	if length( sym_ref ) = 3 then
		-- just the sym...serialize it
		if lhs then
			emit_symstruct( struct_sym, ref )
			emit_opnd( 0 ) -- don't deref
			
			return
		else
			emit_symstruct( struct_sym, ref )
			emit_op( MEMSTRUCT_READ )
		end if
		return
	end if
	
	sequence names = { sym_name( mem_struct )}

	No_new_entry = 1
	integer members = 0
	symtab_pointer member = 0
	integer has_dot = 1
	while 1 with entry do
		integer tid = tok[T_ID]
		switch tid do
			case VARIABLE, FUNC, PROC, TYPE, NAMESPACE then
				
				if not has_dot then
					peek_member( members, member, ref, lhs, names )
					putback( tok )
					exit
				end if
				
				-- make it look like the IGNORED token
				tok= { IGNORED, SymTab[tok[T_SYM]][S_NAME] }
				fallthru
			
			case IGNORED then
				if not has_dot then
					peek_member( members, member, ref, lhs, names )
					if tid != IGNORED then
						putback( tok )
					else
						No_new_entry = 0
						putback( keyfind( tok[T_SYM], -1 ) )
					end if
					exit
				end if
				
				-- just look at it within this memstruct's context...
				names = append( names, tok[T_SYM] )
				
				if ref label "IGNORED ref" then
					-- we don't know the memstruct yet!
					member = NewBasicEntry( tok[T_SYM], 0, SC_MEMSTRUCT, MS_MEMBER, 0, 0, 00 )
					SymTab[member] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[member] ) )
					emit_member( member, ref, MEMSTRUCT_ACCESS, names )
				else
					if member then
						-- going into an embedded / linked struct or union
						integer new_struct_sym = SymTab[member][S_MEM_STRUCT]
						if new_struct_sym then
							struct_sym = new_struct_sym
							if SymTab[struct_sym][S_SCOPE] = SC_UNDEFINED then
								ref = new_forward_reference( MEMSTRUCT, struct_sym, MEMSTRUCT_ACCESS )
								member = NewBasicEntry( tok[T_SYM], 0, SC_MEMSTRUCT, MS_MEMBER, 0, 0, 00 )
								SymTab[member] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[member] ) )
								emit_member( member, ref, MEMSTRUCT_ACCESS, names )
								break "IGNORED ref"
							end if

						else
							-- unresolved memstruct type!
							ref = new_forward_reference( MEMSTRUCT, struct_sym, MEMSTRUCT_ACCESS )
							member = NewBasicEntry( tok[T_SYM], 0, SC_MEMSTRUCT, MS_MEMBER, 0, 0, 00 )
							SymTab[member] &= repeat( 0, SIZEOF_MEMSTRUCT_ENTRY - length( SymTab[member] ) )
							emit_member( member, ref, MEMSTRUCT_ACCESS, names )
							break "IGNORED ref"
						end if
					end if
					
					if SymTab[struct_sym][S_TOKEN] = MEMTYPE then
						-- use whatever it really is
						struct_sym = SymTab[struct_sym][S_MEM_PARENT]
					end if
					
					member = resolve_member( tok[T_SYM], struct_sym )
					if not member then
						CompileErr( NOT_A_MEMBER, { tok[T_SYM], sym_name( struct_sym ) } )
					elsif member > 0 then
						names = {}
					end if
					emit_opnd( member )
				end if
				
				members += 1
				has_dot = 0
				
			case MULTIPLY then
				if not has_dot then
					-- multiplying
					putback( tok )
					peek_member( members, member, ref, lhs, names, /* op */ , 0 )
					exit
				end if
				-- ptr.struct.ptr_to_something.*  fetch the value pointed to
				if not ref then
					-- make sure it's actually a pointer...
					if not SymTab[member][S_MEM_POINTER] then
						CompileErr( DEREFERENCING_NONPOINTER )
					end if
				end if
				peek_member( members, member, ref, lhs, names, /* op */ , 1 )
				exit
				
			case DOT then
				-- another layer...
				if not member then
					CompileErr( 68, {"a member name", LexName( tid )} )
				end if
				has_dot = 1
				
			case LEFT_SQUARE then
				-- array...
				if has_dot then
					-- can't do this...
				end if
				Expr()
				tok_match( RIGHT_SQUARE )
				
				tok = next_token()
				putback( tok )
				if tok[T_ID] != DOT then
					if lhs then
						peek_member( members, member, ref, lhs, names, ARRAY_ACCESS )
					else
						emit_op( PEEK_ARRAY )
					end if
					exit
				end if
				
				emit_op( MEMSTRUCT_ARRAY )
				
			case else
				peek_member( members, member, ref, lhs, names )
				putback( tok )
				exit
		end switch
	entry
		tok = next_token()
	end while
	No_new_entry = 0
end procedure

procedure peek_member( integer members, symtab_index member, integer ref, 
					   integer lhs, sequence names, integer op = MEMSTRUCT_ACCESS,
					   integer deref_ptr = 0
 					)
	
	emit_opnd( members )
	emit_op( op )
	if lhs then
		emit_member( member, ref, op, names )
		emit_opnd( deref_ptr )
	else
		-- geting the value...peek it
		emit_member( member, ref, PEEK_MEMBER, names )
		emit_opnd( deref_ptr )
		emit_op( PEEK_MEMBER )
	end if
end procedure
