/* arch:summary=Stream status of a single xrwm workspace tag for Waybar button */
#define _GNU_SOURCE
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static int has_number_in_array(const char *json, const char *key, int num) {
    const char *p = strstr(json, key);
    if (!p) return 0;
    p = strchr(p, '[');
    if (!p) return 0;
    const char *end = strchr(p, ']');
    if (!end) return 0;

    char target[16];
    snprintf(target, sizeof(target), "%d", num);
    int tlen = strlen(target);

    p++;
    while (p < end) {
        while (p < end && (*p == ' ' || *p == ',')) p++;
        if (p >= end) break;
        if (strncmp(p, target, tlen) == 0) {
            char after = p[tlen];
            if (after == ',' || after == ']' || after == ' ' || after == '\0') {
                return 1;
            }
        }
        while (p < end && *p != ',' && *p != ']') p++;
    }
    return 0;
}

static int find_xrwm_socket(char *out, size_t max_len) {
    const char *display = getenv("WAYLAND_DISPLAY");
    uid_t uid = getuid();

    if (display && strlen(display) > 0) {
        snprintf(out, max_len, "/run/user/%d/xrwm-%s.sock", uid, display);
        if (access(out, F_OK) == 0) return 0;
    }

    char run_dir[64];
    snprintf(run_dir, sizeof(run_dir), "/run/user/%d", uid);
    DIR *d = opendir(run_dir);
    if (!d) return -1;

    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (strncmp(ent->d_name, "xrwm-", 5) == 0 && strstr(ent->d_name, ".sock")) {
            snprintf(out, max_len, "%s/%s", run_dir, ent->d_name);
            closedir(d);
            return 0;
        }
    }
    closedir(d);
    return -1;
}

int main(int argc, char **argv) {
    int tag = 1;
    if (argc > 1) {
        tag = atoi(argv[1]);
        if (tag < 1 || tag > 9) tag = 1;
    }

    char sock_path[256];
    if (find_xrwm_socket(sock_path, sizeof(sock_path)) < 0) {
        return 1;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return 1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_path, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return 1;
    }

    const char *req = "{\"type\":\"Status\",\"payload\":{\"stream\":true,\"format\":null}}\n";
    if (write(fd, req, strlen(req)) < 0) {
        close(fd);
        return 1;
    }

    FILE *fp = fdopen(fd, "r");
    if (!fp) {
        close(fd);
        return 1;
    }

    char line[16384];
    while (fgets(line, sizeof(line), fp)) {
        if (strlen(line) < 10) continue;
        int active = has_number_in_array(line, "\"active_tag_numbers\"", tag);
        int occupied = has_number_in_array(line, "\"occupied_tag_numbers\"", tag);

        if (active && occupied) {
            printf("{\"text\":\"%d\",\"class\":[\"focused\",\"occupied\"],\"tooltip\":\"Workspace %d\"}\n", tag, tag);
        } else if (active) {
            printf("{\"text\":\"%d\",\"class\":[\"focused\"],\"tooltip\":\"Workspace %d\"}\n", tag, tag);
        } else if (occupied) {
            printf("{\"text\":\"%d\",\"class\":[\"occupied\"],\"tooltip\":\"Workspace %d\"}\n", tag, tag);
        } else {
            printf("{\"text\":\"%d\",\"class\":[\"empty\"],\"tooltip\":\"Workspace %d\"}\n", tag, tag);
        }
        fflush(stdout);
    }

    fclose(fp);
    return 0;
}
