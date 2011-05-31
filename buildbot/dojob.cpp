/*
  Utility to run processes under job object control.
  Handy in buildbot environment, as buildbot does not terminate process trees
  cleanly.
  It works by creating named job object (name is derived from current directory),
  assigning current process to the object, so that all subprocesses also run 
  under this job. If named job object already existed, it is terminated.

  We expect different builders to run in different directories, hence deriving 
  job object name from current directory should be fine.

  dojob acts as replacement for "cmd /c". It should be used in AddStep in buildbot
  as the first element in the "command" array, like this

  f_win32_debug.addStep(ShellCommand(
        name= "remove_old_build_dir",
        command=["dojob",  WithProperties("rmdir /S /Q c:\\buildbot\\%(buildername)s\\build || exit 0")],
        alwaysRun=True
));

  NOTE: to use dojob like this, you'll need to place dojob.exe into a directory
  in PATH

  Compiling dojob:

    cl dojob.c
*/


#include <Windows.h>
#include <process.h>
#include <stdlib.h>
#include <stdio.h>

HANDLE job;
BOOL WINAPI CtrlHandler( DWORD type ) 
{
  printf("dojob: CtrlHandler invoked, type=%d\n",type);
  if (job)
    TerminateJobObject(job, 0);
  return FALSE;
}

int main(int argc, char* argv[])
{
  char jobname[MAX_PATH];
  char *argvbuffer[1024];
  if(argc == 1)
  {
    printf(
      "Usage: dojob <command line>. \n"
      "Runs process tree in Windows job object."
      "The job name is derived from current directory. If dojob finds an already running "
      "job in the same directory, existing job will be terminated\n");
    exit(0);
  }
  if (GetCurrentDirectoryA(sizeof(jobname), jobname) == 0)
  {
    fprintf(stderr, "Cannot determine current directory");
  }
  for(int i=0; jobname[i]; i++)
    if(jobname[i] == '\\')
      jobname[i]='/';

  job = CreateJobObjectA(NULL, jobname);
  if (!job)
  {
    fprintf(stderr, "Can not create job object, last error %d\n", GetLastError() );
    exit(1);
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS)
  {
    fprintf(stderr,"dojob:aborting exiting job object\n");
    if (!TerminateJobObject(job, 3))
    {
      fprintf(stderr, "dojob:Cannot terminate existing job, last error %d\n", GetLastError());
      exit(1);
    }
    job = CreateJobObjectA(NULL, jobname);
    if (!job)
    {
      fprintf(stderr, "dojob:Can not create job object, last error %d\n", GetLastError() );
      exit(1);
    }
  }

  if (!AssignProcessToJobObject(job, GetCurrentProcess()))
  {
    fprintf(stderr, "dojob:Cannot assign current process to the job\n");
    exit(1);
  }
  SetConsoleCtrlHandler(CtrlHandler, TRUE);
  argvbuffer[0]="C:\\windows\\system32\\cmd.exe";
  argvbuffer[1]="/c";

  for(int i=0; i< argc; i++)
  {
    argvbuffer[i+2]= argv[i+1];
  }

  intptr_t err = _spawnv(_P_WAIT, argvbuffer[0], argvbuffer);
  if (err)
  {
    fprintf(stderr,"dojob: spawn returned error %d\n",(int) err);
  }
  return (int)err;
}

