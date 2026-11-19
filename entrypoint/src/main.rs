//! # Rhino Entrypoint (rhino-entrypoint)
//!
//! Ultra-lightweight, hardened PID 1 entrypoint for game server containers
//! managed by Rhino Action and Rhino Panel.
//!
//! ## Key DevSecOps Responsibilities:
//! - Functions as init (PID 1): traps signals (SIGTERM, SIGINT, SIGHUP, etc.) and
//!   forwards them to the child process group.
//! - Zombie reaping: collects orphaned background processes with `waitpid(-1, WNOHANG)`.
//! - Safe environment variable expansion: expands `{{VAR}}` and `${VAR}` without
//!   vulnerable shell `eval` or command-injection risks.
//! - Non-root verification and least-privilege reporting.
//! - Direct execve execution (bypassing `/bin/sh` unless explicitly needed).
//! - Optional background helper lifecycle (e.g. headless Xvfb for Windows/Wine game servers).

use std::env;
use std::fs;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{self, Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use std::time::{Duration, Instant};

static CAUGHT_SIGNAL: AtomicI32 = AtomicI32::new(0);
static CHILD_EVENT: AtomicBool = AtomicBool::new(false);

const DEFAULT_WORKDIR: &str = "/home/container";
const DEFAULT_STOP_TIMEOUT_SECS: u64 = 30;

extern "C" fn signal_handler(sig: libc::c_int) {
    if sig == libc::SIGCHLD {
        CHILD_EVENT.store(true, Ordering::SeqCst);
    } else {
        CAUGHT_SIGNAL.store(sig, Ordering::SeqCst);
    }
}

fn register_signals() {
    let mut sa: libc::sigaction = unsafe { std::mem::zeroed() };
    sa.sa_sigaction = signal_handler as *const () as usize;
    sa.sa_flags = libc::SA_RESTART;
    unsafe {
        libc::sigemptyset(&mut sa.sa_mask);
        libc::sigaction(libc::SIGTERM, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGINT, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGHUP, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGQUIT, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGUSR1, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGUSR2, &sa, std::ptr::null_mut());
        libc::sigaction(libc::SIGCHLD, &sa, std::ptr::null_mut());
    }
}

/// Expand `{{VARIABLE}}`, `${VARIABLE}`, and `$VARIABLE` from environment variables.
/// Prevents shell injection by executing pure string substitution in-memory.
pub fn interpolate_variables(input: &str) -> String {
    let mut result = String::with_capacity(input.len());
    let chars: Vec<char> = input.chars().collect();
    let len = chars.len();
    let mut i = 0;

    while i < len {
        // Match {{VAR}}
        if i + 1 < len && chars[i] == '{' && chars[i + 1] == '{' {
            let start = i + 2;
            let mut end = start;
            while end + 1 < len && !(chars[end] == '}' && chars[end + 1] == '}') {
                end += 1;
            }
            if end + 1 < len && chars[end] == '}' && chars[end + 1] == '}' {
                let var_name: String = chars[start..end].iter().collect();
                let trimmed = var_name.trim();
                let val = env::var(trimmed).unwrap_or_default();
                result.push_str(&val);
                i = end + 2;
                continue;
            }
        }

        // Match ${VAR}
        if i + 1 < len && chars[i] == '$' && chars[i + 1] == '{' {
            let start = i + 2;
            let mut end = start;
            while end < len && chars[end] != '}' {
                end += 1;
            }
            if end < len && chars[end] == '}' {
                let var_name: String = chars[start..end].iter().collect();
                let trimmed = var_name.trim();
                let val = env::var(trimmed).unwrap_or_default();
                result.push_str(&val);
                i = end + 1;
                continue;
            }
        }

        // Match $VAR (alphanumeric and underscores)
        if chars[i] == '$' && i + 1 < len && (chars[i + 1].is_alphanumeric() || chars[i + 1] == '_')
        {
            let start = i + 1;
            let mut end = start;
            while end < len && (chars[end].is_alphanumeric() || chars[end] == '_') {
                end += 1;
            }
            let var_name: String = chars[start..end].iter().collect();
            let val = env::var(&var_name).unwrap_or_default();
            result.push_str(&val);
            i = end;
            continue;
        }

        result.push(chars[i]);
        i += 1;
    }

    result
}

/// Shell mode: `{{VAR}}` becomes `${VAR}` and the SHELL expands it. A parameter expansion is
/// never re-parsed as shell syntax, so a variable value (user-controlled) can never inject a
/// command, whatever it contains (`;`, `$(...)`, quotes…). Invalid names expand to nothing.
pub fn to_shell_references(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut rest = input;
    while let Some(start) = rest.find("{{") {
        out.push_str(&rest[..start]);
        let after = &rest[start + 2..];
        let Some(end) = after.find("}}") else {
            out.push_str(&rest[start..]);
            return out;
        };
        let name = after[..end].trim();
        if !name.is_empty() && name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
            out.push_str("${");
            out.push_str(name);
            out.push('}');
        }
        rest = &after[end + 2..];
    }
    out.push_str(rest);
    out
}

/// Tokenize command line into individual arguments respecting quotes and escapes.
pub fn tokenize_command(cmd: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    let mut in_single = false;
    let mut in_double = false;
    let mut escaped = false;

    for ch in cmd.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        if ch == '\\' && !in_single {
            escaped = true;
            continue;
        }

        if ch == '\'' && !in_double {
            in_single = !in_single;
            continue;
        }

        if ch == '"' && !in_single {
            in_double = !in_double;
            continue;
        }

        if ch.is_whitespace() && !in_single && !in_double {
            if !current.is_empty() {
                tokens.push(current.clone());
                current.clear();
            }
            continue;
        }

        current.push(ch);
    }

    if !current.is_empty() {
        tokens.push(current);
    }

    tokens
}

/// Check if a command contains shell control characters that require a shell.
pub fn contains_shell_metacharacters(cmd: &str) -> bool {
    let mut in_single = false;
    let mut in_double = false;
    let chars: Vec<char> = cmd.chars().collect();

    for (idx, &ch) in chars.iter().enumerate() {
        if ch == '\'' && !in_double {
            in_single = !in_single;
            continue;
        }
        if ch == '"' && !in_single {
            in_double = !in_double;
            continue;
        }
        if !in_single && !in_double {
            match ch {
                '|' | ';' | '&' | '<' | '>' | '`' => return true,
                '$' if idx + 1 < chars.len() && chars[idx + 1] == '(' => return true,
                _ => {}
            }
        }
    }
    false
}

fn signal_name(sig: libc::c_int) -> &'static str {
    match sig {
        libc::SIGTERM => "SIGTERM",
        libc::SIGINT => "SIGINT",
        libc::SIGHUP => "SIGHUP",
        libc::SIGQUIT => "SIGQUIT",
        libc::SIGUSR1 => "SIGUSR1",
        libc::SIGUSR2 => "SIGUSR2",
        libc::SIGCHLD => "SIGCHLD",
        libc::SIGKILL => "SIGKILL",
        _ => "UNKNOWN",
    }
}

/// Reap any exited child processes (prevent zombie accumulation in PID 1).
fn reap_zombies() {
    loop {
        let mut status = 0;
        let pid = unsafe { libc::waitpid(-1, &mut status, libc::WNOHANG) };
        if pid <= 0 {
            break;
        }
    }
}

/// Optional helper for Wine / Windows headless servers: launch Xvfb on DISPLAY=:99.
fn maybe_start_xvfb() -> Option<Child> {
    let start_xvfb = env::var("RHINO_START_XVFB").unwrap_or_default() == "1"
        || env::var("XVFB_ENABLED").unwrap_or_default() == "1";

    if !start_xvfb {
        return None;
    }

    let display = env::var("DISPLAY").unwrap_or_else(|_| ":99".to_string());
    let width = env::var("DISPLAY_WIDTH").unwrap_or_else(|_| "1024".to_string());
    let height = env::var("DISPLAY_HEIGHT").unwrap_or_else(|_| "768".to_string());
    let depth = env::var("DISPLAY_DEPTH").unwrap_or_else(|_| "16".to_string());
    let screen = format!("{}x{}x{}", width, height, depth);

    eprintln!(
        "[rhino-entrypoint] Launching headless Xvfb on display {} ({})",
        display, screen
    );

    match Command::new("Xvfb")
        .arg(&display)
        .arg("-screen")
        .arg("0")
        .arg(&screen)
        .arg("-nolisten")
        .arg("tcp")
        .arg("-ac")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(child) => {
            env::set_var("DISPLAY", &display);
            // Brief pause to allow Xvfb to initialize socket
            std::thread::sleep(Duration::from_millis(150));
            Some(child)
        }
        Err(err) => {
            eprintln!("[rhino-entrypoint] Warning: Failed to spawn Xvfb: {}", err);
            None
        }
    }
}

fn check_security_profile() {
    let uid = unsafe { libc::getuid() };
    let gid = unsafe { libc::getgid() };

    eprintln!(
        "[rhino-entrypoint] Security context: UID={} GID={}",
        uid, gid
    );

    if uid == 0 {
        eprintln!(
            "[rhino-entrypoint] ⚠️ WARNING: Container running as root (UID 0)! \
             Rhino containers should run as unprivileged user (rhino UID 1000)."
        );
        if env::var("RHINO_REQUIRE_NON_ROOT").unwrap_or_default() == "1" {
            eprintln!("[rhino-entrypoint] FATAL: RHINO_REQUIRE_NON_ROOT is enabled. Aborting.");
            process::exit(1);
        }
    }

    // Verify read-only status of rootfs
    if let Ok(metadata) = fs::metadata("/") {
        if metadata.permissions().readonly() {
            eprintln!("[rhino-entrypoint] Rootfs status: READ-ONLY (Hardened)");
        }
    }
}

fn print_banner(workdir: &Path, final_cmd: &str) {
    eprintln!("\x1b[1;36m========================================================\x1b[0m");
    eprintln!("\x1b[1;36m  🦏 Rhino Container Entrypoint (PID 1) v0.1.0\x1b[0m");
    eprintln!("\x1b[1;36m========================================================\x1b[0m");
    eprintln!("[rhino-entrypoint] Working dir : {}", workdir.display());
    eprintln!("[rhino-entrypoint] Command     : {}", final_cmd);
    eprintln!("\x1b[1;36m--------------------------------------------------------\x1b[0m");
}

/// Max length of the process title (bytes).
#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
const PROCESS_TITLE_MAX: usize = 200;

/// Fields 48..=51 of `/proc/self/stat`: `arg_start arg_end env_start env_end` (Linux ≥ 3.5).
#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn parse_cmdline_area(stat: &str) -> Option<(usize, usize, usize, usize)> {
    // The command name (field 2) may contain spaces: fields are counted after the last ')'.
    let rest = stat.get(stat.rfind(')')? + 2..)?;
    let fields: Vec<&str> = rest.split_whitespace().collect();
    // `rest` starts at field 3.
    let field = |n: usize| fields.get(n - 3)?.parse::<usize>().ok();
    Some((field(48)?, field(49)?, field(50)?, field(51)?))
}

/// Keeps only printable characters and caps the size (UTF-8 boundary safe).
#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn sanitize_title(raw: &str) -> String {
    let mut out = String::new();
    for c in raw.chars().filter(|c| !c.is_control()) {
        if out.len() + c.len_utf8() > PROCESS_TITLE_MAX {
            break;
        }
        out.push(c);
    }
    out.trim().to_string()
}

/// `RHINO_PROCESS_TITLE` (set by Rhino Action, e.g. "Rhino Instance Lobby") replaces the command line
/// of PID 1 so every server is recognisable in `htop` / `ps` on the host, and its `comm`
/// (`prctl(PR_SET_NAME)`, 15 bytes). The argv + environ area is reused (setproctitle technique):
/// the environment is first copied to the heap, so nothing is lost.
///
/// MUST run while the process is single-threaded and after `env::args()` was copied (the strings
/// it points to are overwritten).
#[cfg(target_os = "linux")]
fn apply_process_title() {
    let Ok(raw) = env::var("RHINO_PROCESS_TITLE") else {
        return;
    };
    let title = sanitize_title(&raw);
    if title.is_empty() {
        return;
    }

    if let Ok(comm) = std::ffi::CString::new(
        title
            .as_bytes()
            .iter()
            .copied()
            .take(15)
            .collect::<Vec<u8>>(),
    ) {
        unsafe {
            libc::prctl(libc::PR_SET_NAME, comm.as_ptr() as libc::c_ulong, 0, 0, 0);
        }
    }

    let Some((arg_start, arg_end, env_start, env_end)) = fs::read_to_string("/proc/self/stat")
        .ok()
        .and_then(|s| parse_cmdline_area(&s))
    else {
        return;
    };
    if arg_end <= arg_start {
        return;
    }
    // The environment strings follow argv in the usual layout: reuse them only in that case.
    let reuse_env = env_start == arg_end && env_end > env_start;
    let end = if reuse_env { env_end } else { arg_end };
    let area = end - arg_start;

    if reuse_env {
        // Copy the environment to the heap before its original strings are overwritten.
        let vars: Vec<(std::ffi::OsString, std::ffi::OsString)> = env::vars_os().collect();
        unsafe {
            libc::clearenv();
        }
        for (k, v) in vars {
            env::set_var(k, v);
        }
    }

    let bytes = title.as_bytes();
    let len = bytes.len().min(area - 1);
    unsafe {
        let dst = arg_start as *mut u8;
        std::ptr::write_bytes(dst, 0, area);
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), dst, len);
    }
}

#[cfg(not(target_os = "linux"))]
fn apply_process_title() {}

fn main() {
    let args: Vec<String> = env::args().collect();

    // Handle flags
    if args.len() > 1 {
        match args[1].as_str() {
            "--help" | "-h" => {
                println!("Rhino Container Entrypoint (PID 1)");
                println!("Usage: rhino-entrypoint [FLAGS] [COMMAND...]");
                println!();
                println!("Flags:");
                println!("  -h, --help       Show this help message");
                println!("  -v, --version    Show version");
                println!("  --dry-run        Interpolate command and print without executing");
                return;
            }
            "--version" | "-v" => {
                println!("rhino-entrypoint v0.1.0");
                return;
            }
            _ => {}
        }
    }

    // Determine target working directory
    let workdir_str = env::var("HOME_DIR").unwrap_or_else(|_| DEFAULT_WORKDIR.to_string());
    let workdir = PathBuf::from(&workdir_str);

    if workdir.exists() {
        if let Err(e) = env::set_current_dir(&workdir) {
            eprintln!(
                "[rhino-entrypoint] Warning: Could not chdir to {}: {}",
                workdir.display(),
                e
            );
        }
    } else {
        eprintln!(
            "[rhino-entrypoint] Notice: Directory {} does not exist, staying in current directory.",
            workdir.display()
        );
    }

    let is_dry_run = args.len() > 1 && args[1] == "--dry-run";
    let raw_args = if is_dry_run { &args[2..] } else { &args[1..] };

    // Determine raw startup command:
    // 1. If STARTUP env var is present and non-empty, prioritize it (Rhino Action standard).
    // 2. Otherwise use arguments passed to container.
    let startup_env = env::var("STARTUP").unwrap_or_default().trim().to_string();
    let raw_cmd = if !startup_env.is_empty() {
        startup_env
    } else if !raw_args.is_empty() {
        raw_args.join(" ")
    } else {
        eprintln!(
            "[rhino-entrypoint] Error: No command or STARTUP environment variable specified."
        );
        eprintln!("Usage: rhino-entrypoint [COMMAND...] or set STARTUP variable.");
        process::exit(1);
    };

    // Interpolate environment variables safely in-memory
    let interpolated = interpolate_variables(&raw_cmd);

    if is_dry_run {
        println!("{}", interpolated);
        return;
    }

    check_security_profile();
    print_banner(&workdir, &interpolated);
    // Still single-threaded, `args` already copied: safe to rewrite the command line now.
    apply_process_title();

    // Stop timeout (time to wait after SIGTERM before sending SIGKILL)
    let stop_timeout = env::var("RHINO_STOP_TIMEOUT")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(DEFAULT_STOP_TIMEOUT_SECS);

    // The shell decision is taken on the TEMPLATE (written by the administrator in the Now),
    // never on the interpolated line: a variable value cannot switch to shell mode, and once in
    // shell mode values are expanded by the shell itself (never parsed as code).
    let force_shell = env::var("RHINO_USE_SHELL").unwrap_or_default() == "1";
    let needs_shell = force_shell || contains_shell_metacharacters(&raw_cmd);

    let mut command = if needs_shell {
        eprintln!("[rhino-entrypoint] Spawning via /bin/sh -c (shell control structures detected)");
        let mut c = Command::new("/bin/sh");
        c.arg("-c").arg(to_shell_references(&raw_cmd));
        c
    } else {
        // Split the TEMPLATE first, then expand each argument: a value containing spaces or
        // quotes stays one argument.
        let tokens: Vec<String> = tokenize_command(&raw_cmd)
            .iter()
            .map(|t| interpolate_variables(t))
            .collect();
        if tokens.is_empty() {
            eprintln!("[rhino-entrypoint] Error: Tokenized command is empty.");
            process::exit(1);
        }
        let mut c = Command::new(&tokens[0]);
        if tokens.len() > 1 {
            c.args(&tokens[1..]);
        }
        c
    };

    // Configure child process: inherit stdio for interactive game server console
    command.stdin(Stdio::inherit());
    command.stdout(Stdio::inherit());
    command.stderr(Stdio::inherit());

    // Isolate into its own process group so signals can be broadcast
    unsafe {
        command.pre_exec(|| {
            libc::setpgid(0, 0);
            // With a TTY (Rhino Action consoles), the new process group must also become the
            // terminal's FOREGROUND group: otherwise reading stdin raises SIGTTIN and the game
            // server is stopped (state T) as soon as a console command arrives. SIGTTOU is
            // ignored for the call because we are not yet in the foreground.
            if libc::isatty(libc::STDIN_FILENO) == 1 {
                let previous = libc::signal(libc::SIGTTOU, libc::SIG_IGN);
                libc::tcsetpgrp(libc::STDIN_FILENO, libc::getpid());
                libc::signal(libc::SIGTTOU, previous);
            }
            Ok(())
        });
    }

    // Optional background services (e.g. Xvfb)
    let xvfb_process = maybe_start_xvfb();

    // Register Unix signal handlers
    register_signals();

    // Spawn the game server process
    let child = match command.spawn() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("[rhino-entrypoint] FATAL: Failed to spawn process: {}", e);
            if let Some(mut xvfb) = xvfb_process {
                let _ = xvfb.kill();
            }
            process::exit(127);
        }
    };

    let child_pid = child.id() as libc::pid_t;
    eprintln!(
        "[rhino-entrypoint] Game server spawned with PID {} (Group {})",
        child_pid, child_pid
    );

    let mut terminating = false;
    let mut term_start = Instant::now();
    let mut exit_code: i32 = 0;

    // Main event loop as PID 1
    loop {
        // 1. Check for caught signals
        let sig = CAUGHT_SIGNAL.swap(0, Ordering::SeqCst);
        if sig != 0 {
            eprintln!(
                "[rhino-entrypoint] Caught signal {} ({}), forwarding to process group -{}",
                signal_name(sig),
                sig,
                child_pid
            );

            // Forward signal to the entire child process group
            unsafe {
                libc::kill(-child_pid, sig);
            }

            if (sig == libc::SIGTERM || sig == libc::SIGINT || sig == libc::SIGQUIT) && !terminating
            {
                terminating = true;
                term_start = Instant::now();
            }
        }

        // 2. Check if primary child exited
        let mut status: libc::c_int = 0;
        let res = unsafe { libc::waitpid(child_pid, &mut status, libc::WNOHANG) };

        if res == child_pid {
            if libc::WIFEXITED(status) {
                exit_code = libc::WEXITSTATUS(status);
                eprintln!(
                    "[rhino-entrypoint] Game server exited normally with status {}",
                    exit_code
                );
            } else if libc::WIFSIGNALED(status) {
                let term_sig = libc::WTERMSIG(status);
                exit_code = 128 + term_sig;
                eprintln!(
                    "[rhino-entrypoint] Game server terminated by signal {} ({})",
                    signal_name(term_sig),
                    term_sig
                );
            }
            break;
        }

        // 3. Reap any orphan/zombie child processes
        reap_zombies();

        // 4. Handle termination timeout -> SIGKILL
        if terminating && term_start.elapsed() > Duration::from_secs(stop_timeout) {
            eprintln!(
                "[rhino-entrypoint] Stop timeout of {}s exceeded. Sending SIGKILL to process group -{}",
                stop_timeout, child_pid
            );
            unsafe {
                libc::kill(-child_pid, libc::SIGKILL);
            }
            // Allow a short moment for SIGKILL to take effect
            std::thread::sleep(Duration::from_millis(200));
        }

        // Low-latency, low-CPU poll sleep (50 ms)
        std::thread::sleep(Duration::from_millis(50));
    }

    // Cleanup background helper if started
    if let Some(mut xvfb) = xvfb_process {
        let _ = xvfb.kill();
        let _ = xvfb.wait();
    }

    // Final zombie reaping before exit
    reap_zombies();

    eprintln!(
        "[rhino-entrypoint] Container lifecycle ended. Exiting with code {}.",
        exit_code
    );
    process::exit(exit_code);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_variable_interpolation_curly() {
        env::set_var("SERVER_PORT", "25565");
        env::set_var("SERVER_MEMORY", "4096");
        let input = "java -Xmx{{SERVER_MEMORY}}M -jar server.jar --port {{SERVER_PORT}}";
        let output = interpolate_variables(input);
        assert_eq!(output, "java -Xmx4096M -jar server.jar --port 25565");
    }

    #[test]
    fn test_variable_interpolation_posix() {
        env::set_var("WORLD_NAME", "rhino_land");
        let input = "echo Starting ${WORLD_NAME} on $WORLD_NAME";
        let output = interpolate_variables(input);
        assert_eq!(output, "echo Starting rhino_land on rhino_land");
    }

    #[test]
    fn test_tokenize_command_with_quotes() {
        let cmd = "java -Xmx2G -jar \"server jar with spaces.jar\" 'nogui' \\-test";
        let tokens = tokenize_command(cmd);
        assert_eq!(
            tokens,
            vec![
                "java",
                "-Xmx2G",
                "-jar",
                "server jar with spaces.jar",
                "nogui",
                "-test"
            ]
        );
    }

    #[test]
    fn test_parse_cmdline_area() {
        // Field 2 contains spaces and a ')' on purpose.
        let mut stat = String::from("1 (rhino entry) x) S");
        for n in 4..=52 {
            stat.push_str(&format!(" {}", n * 10));
        }
        assert_eq!(parse_cmdline_area(&stat), Some((480, 490, 500, 510)));
        assert_eq!(parse_cmdline_area("garbage"), None);
    }

    #[test]
    fn test_sanitize_title() {
        assert_eq!(
            sanitize_title("Rhino Instance Lobby\n\u{7}"),
            "Rhino Instance Lobby"
        );
        let long = "é".repeat(300);
        let t = sanitize_title(&long);
        assert!(t.len() <= PROCESS_TITLE_MAX && t.chars().all(|c| c == 'é'));
    }

    #[test]
    fn test_values_never_become_code() {
        // Shell mode: values are referenced, not pasted.
        assert_eq!(
            to_shell_references("cd x && java -Xmx{{SERVER_MEMORY}}M -jar \"{{JAR}}\""),
            "cd x && java -Xmx${SERVER_MEMORY}M -jar \"${JAR}\""
        );
        assert_eq!(to_shell_references("echo {{A;B}} {{ OK }}"), "echo  ${OK}");
        assert_eq!(to_shell_references("echo {{unclosed"), "echo {{unclosed");
        // Direct mode: one template token = one argument, whatever the value contains.
        unsafe { env::set_var("RHINO_TEST_VALUE", "a b; rm -rf / $(id)") };
        let tokens: Vec<String> = tokenize_command("run --name {{RHINO_TEST_VALUE}}")
            .iter()
            .map(|t| interpolate_variables(t))
            .collect();
        assert_eq!(tokens, vec!["run", "--name", "a b; rm -rf / $(id)"]);
        assert!(!contains_shell_metacharacters(
            "run --name {{RHINO_TEST_VALUE}}"
        ));
    }

    #[test]
    fn test_shell_metacharacters() {
        assert!(contains_shell_metacharacters("echo 1 | grep 1"));
        assert!(contains_shell_metacharacters("cat file > output.txt"));
        assert!(contains_shell_metacharacters("cmd1 && cmd2"));
        assert!(!contains_shell_metacharacters(
            "java -Xmx2G -jar server.jar"
        ));
        assert!(!contains_shell_metacharacters(
            "echo \"safe | pipe inside quote\""
        ));
    }
}
