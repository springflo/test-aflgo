/* sample1  */ 


#include<stdio.h>
#include<string.h>
#define BUFSIZE 1<<10

char type[BUFSIZE];

void recurse(char *buf){
	if(*buf == '\0'){
		return ;
	}
	else if(*buf == '_'){ //"_txx_rxx"
		switch(*(buf + 1)){
			case 't':{
				strcpy(type, buf + 2);
				return recurse(buf + 2);
			}
			case 'r':{
				strcpy(buf + 2, type);
				return recurse(buf + 2);
			}
			case '\0': return;
		}
	}
	else return recurse(buf + 1);
}

int sample1() {
	char log[BUFSIZE]="";
	char buf[BUFSIZE]="";
	while(1){
		scanf("%s", buf);
		switch (buf[0]) {
			case 'c': strcat(log, buf); break;
			case 'r': printf("%s", log); break;
			case 'u': strcpy(log, buf); break;
			case 'd': log[buf[1] - '0'] = '\0'; break;
			case 'n': {
				recurse(buf + 1);
				strcpy(log, buf);
				return 1;
			}
			default: return -1;
		}
		printf("log=%s\n", log);
	}
	return 0;
}


int main(){
    printf("return: %d\n", sample1());
    return 0;
}