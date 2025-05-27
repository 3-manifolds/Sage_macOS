#include <stdio.h>
#include <unistd.h>
#include <sys/param.h>
#include <libgen.h>
#include <CoreFoundation/CoreFoundation.h>

/*
 * We expect the bundle to contain:
 *    + A symlink MacOS/Python to the python
 *      (This is needed in order for the main menu to show the app name)
 *    + a symlink MacOS/lib to the local/lib directory in the Sage framewor k
 *      (This is needed to allow tkinter to find init.tcl)
 *    + a python script Resources/main.py 
 *      (This program run the script as the main executable, using MacOS/Python.)  
 */

static void debugMessage(char *msg) {
    FILE *logfile = fopen("/tmp/sagemath.log", "a");
    fprintf(logfile, "%s\n", msg);
    fclose(logfile);
}

int main(int argc, char **argv, char **envp) {
    char executablePath[PATH_MAX + 1];
    char contentsPath[PATH_MAX + 1];
    char pythonPath[PATH_MAX + 1];
    char mainPath[PATH_MAX];
    char *exec_argv[3] = {pythonPath, mainPath, NULL};
    CFBundleRef bundle = CFBundleGetMainBundle();
    CFURLRef URL;
    CFStringRef string;
    /* debugMessage("Starting SageMath"); */
    URL = CFBundleCopyExecutableURL(bundle);
    string = CFURLCopyFileSystemPath(URL, kCFURLPOSIXPathStyle);
    CFRelease(URL);
    CFStringGetCString(string, executablePath, PATH_MAX, kCFStringEncodingUTF8);
    CFRelease(string);
    CFRelease(bundle);
    dirname_r(executablePath, contentsPath);
    dirname_r(contentsPath, pythonPath);
    dirname_r(contentsPath, mainPath);
    strlcat(pythonPath, "/MacOS/Python", PATH_MAX);
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
