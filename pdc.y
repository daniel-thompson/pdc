/*
 * pdc.y
 *
 * The programmers desktop calculator. A desktop calculator supporting both
 * shifts and mixed base inputs.
 *
 * Copyright (C) 2001, 2002 Daniel Thompson <see help function for e-mail>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

/*
 * Compile with 'yacc pdc.y && cc y.tab.c -o pdc'
 */

/* TODO
 *  - fix backspace to delete as one might expect on GNU/Linux
 */

%{
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct symbol {
	const char *name;
	int type;
	union {
		long var;
		long (*func)(long);
	} value;
	struct symbol *next;
} symbol_t;

symbol_t *symbol_table = NULL;

int yyerror(char *s);
int yylex(void);
symbol_t *getsym(const char *name);
symbol_t *putsym(const char *name, int type);

const char *num2str(unsigned long num, int base);
%}

/* yylval's structure */
%union {
	long     integer;
	symbol_t *symbol;
}

%token <integer> INTEGER
%token <symbol>  VARIABLE FUNCTION
%type  <integer> expression

/* operators have C conventions for precedence */
%right '='
%left  LOGICAL_OR
%left  LOGICAL_AND
%left  '|'
%left  '^'
%left  '&'
%left  LEFT_SHIFT RIGHT_SHIFT
%left  '+' '-'
%left  '*' '/' '%'
%left  '!' '~' NEG

%% /* YACC grammar follows */

input:	  /* empty */
	| input line
;

line:	  '\n'
	| expression '\n' { 
		long base = getsym("obase")->value.var;

		printf("\t");

		/* print the prefixes */
		switch(base) {
		case 16:
			printf("0x");
			break;
		case 10:
			break;
		case 8:
			printf("0");
			break;
		case 2:
			printf("0b");
			break;
		case 0:
			break;
		default:
			printf("[base %d]", base);
		}

		/* now print the actual values */
		switch(base) {
		case 10:
			/* print base 10 values directly to keep signedness */
			printf("%0*ld", abs(getsym("pad")->value.var), $1);
			break;
		case 0:
			/* special case base 0 (print dec and hex) */
			printf("%0*ld\t[0x%0*lx]",
					abs(getsym("pad")->value.var), $1,
					abs(getsym("pad")->value.var), $1);
			break;
		default:
			printf("%0*s", abs(getsym("pad")->value.var), num2str($1, base));
		}

		/* Store the result of the last calculation. */
		getsym("ans")->value.var = $1;

		printf("\n> ");
		fflush(stdout);
	}
	| error '\n'			{ yyerrok; }
;

expression:
	  INTEGER			{ $$ = $1; }
	| VARIABLE			{ $$ = $1->value.var; }
	| FUNCTION '(' expression ')'	{ $$ = (*($1->value.func))($3); }
	| FUNCTION			{ $$ = (*($1->value.func))(0); }
	| VARIABLE '=' expression	{ $$ = $3; $1->value.var = $3; }
	| expression '+' expression	{ $$ = $1 + $3; }
	| expression '-' expression	{ $$ = $1 - $3; }
	| expression '|' expression	{ $$ = $1 | $3; }
	| expression '^' expression	{ $$ = $1 ^ $3; }
	| expression '*' expression	{ $$ = $1 * $3; }
	| expression '/' expression	{ $$ = $1 / $3; }
	| expression '%' expression	{ $$ = $1 % $3; }
	| expression '&' expression	{ $$ = $1 & $3; }
	| '~' expression		{ $$ = ~$2; }
	| '-' expression %prec NEG	{ $$ = -$2; }
	| expression LEFT_SHIFT expression
					{ $$ = $1 << $3; }
	| expression RIGHT_SHIFT expression
					{ $$ = $1 >> $3; }
	| expression LOGICAL_AND expression
					{ $$ = $1 && $3; }
	| expression LOGICAL_OR expression
					{ $$ = $1 || $3; }
	| '!' expression		{ $$ = !$2; }
	| '(' expression ')'		{ $$ = $2; }
;

%%

int yyerror(char *s)
{
	printf("%s\n> ", s);
	fflush(stdout);
	return 0;
}

int yylex(void)
{
	int c, i;

	/* ignore whitespace */
	do {
		c = getchar();
	} while (strchr(" \t", c));

	/* handle end of input */
	if (EOF == c) {
		return 0;
	}

	/* handle numeric types */
	if (isdigit(c)) {
		int base;

		/* determine the base of this number */
		if (c != '0') {
			base = getsym("ibase")->value.var;
			ungetc(c, stdin);
		} else {
			c = getchar();
			switch(c) {
			case 'd':
			case 'D':
				base = 10;
				break;
			case 'x':
			case 'X':
				base = 16;
				break;
			case 'b':
			case 'B':
				base = 2;
				break;
			default:
				base = 8;
				ungetc(c, stdin);
			}
		}

		yylval.integer = 0;
		c = getchar();
		while(EOF != c && isxdigit(c)) {
			static const char lookup[] = "0123456789abcdef";
			unsigned long digit = 
				((unsigned long) strchr(lookup, tolower(c))) -
				((unsigned long) lookup);

			if (digit >= base) {
				return INTEGER;
			}

			yylval.integer *= base;
			yylval.integer += digit;

			c = getchar();
		}

		switch (c) {
		case 'K':
			yylval.integer *= 1024;
			break;
		case 'M':
			yylval.integer *= 1024*1024;
			break;
		default:
			ungetc(c, stdin);
		}

		return INTEGER;
	}

	/* handle identifiers */
	if (isalpha(c)) {
		symbol_t *sym;
		static char *buf = NULL; /* this is allocated only once */
		static int length = 0;

		if (NULL == buf) {
			length = 40;
			buf = malloc(length + 1);
		}

		i = 0;
		do {
			/* grow the buffer if it is too small */
			if (i == length) {
				length *= 2;
				buf = realloc(buf, length +1);
			}

			buf[i++] = c;
			c = getchar();
		} while ((EOF != c) && isalnum(c));

		ungetc(c, stdin);
		buf[i] = '\0';

		/* look up (or generate) the symbol */
		if (NULL == (sym = getsym(buf))) {
			sym = putsym(buf, VARIABLE);
		}
		yylval.symbol = sym;
		return sym->type;
	}

	/* check for the shift operators */
	if (strchr("<>&|", c)) {
		int d = getchar();
		if (c == d) {
			switch (c) {
			case '<':
				return LEFT_SHIFT;
			case '>':
				return RIGHT_SHIFT;
			case '&':
				return LOGICAL_AND;
			case '|':
				return LOGICAL_OR;
			}
		} else {
			ungetc(d, stdin);
		}
	}

	/* this is a single character terminal */
	return c;
}

long defaultfunc(long i)
{
	fprintf(stderr, "internal error\n");
	exit(0);

	return 0;
}

symbol_t *putsym(const char *name, int type)
{
	symbol_t *sym;

	sym = (symbol_t*) malloc(sizeof(*sym));
	if (NULL == sym) {
		return NULL;
	}

	sym->name = strdup(name);
	if (NULL == sym->name) {
		free(sym);
		return NULL;
	}

	sym->type = type;
	switch(type) {
	case VARIABLE:
		sym->value.var = 0;
		break;
	case FUNCTION:
		sym->value.func = defaultfunc;
		break;
	}

	sym->next = symbol_table;
	symbol_table = sym;

	return sym;
}

symbol_t *getsym(const char *name)
{
	symbol_t *p;

	for (p = symbol_table; p != NULL; p = p->next) {
		if (0 == strcmp(p->name, name)) {
			return p;
		}
	}

	return NULL;
}

const char *num2str(unsigned long num, int base) {
	static const char lookup[] = "0123456789abcdef";
	static char *pStr, str[(sizeof(num) * 8) + 1];

	/* check for unsupported bases */
	if (base < 2 || base >= sizeof(lookup)) {
		printf("(bad obase, assuming base 10)\n\t");
		base = 10;
	} 
	
	pStr = &str[sizeof(str)];
	*--pStr = '\0';

	do {
		*--pStr = lookup[num % base];
		num /= base;
	} while (num);

	return pStr;
}

long bitcnt(long x)
{
	long b;
	for (b=0; x!=0; b++) {
		x &= x-1; /* clear least significant (set) bit */
	}
	return b;
}

long lssb(long x)
{
	x ^= x-1; /* isolate the least significant bit */
	return bitcnt(x-1)+1;
}
long swap32(long d)
{
	return (d >> 24 & 0x000000ff) |
	       (d >>  8 & 0x0000ff00) |
	       (d <<  8 & 0x00ff0000) |
	       (d << 24 & 0xff000000);
}

long quit(long ret)
{ 
	exit((int) ret);
	return 0;
}

long help(long mode)
{
	printf(
"pdc 0.5.4 - the programmers desktop calculator\n"
"\n"
"Copyright (C) 2001, 2002 Daniel Thompson <d\056thompson\100gmx\056net>\n"
"This is free software with ABSOLUTELY NO WARRANTY.\n"
"For details type `warranty'.\n"
"\n"
	);

	if (0 == mode) {
		printf(
"Contributers:\n"
"	Daniel Thompson          <d\056thompson\100gmx\056net>\n"
"	Paul Walker              <paul\100blacksun\056org\056uk>\n"
"\n"
"Variables:\n"
"	ans    - the result of the previous calculation\n"
"	ibase  - set the default input base (to force decimal use 0d10)\n"
"	obase  - set the default output base\n"
"	pad    - set the amount of zero padding used when displaying numbers\n"
"\n"
"Functions:\n"
"	abs(x)    - get the absolute value of x\n"
"	bitcnt(x) - get the population count of x\n"
"	help      - display this help message\n"
"	lssb(x)   - get the least significant set bit in x\n"
"	quit      - leave pdc\n"
"	swap32(x) - perform a 32-bit byte swap\n"
"	warranty  - display warranty and licencing information\n"
"\n"
		);
	}

	if (2 == mode) {
		printf(
"    This program is free software; you can redistribute it and/or modify\n"
"    it under the terms of the GNU General Public License as published by\n"
"    the Free Software Foundation; either version 2 of the License , or\n"
"    (at your option) any later version.\n"
"\n"
"    This program is distributed in the hope that it will be useful,\n"
"    but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
"    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
"    GNU General Public License for more details.\n"
"\n"
"    You should have received a copy of the GNU General Public License\n"
"    along with this program. If not, write to\n"
"\n"
"       The Free Software Foundation, Inc.\n"
"       59 Temple Place, Suite 330\n"
"       Boston, MA 02111, USA.\n"
"\n"
		);
	}

	return 0;
}

long warranty(long dummy)
{
	help(2);
	return 0;
}

symbol_t initial_symbols[] = {
	{ "ibase",   VARIABLE, { 10             }, NULL },
	{ "obase",   VARIABLE, { 0              }, NULL },
	{ "pad",     VARIABLE, { 0              }, NULL },
	{ "ans",     VARIABLE, { 0              }, NULL },
	{ "abs",     FUNCTION, { (long) labs    }, NULL },
	{ "bitcnt",  FUNCTION, { (long) bitcnt  }, NULL },
	{ "help",    FUNCTION, { (long) help    }, NULL },
	{ "lssb",    FUNCTION, { (long) lssb    }, NULL },
	{ "warranty",FUNCTION, { (long) warranty}, NULL },
	{ "quit",    FUNCTION, { (long) quit    }, NULL },
	{ "swap32",  FUNCTION, { (long) swap32  }, NULL },
	{ NULL,             0, { 0              }, NULL }
};

int main()
{
	int i;

	help(1);

	printf("> ");
	fflush(stdout);

	/* setup the initial symbol table */
	for (i=1; NULL != initial_symbols[i].name; i++) {
		initial_symbols[i].next = &initial_symbols[i-1];
	}
	symbol_table = &initial_symbols[i-1];
	
	/* run the calculator */
	yyparse();

	/* shutdown cleanly after a ^D */
	printf("\n");

	return 0;
}
