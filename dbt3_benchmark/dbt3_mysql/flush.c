/* Copyright Monty Program KB */
/* Flush all file-buffers pages for easyer timeing */

#include <my_global.h>
#include <my_sys.h>

static int get_options(int *argc,char **argv[]);

static char *progname;
static int memory=28,verbose=0;

int main(argc, argv)
int argc;
char *argv[];
{
  if (get_options(&argc,&argv))
    exit(1);

  if (verbose)
    printf("Syncing filesystem...\n");
  sync(); sleep(1); sync();
  if (verbose)
    printf("Allocating %d meg memory\n",memory);
  while (memory-- >0)
    VOID(my_malloc((uint) 1024*1024-MALLOC_OVERHEAD,
		   MYF(MY_WME | MY_ZEROFILL)));
  exit(0);
  return 0;
}

static int get_options(argc,argv)
register int *argc;
register char **argv[];
{
  int version;
  char *pos;

  progname= (*argv)[0];

  while (--*argc >0 && *(pos = *(++*argv)) == '-' ) {
    while (*++pos)
    {
      version=0;
      switch (*pos) {
      case 'v':
      	verbose=1;
      	break;
      case 'V':
	version=1;
      case 'I':
      case '?':
	printf("%s  Ver 1.0 for %s at %s\n",progname,SYSTEM_TYPE,MACHINE_TYPE);
	puts("TCX Datakonsult AB, by Monty, for your professional use\n");
	if (version)
	  break;
	puts("Flush all disk-buffers by allocating all memory.");
	puts("");
        printf("Usage: %s [-?vIV] memory\n",progname);
	puts("");
	puts("Options: -? or -I \"Info\"  -v \"verbose\"  -V \"Version\"");
	break;
      default:
	fprintf(stderr,"illegal option: -%c\n",*pos);
	return(1);
	break;
      }
    }
  }
  if (*argc)
    memory=atoi(**argv);
  return(0);
} /* get_options */
