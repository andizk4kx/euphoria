-- (c) Copyright 2007,2008 Rapid Deployment Software - See License.txt
--
-- IL opcodes, scanner tokens etc.

global constant 
	LESS                = 1,  -- keep relops consecutive LESS..GREATER, NOT
	GREATEREQ           = 2,
	EQUALS              = 3,
	NOTEQ               = 4,
	LESSEQ              = 5,
	GREATER             = 6,
	NOT                 = 7,
	AND                 = 8,
	OR                  = 9,
	MINUS               = 10,
	PLUS                = 11,
	UMINUS              = 12,
	MULTIPLY            = 13,
	DIVIDE              = 14,
	CONCAT              = 15,
	ASSIGN_SUBS         = 16,
	GETS                = 17,
	ASSIGN              = 18,
	PRINT               = 19,
	IF                  = 20,
	FOR                 = 21,
	ENDWHILE            = 22,
	ELSE                = 23,
	OR_BITS             = 24,
	RHS_SUBS            = 25,
	XOR_BITS            = 26,  -- careful, same code as EOF
	PROC                = 27,
	RETURNF             = 28,
	RETURNP             = 29,
	PRIVATE_INIT_CHECK  = 30,
	RIGHT_BRACE_N       = 31,  -- see also RIGHT_BRACE_2
	REPEAT              = 32,
	GETC                = 33,
	RETURNT             = 34,
	APPEND              = 35,
	QPRINT              = 36,
	OPEN                = 37,
	PRINTF              = 38,
	ENDFOR_GENERAL      = 39,
	IS_AN_OBJECT        = 40,
	SQRT                = 41,
	LENGTH              = 42,
	BADRETURNF          = 43,
	PUTS                = 44,
	ASSIGN_SLICE        = 45,
	RHS_SLICE           = 46,
	WHILE               = 47,
	ENDFOR_INT_UP       = 48,
	ENDFOR_UP           = 49,
	ENDFOR_DOWN         = 50,
	NOT_BITS            = 51,
	ENDFOR_INT_DOWN     = 52,
	SPRINTF             = 53,
	ENDFOR_INT_UP1      = 54,
	ENDFOR_INT_DOWN1    = 55,
	AND_BITS            = 56,
	PREPEND             = 57,
	STARTLINE           = 58,
	CLEAR_SCREEN        = 59,
	POSITION            = 60,
	EXIT                = 61,
	RAND                = 62,
	FLOOR_DIV           = 63,
	TRACE               = 64,
	TYPE_CHECK          = 65,
	FLOOR_DIV2          = 66,
	IS_AN_ATOM          = 67,
	IS_A_SEQUENCE       = 68,
	DATE                = 69,
	TIME                = 70,
	REMAINDER           = 71,
	POWER               = 72,
	ARCTAN              = 73,
	LOG                 = 74,
	SPACE_USED          = 75,
	COMPARE             = 76,
	FIND                = 77,
	MATCH               = 78,
	GET_KEY             = 79,
	SIN                 = 80,
	COS                 = 81,
	TAN                 = 82,
	FLOOR               = 83,
	ASSIGN_SUBS_CHECK   = 84,
	RIGHT_BRACE_2       = 85,
	CLOSE               = 86,
	DISPLAY_VAR         = 87,
	ERASE_PRIVATE_NAMES = 88,
	UPDATE_GLOBALS      = 89,
	ERASE_SYMBOL        = 90,
	GETENV              = 91,
	RHS_SUBS_CHECK      = 92,
	PLUS1               = 93,
	IS_AN_INTEGER       = 94,
	LHS_SUBS            = 95,
	INTEGER_CHECK       = 96,
	SEQUENCE_CHECK      = 97,
	DIV2                = 98,
	SYSTEM              = 99,
	COMMAND_LINE        = 100,
	ATOM_CHECK          = 101,
	LESS_IFW            = 102,   -- keep relops consecutive LESS..GREATER, NOT
	GREATEREQ_IFW       = 103,
	EQUALS_IFW          = 104,
	NOTEQ_IFW           = 105,
	LESSEQ_IFW          = 106,
	GREATER_IFW         = 107,
	NOT_IFW             = 108,
	GLOBAL_INIT_CHECK   = 109,
	NOP2                = 110,
	MACHINE_FUNC        = 111,
	MACHINE_PROC        = 112,
	ASSIGN_I            = 113,   -- keep these _I's together ...
	RHS_SUBS_I          = 114,
	PLUS_I              = 115,
	MINUS_I             = 116,
	PLUS1_I             = 117,   -- ... they check for integer result
	ASSIGN_SUBS_I       = 118,
	LESS_IFW_I          = 119,   -- keep relop _I's consecutive LESS..GREATER
	GREATEREQ_IFW_I     = 120,
	EQUALS_IFW_I        = 121,
	NOTEQ_IFW_I         = 122,
	LESSEQ_IFW_I        = 123,
	GREATER_IFW_I       = 124,
	FOR_I               = 125,
	ABORT               = 126,
	PEEK                = 127,
	POKE                = 128,
	CALL                = 129,
	PIXEL               = 130,
	GET_PIXEL           = 131,
	MEM_COPY            = 132,
	MEM_SET             = 133,
	C_PROC              = 134,
	C_FUNC              = 135,
	ROUTINE_ID          = 136,
	CALL_BACK_RETURN    = 137,
	CALL_PROC           = 138,
	CALL_FUNC           = 139,
	POKE4               = 140,
	PEEK4S              = 141,
	PEEK4U              = 142,
	SC1_AND             = 143,
	SC2_AND             = 144,
	SC1_OR              = 145,
	SC2_OR              = 146,
	SC2_NULL            = 147,  -- no code address for this one
	SC1_AND_IF          = 148,
	SC1_OR_IF           = 149,
	ASSIGN_SUBS2        = 150,  -- just for emit, not x.c
	ASSIGN_OP_SUBS      = 151,
	ASSIGN_OP_SLICE     = 152,
	PROFILE             = 153,
	XOR                 = 154,
	EQUAL               = 155,
	SYSTEM_EXEC         = 156,
	PLATFORM            = 157,
	END_PARAM_CHECK     = 158,
	CONCAT_N            = 159,
	NOPWHILE            = 160,  -- Translator only
	NOP1                = 161,  -- Translator only
	PLENGTH             = 162,
	LHS_SUBS1           = 163,
	PASSIGN_SUBS        = 164,
	PASSIGN_SLICE       = 165,
	PASSIGN_OP_SUBS     = 166,
	PASSIGN_OP_SLICE    = 167,
	LHS_SUBS1_COPY      = 168,
	TASK_CREATE         = 169,
	TASK_SCHEDULE       = 170,
	TASK_YIELD          = 171,
	TASK_SELF           = 172,
	TASK_SUSPEND        = 173,
	TASK_LIST           = 174,
	TASK_STATUS         = 175,
	TASK_CLOCK_STOP     = 176,
	TASK_CLOCK_START    = 177,
	FIND_FROM           = 178,
	MATCH_FROM          = 179,
	POKE2               = 180,
	PEEK2S              = 181,
	PEEK2U              = 182,
	PEEKS               = 183,
	PEEK_STRING         = 184,
	OPTION_SWITCHES     = 185,
	RETRY               = 186,
	SWITCH              = 187,
	CASE                = 188,
	NOPSWITCH           = 189,  -- Translator only
	GOTO 				= 190,
	GLABEL 				= 191,
	SPLICE				= 192,
	INSERT				= 193,
	MAX_OPCODE          = 193

-- adding new opcodes possibly affects reswords.h (C-coded backend),
-- be_execute.c (localjumptab[])
-- be_runtime.c (optable[]), redef.h, and maybe scanner.e, 
-- emit.e, keylist.e and the Translator (compile.e)
-- Also, run makename.ex 

-- scanner codes
--
-- codes for characters that are simply returned to the parser 
-- without any processing <= -20
global constant
	ILLEGAL_CHAR  = -20,
	END_OF_FILE   = -21,
	DOLLAR        = -22,
	COLON         = -23,
	LEFT_BRACE    = -24,
	RIGHT_BRACE   = -25,
	LEFT_ROUND    = -26,
	RIGHT_ROUND   = -27,
	LEFT_SQUARE   = -28,
	RIGHT_SQUARE  = -29,
	COMMA         = -30,
	QUESTION_MARK = -31

-- codes for classes of characters that the scanner 
-- has to process in some way
global constant
	NUMBER_SIGN  = -11,
	KEYWORD      = -10,
	BUILTIN      = -9,
	BLANK        = -8,
	DIGIT        = -7,
	NEWLINE      = -6,
	SINGLE_QUOTE = -5,
	DOUBLE_QUOTE = -4,
	DOT          = -3,
	LETTER       = -2,
	BANG         = -1

-- other scanner tokens 
global constant VARIABLE = -100

global constant END_OF_FILE_CHAR = 26 -- use this char to indicate EOF

-- other keywords
global enum 
	END = 402,
	TO,
	BY,
	PROCEDURE,
	FUNCTION,
	IFDEF,
	ELSIFDEF,
	THEN,
	DO,
	GLOBAL,
	RETURN,
	ELSIF,
	OBJECT,
	TYPE_DECL,
	CONSTANT,
	INCLUDE,
	LABEL,
	WITH,
	WITHOUT,
	LOOP,
	UNTIL,
	ENTRY,
	BREAK,
	CONTINUE,
	ENUM,
	EXPORT,
	OVERRIDE

global enum 
	FUNC = 501,
	ATOM,
	STRING,
	TYPE,
	PLAYBACK_ENDS,
	WARNING,
	RECORDED,
	QUALIFIED_VARIABLE,
	SLICE,
	VARIABLE_DECL,
	PLUS_EQUALS,
	MINUS_EQUALS,
	MULTIPLY_EQUALS,
	DIVIDE_EQUALS,
	CONCAT_EQUALS,
	NAMESPACE,
	QUALIFIED_FUNC,
	QUALIFIED_PROC,
	QUALIFIED_TYPE

