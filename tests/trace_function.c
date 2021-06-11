#include "../config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ipc.h>//ipc
#include <sys/shm.h>
#include <unistd.h>

#ifdef __APPLE__
#include <malloc/malloc.h>
#define malloc_usable_size malloc_size
#else
#include <malloc.h>
#endif /* ^!__APPLE__ */

struct sys_data
{
  unsigned long long int UpdateFunctionState;
};

void __attribute__((constructor)) traceBegin(void) {
  ;
}

void __attribute__((destructor)) traceEnd(void) {

  printf("\n@@@ instru: Finished @@@\n\n");
  printf("instru: update function state = %lld\n", memory_peak);

}

uint64_t simple_hash(uint64_t x) {
    x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
    x = x ^ (x >> 31);
    return x;
}
uint32_t hash_int(uint32_t old, uint32_t val){
  uint64_t input = (((uint64_t)(old))<<32) | ((uint64_t)(val));
  return (uint32_t)(simple_hash(input));
}
uint32_t hash_inst(uint32_t old, char* val){
  return hash_mem(old, val, strlen(val));
}
uint32_t hash_mem(uint32_t old, char* val, size_t len){
  old = hash_int(old,len);
  for(size_t i = 0; i < len ; i++){
    old = hash_int(old, val[i]);
  }
  return old;
}

void function_inst_int(unsigned int addr, int option, long long int value){
    switch(option){
        case 1:{
            if(value > function_int_value[addr % FUNCTION_MAP_SIZE]){
                function_int_value[addr % FUNCTION_MAP_SIZE] = value;
            }
            break;
        }
        case 2:{
            if(value < function_int_value[addr % FUNCTION_MAP_SIZE]){
                function_int_value[addr % FUNCTION_MAP_SIZE] = value;
            }
            break;
        }
        case 3:{
            if(abs(value) < abs(function_int_value[addr % FUNCTION_MAP_SIZE])){
                function_int_value[addr % FUNCTION_MAP_SIZE] = value;
            }
            break;
        }
        default:break;
    }
}

void function_inst_string(unsigned int addr, int option, char* str){
    switch(option){
        case 4:{
            if(strlen(str) > function_int_value[addr % FUNCTION_MAP_SIZE]){
                function_int_value[addr % FUNCTION_MAP_SIZE] = strlen(str);
            }
            break;
        }
        default:break;
    }
}
