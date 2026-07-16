#include <mach-o/dyld.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    char executablePath[PATH_MAX];
    uint32_t size = sizeof(executablePath);

    if (_NSGetExecutablePath(executablePath, &size) != 0) {
        return 1;
    }

    char resolvedPath[PATH_MAX];
    if (realpath(executablePath, resolvedPath) == NULL) {
        return 1;
    }

    char *macOSComponent = strstr(resolvedPath, "/Contents/MacOS/");
    if (macOSComponent == NULL) {
        return 1;
    }

    size_t contentsLength = (size_t)(macOSComponent - resolvedPath) + strlen("/Contents");
    char binaryPath[PATH_MAX];
    int written = snprintf(
        binaryPath,
        sizeof(binaryPath),
        "%.*s/Resources/StudyTrackerBinary",
        (int)contentsLength,
        resolvedPath
    );

    if (written < 0 || written >= (int)sizeof(binaryPath)) {
        return 1;
    }

    char **newArgv = calloc((size_t)argc + 1, sizeof(char *));
    if (newArgv == NULL) {
        return 1;
    }

    newArgv[0] = binaryPath;
    for (int index = 1; index < argc; index++) {
        newArgv[index] = argv[index];
    }

    execv(binaryPath, newArgv);
    perror("execv");
    free(newArgv);
    return 1;
}
