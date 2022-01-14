#include <stdio.h>
#include <unistd.h>
#include <sys/param.h>
#include <libgen.h>
#include <CoreFoundation/CoreFoundation.h>

/*
 * We expect the bundle to contain a symlink MacOS/Python to the python
 * executable within the bundle and a python script Resources/main.py
 * which will be run using the python executable.
 */

static void debugMessage(char *msg) {
    FILE *logfile = fopen("/tmp/sagemath.log", "a");
    fprintf(logfile, "%s\n", msg);
    fclose(logfile);
}

int main(int argc, char **argv, char **envp) {
    char executablePath[PATH_MAX];
    char pythonPath[PATH_MAX];
    char mainPath[PATH_MAX];
    char *exec_argv[3] = {pythonPath, mainPath, NULL};
    CFBundleRef bundle = CFBundleGetMainBundle();
    CFURLRef URL;
    CFStringRef string;
    debugMessage("Starting SageMath");
    URL = CFBundleCopyExecutableURL(bundle);
    string = CFURLCopyFileSystemPath(URL, kCFURLPOSIXPathStyle);
    CFRelease(URL);
    CFStringGetCString(string, executablePath, PATH_MAX, kCFStringEncodingUTF8);
    CFRelease(string);
    CFRelease(bundle);
    dirname_r(executablePath, pythonPath);
    dirname_r(pythonPath, mainPath);
    strlcat(pythonPath, "/Python", PATH_MAX);
    strlcat(mainPath, "/Resources/main.py", PATH_MAX);
    /*
    debugMessage(pythonPath);
    debugMessage(mainPath);
    for (char **p = envp; *p != NULL; p++) {
        debugMessage(*p);
    }
    */
    execve(pythonPath, exec_argv, envp);
    return 0;
}
