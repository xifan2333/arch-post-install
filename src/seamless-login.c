/*
 * seamless-login.c - Minimalist VT graphics mode switcher and session launcher
 * Locks virtual terminal into KD_GRAPHICS mode to eliminate console text flicker
 * before executing the Wayland compositor session.
 */
#include <fcntl.h>
#include <linux/kd.h>
#include <linux/vt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    int vt_fd;
    int vt_num = 1; /* TTY1 */
    char vt_path[32];

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command> [args...]\n", argv[0]);
        return 1;
    }

    snprintf(vt_path, sizeof(vt_path), "/dev/tty%d", vt_num);
    vt_fd = open(vt_path, O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT");
        return 1;
    }

    /* Activate VT1 and wait until it is active */
    if (ioctl(vt_fd, VT_ACTIVATE, vt_num) < 0) {
        perror("VT_ACTIVATE failed");
        close(vt_fd);
        return 1;
    }

    if (ioctl(vt_fd, VT_WAITACTIVE, vt_num) < 0) {
        perror("VT_WAITACTIVE failed");
        close(vt_fd);
        return 1;
    }

    /* Set graphics mode to prevent console text and cursor from showing */
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE KD_GRAPHICS failed");
        close(vt_fd);
        return 1;
    }

    /* Clear VT screen */
    const char *clear_seq = "\033[H\033[2J";
    if (write(vt_fd, clear_seq, strlen(clear_seq)) < 0) {
        perror("Failed to clear VT");
    }

    close(vt_fd);

    /* Switch working directory to user home */
    const char *home = getenv("HOME");
    if (home) {
        if (chdir(home) < 0) {
            perror("Failed to chdir to HOME");
        }
    }

    /* Execute the Wayland compositor session */
    execvp(argv[1], &argv[1]);
    perror("Failed to exec session");
    return 1;
}
