CFLAGS=-O2 -g -Wall

pdc : y.tab.o
	$(CC) $(CFLAGS) -o $@ y.tab.o

y.tab.c : pdc.y
	$(YACC) pdc.y

clean :
	$(RM) pdc y.tab.c *.o
	
