#include <stdint.h>
typedef unsigned UINT;
typedef struct {int unused;} FATFS;
typedef struct {uint64_t size;void *handle;} FIL;
#define FR_OK 0
#define FA_READ 1
#define f_size(f) ((f)->size)
int f_mount(FATFS*,const char*,int);
int f_open(FIL*,const char*,unsigned);
int f_read(FIL*,void*,UINT,UINT*);
int f_close(FIL*);
