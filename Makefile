CFLAGS += -O2 -g

ifndef WITHOUT_GCC
CFLAGS += -Wall
endif

ifdef WITH_CMDEDIT
CFLAGS += -DHAVE_CMDEDIT
else

ifndef WITHOUT_READLINE
LDFLAGS += -lreadline
CFLAGS  += -DHAVE_READLINE
endif
ifndef WITHOUT_NCURSES
LDFLAGS += -lncurses
endif

endif

all: pdc

pdc : y.tab.o
	$(CC) $(CFLAGS) -o $@ y.tab.o $(LDFLAGS)

y.tab.c : pdc.y
	$(YACC) pdc.y

clean :
	$(RM) pdc y.tab.c *.o
	
