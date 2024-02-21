--****
-- == Keyword Data
--
-- Keywords and routines built in to Euphoria.
--
-- <<LEVELTOC level=2 depth=4>>
--

namespace keywords

--****
-- === Constants
--

--**
-- Sequence of Euphoria keywords

public constant keywords = {
	"and",
	"as",
	"break",
	"by",
	"case",
	"constant",
	"continue",
    "deprecate",
	"do",
	"double",
	"else",
	"elsedef",
	"elsif",
	"elsifdef",
	"end",
	"entry",
	"enum",
	"exit",
	"export",
	"fallthru",
	"float",
	"for",
	"function",
	"global",
	"goto",
	"if",
	"ifdef",
	"include",
	"int",
	"label",
	"long",
	"loop",
	"memstruct",
	"memtype",
	"memunion",
	"namespace",
	"not",
	"or",
	"override",
	"pointer",
	"procedure",
	"public",
	"retry",
	"return",
	"routine",
	"signed",
	"switch",
	"then",
	"to",
	"type",
	"unsigned",
	"until",
	"while",
	"with",
	"without",
	"xor"
}

--**
-- Sequence of Euphoria's built-in function names

public constant builtins = {
	"?",
	"abort",
	"and_bits",
	"append",
	"arctan",
	"atom",
	"c_func",
	"c_proc",
	"call",
	"call_func",
	"call_proc",
	"clear_screen",
	"close",
	"command_line",
	"compare",
	"cos",
	"date",
	"delete",
	"delete_routine",
	"equal",
	"find",
	"floor",
	"get_key",
	"getc",
	"getenv",
	"gets",
	"hash",
	"head",
	"include_paths",
	"insert",
	"integer",
	"length",
	"log",
	"machine_func",
	"machine_proc",
	"match",
	"mem_copy",
	"mem_set",
	"not_bits",
	"object",
	"open",
	"option_switches",
	"or_bits",
	"peek",
	"peek2s",
	"peek2u",
	"peek4s",
	"peek4u",
	"peek8s",
	"peek8u",
	"peek_longs",
	"peek_longu",
	"peek_pointer",
	"peeks",
	"peek_string",
	"pixel",
	"platform",
	"poke",
	"poke2",
	"poke4",
	"poke8",
	"poke_long",
	"poke_pointer",
	"position",
	"power",
	"prepend",
	"print",
	"printf",
	"puts",
	"rand",
	"remainder",
	"remove",
	"repeat",
	"replace",
	"routine_id",
	"sequence",
	"sin",
	"sizeof",
	"splice",
	"sprintf",
	"sqrt",
	"system",
	"system_exec",
	"tail",
	"tan",
	"task_clock_start",
	"task_clock_stop",
	"task_create",
	"task_list",
	"task_schedule",
	"task_self",
	"task_status",
	"task_suspend",
	"task_yield",
	"time",
	"trace",
	"xor_bits"
}
