CFLAGS = -O2 -g

ifndef WITHOUT_GCC
CFLAGS += -Wall
endif

ifndef WITHOUT_READLINE
LDFLAGS += -lreadline -lncurses
CFLAGS  += -DHAVE_READLINE
endif

all: pdc

pdc : y.tab.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ y.tab.o

y.tab.c : pdc.y
	$(YACC) pdc.y

clean :
	$(RM) pdc y.tab.c *.o
	
