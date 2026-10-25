#define _DEFAULT_SOURCE 1

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Same pointer/length layout as a Goose u8[:] slice. The native sidecar is
   compiled separately from the generated Goose translation unit. */
typedef struct { uint8_t *data; int64_t len; } ps1_u8;

#if defined(_WIN32)

int64_t ps1_deepseek_chat(ps1_u8 api_key, ps1_u8 request, ps1_u8 response) {
    (void)api_key;
    (void)request;
    (void)response;
    return -5; /* The curl subprocess bridge is currently POSIX-only. */
}

#else

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int write_all(int fd, const uint8_t *data, int64_t len) {
    int64_t offset = 0;
    while (offset < len) {
        ssize_t n = write(fd, data + offset, (size_t)(len - offset));
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return 0;
        offset += n;
    }
    return 1;
}

static int make_file(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR);
    if (fd < 0) return 0;
    return close(fd) == 0;
}

static int write_config(int fd, ps1_u8 api_key) {
    static const char prefix[] = "header = \"Authorization: Bearer ";
    static const char suffix[] = "\"\nheader = \"Content-Type: application/json\"\n";
    return write_all(fd, (const uint8_t *)prefix, (int64_t)sizeof(prefix) - 1) &&
           write_all(fd, api_key.data, api_key.len) &&
           write_all(fd, (const uint8_t *)suffix, (int64_t)sizeof(suffix) - 1);
}

static int key_is_safe(ps1_u8 api_key) {
    if (!api_key.data || api_key.len <= 0 || api_key.len > 4096) return 0;
    for (int64_t i = 0; i < api_key.len; i++) {
        uint8_t c = api_key.data[i];
        if (c < 0x21 || c > 0x7e || c == '"' || c == '\\') return 0;
    }
    return 1;
}

int64_t ps1_deepseek_chat(ps1_u8 api_key, ps1_u8 request, ps1_u8 response) {
    if (!key_is_safe(api_key)) return -1;
    if (!request.data || request.len <= 0 || request.len > 65536 ||
        !response.data || response.len <= 0) return -2;

    char dir[] = "/tmp/ps1-deepseek-XXXXXX";
    if (!mkdtemp(dir)) return -2;

    char request_path[512] = {0}, response_path[512] = {0};
    char data_arg[520] = {0};
    int request_len = snprintf(request_path, sizeof(request_path), "%s/request.json", dir);
    int response_len = snprintf(response_path, sizeof(response_path), "%s/response.json", dir);
    int data_len = snprintf(data_arg, sizeof(data_arg), "@%s", request_path);
    int paths_ok = request_len > 0 && (size_t)request_len < sizeof(request_path) &&
                   response_len > 0 && (size_t)response_len < sizeof(response_path) &&
                   data_len > 0 && (size_t)data_len < sizeof(data_arg);
    int64_t result = -2;
    if (!paths_ok) goto cleanup;

    if (!make_file(request_path) || !make_file(response_path)) goto cleanup;

    int body_fd = open(request_path, O_WRONLY | O_TRUNC);
    if (body_fd < 0) goto cleanup;
    int body_ok = write_all(body_fd, request.data, request.len);
    if (close(body_fd) != 0) body_ok = 0;
    if (!body_ok) goto cleanup;

    int config_pipe[2] = {-1, -1};
    if (pipe(config_pipe) != 0) goto cleanup;
    if (!write_config(config_pipe[1], api_key)) {
        close(config_pipe[0]);
        close(config_pipe[1]);
        config_pipe[0] = config_pipe[1] = -1;
        goto cleanup;
    }
    close(config_pipe[1]);
    config_pipe[1] = -1;

    pid_t child = fork();
    if (child < 0) {
        close(config_pipe[0]);
        config_pipe[0] = -1;
        goto cleanup;
    }
    if (child == 0) {
        if (dup2(config_pipe[0], STDIN_FILENO) < 0) _exit(126);
        close(config_pipe[0]);
        int null_fd = open("/dev/null", O_WRONLY);
        if (null_fd >= 0) {
            dup2(null_fd, STDOUT_FILENO);
            dup2(null_fd, STDERR_FILENO);
            close(null_fd);
        }
        unsetenv("DEEPSEEK_API_KEY");
        char *const args[] = {
            "curl", "-q", "--silent", "--fail",
            "--connect-timeout", "8", "--max-time", "25", "--max-filesize", "524288",
            "--config", "-", "--data-binary", data_arg, "--output", response_path,
            "https://api.deepseek.com/chat/completions", NULL
        };
        execvp("curl", args);
        _exit(127);
    }
    close(config_pipe[0]);
    config_pipe[0] = -1;

    int child_status = 0;
    pid_t waited;
    do {
        waited = waitpid(child, &child_status, 0);
    } while (waited < 0 && errno == EINTR);
    if (waited != child || !WIFEXITED(child_status) || WEXITSTATUS(child_status) != 0) {
        result = -3;
        goto cleanup;
    }

    int response_fd = open(response_path, O_RDONLY);
    if (response_fd < 0) {
        result = -4;
        goto cleanup;
    }
    struct stat response_stat;
    if (fstat(response_fd, &response_stat) != 0 || response_stat.st_size <= 0 ||
        response_stat.st_size > response.len) {
        close(response_fd);
        result = -4;
        goto cleanup;
    }

    int64_t total = 0;
    while (total < response_stat.st_size) {
        ssize_t n = read(response_fd, response.data + total,
                         (size_t)(response_stat.st_size - total));
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) {
            close(response_fd);
            result = -4;
            goto cleanup;
        }
        total += n;
    }
    close(response_fd);
    result = total;

cleanup:
    if (request_path[0]) unlink(request_path);
    if (response_path[0]) unlink(response_path);
    rmdir(dir);
    return result;
}

#endif
