CFLAGS=-O2

pdc : y.tab.o
	$(CC) -o $@ y.tab.o

y.tab.c : pdc.y
	yacc pdc.y

clean :
	$(RM) pdc y.tab.c *.o
	
