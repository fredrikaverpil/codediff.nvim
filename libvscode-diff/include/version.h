#ifndef VSCODE_DIFF_VERSION_H
#define VSCODE_DIFF_VERSION_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Read version from VERSION file at runtime.
 * The VERSION file is located at the repository root.
 */
static inline const char* read_version_from_file(void) {
    static char version[32] = {0};
    static int initialized = 0;
    
    if (initialized) {
        return version;
    }
    
    // Try to read from VERSION file (relative to library location)
    FILE* f = fopen("VERSION", "r");
    if (!f) {
        // Fallback: try from current directory
        strcpy(version, "unknown");
        initialized = 1;
        return version;
    }
    
    if (fgets(version, sizeof(version), f)) {
        // Remove trailing newline
        size_t len = strlen(version);
        if (len > 0 && version[len-1] == '\n') {
            version[len-1] = '\0';
        }
    } else {
        strcpy(version, "unknown");
    }
    
    fclose(f);
    initialized = 1;
    return version;
}

#define VSCODE_DIFF_VERSION read_version_from_file()

#endif // VSCODE_DIFF_VERSION_H
