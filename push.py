import sys
import os
import subprocess
import webbrowser
import threading
import time
import re
from pathlib import Path
from getpass import getpass
from typing import Tuple

# Fix Windows console encoding issues
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

COMMIT_MESSAGE = "Complete VPN fixes: Real monitoring, Persian UI, config manager, stability improvements"

class GitHubPusher:
    def __init__(self, project_root=None):
        self.root = Path(project_root or os.getcwd())
        self.username = ""
        self.token = ""
        self.repo_name = "oryvex_vpn_demo"

    def log(self, message, level="INFO"):
        icons = {
            "INFO": "[i]", "SUCCESS": "[OK]", "WARNING": "[!]",
            "ERROR": "[X]", "STEP": "[>]", "SECURE": "[SEC]"
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def check_git(self) -> bool:
        try:
            result = subprocess.run(
                ["git", "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.log(f"Git found: {result.stdout.strip()}", "SUCCESS")
                return True
        except Exception:
            pass
        self.log("Git not found! Please install Git first.", "ERROR")
        return False

    def test_token(self) -> bool:
        import urllib.request
        import json
        self.log("Testing GitHub token...", "SECURE")
        try:
            req = urllib.request.Request(
                "https://api.github.com/user",
                headers={"Authorization": f"token {self.token}", "User-Agent": "OryvexVPN"},
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
                self.username = data.get('login', '')
                self.log(f"Authenticated as: {self.username}", "SUCCESS")
                return True
        except Exception as e:
            self.log(f"Token invalid: {e}", "ERROR")
            return False

    def get_credentials(self) -> bool:
        print("\n" + "=" * 60)
        print("GitHub Login")
        print("=" * 60)
        print("\nCreate a token: https://github.com/settings/tokens")
        print("Select scopes: 'repo' and 'workflow'")
        print("NEVER commit this token to git or share it.\n")

        username = input("GitHub Username: ").strip()
        token = getpass("Personal Access Token (hidden): ").strip()

        if not username or not token:
            self.log("Username and token are required!", "ERROR")
            return False

        self.username = username
        self.token = token
        return self.test_token()

    def run_command(self, cmd, env=None, ignore_error: bool = False, timeout: int = 120) -> Tuple[bool, str]:
        try:
            result = subprocess.run(
                cmd, shell=True, cwd=self.root, capture_output=True,
                text=True, timeout=timeout, env=env
            )
            if result.returncode == 0:
                return True, result.stdout.strip()
            if ignore_error:
                return True, result.stdout.strip()
            error = result.stderr.strip() or result.stdout.strip()
            return False, error
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)

    def create_repo_if_missing(self) -> bool:
        import urllib.request
        import urllib.error
        self.log("Checking if repository exists...", "STEP")
        req = urllib.request.Request(
            f"https://api.github.com/repos/{self.username}/{self.repo_name}",
            headers={
                "Authorization": f"token {self.token}",
                "User-Agent": "OryvexVPN",
                "Accept": "application/vnd.github.v3+json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    self.log(f"Repository exists: {self.repo_name}", "SUCCESS")
                    return True
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.log("Repository doesn't exist, creating...", "WARNING")
                return self._create_repo()
            self.log(f"Failed to check repository: {e}", "ERROR")
            return False
        except Exception as e:
            self.log(f"Error checking repository: {e}", "ERROR")
            return False
        return False

    def _create_repo(self) -> bool:
        import urllib.request
        import json
        data = json.dumps({
            "name": self.repo_name,
            "description": "OryvexVPN - Professional Windows VPN Client with Full Persian UI powered by WireGuard",
            "private": False,
            "auto_init": False,
        }).encode('utf-8')
        req = urllib.request.Request(
            "https://api.github.com/user/repos",
            data=data,
            headers={
                "Authorization": f"token {self.token}",
                "User-Agent": "OryvexVPN",
                "Content-Type": "application/json",
                "Accept": "application/vnd.github.v3+json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                if resp.status in (200, 201):
                    self.log(f"Repository created: {self.repo_name}", "SUCCESS")
                    return True
                self.log(f"Failed to create repository: {resp.status}", "ERROR")
                return False
        except Exception as e:
            self.log(f"Error creating repository: {e}", "ERROR")
            return False

    def _check_diff_for_token(self) -> bool:
        success, diff = self.run_command('git diff --cached', ignore_error=True)
        if not success:
            return False
        pattern = re.compile(r'ghp_[A-Za-z0-9_]{36,}')
        if pattern.search(diff):
            self.log("GitHub token found in staged files!", "ERROR")
            return True
        return False

    def run_fixer_and_verify(self) -> bool:
        """
        Run fixer.py, then independently verify with `fixer.py --check`
        that the project is actually in a correct state before allowing
        any push to proceed.

        This closes a gap where fixer.py's apply-mode run exits 0 (its
        normal exit code for both "I fixed something" AND "there was
        nothing to fix") even when the project is still broken - for
        example if an earlier version of fixer.py's checks were too
        loose and missed a real problem (as happened with the
        VS_MANIFEST_UAC / LNK1327 issue: check_cmakelists() used to
        report "OK" without verifying VS_MANIFEST_UAC was disabled, so
        apply-mode had nothing to change, exited 0, and this script
        pushed a build that was still guaranteed to fail in CI).

        A bare returncode == 0 from apply-mode is NOT sufficient
        evidence the project is buildable. --check is the actual
        source of truth, so we always run it after apply-mode and
        refuse to push if it still fails.
        """
        fixer_path = self.root / "fixer.py"
        if not fixer_path.exists():
            self.log("fixer.py not found - skipping fixer/verification step.", "WARNING")
            return True

        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"

        self.log("Running fixer.py...", "STEP")
        try:
            result = subprocess.run(
                [sys.executable, "fixer.py"],
                cwd=self.root, capture_output=True, text=True,
                timeout=120, env=env, encoding='utf-8', errors='replace'
            )
            print(result.stdout)
            if result.returncode != 0:
                self.log(f"fixer.py failed. Output:\n{result.stdout}\n{result.stderr}", "ERROR")
                if input("Continue anyway? (y/n): ").strip().lower() != 'y':
                    return False
        except Exception as e:
            self.log(f"Error running fixer.py: {e}", "ERROR")
            if input("Continue anyway? (y/n): ").strip().lower() != 'y':
                return False

        # Independently verify the project is actually correct now.
        # This is the check that used to be missing: apply-mode exiting
        # 0 was treated as proof of a working build, when it only means
        # "no error occurred while applying fixes" - not "the checks
        # fixer.py knows about all currently pass."
        self.log("Verifying fix with fixer.py --check...", "STEP")
        try:
            check_result = subprocess.run(
                [sys.executable, "fixer.py", "--check"],
                cwd=self.root, capture_output=True, text=True,
                timeout=60, env=env, encoding='utf-8', errors='replace'
            )
            print(check_result.stdout)
            if check_result.returncode != 0:
                self.log(
                    "fixer.py --check still reports problems after running "
                    "fixer.py. Pushing now would ship a build that is very "
                    "likely to fail in CI again.",
                    "ERROR",
                )
                self.log(check_result.stdout.strip() or check_result.stderr.strip(), "ERROR")
                if input(
                    "Push anyway despite failing checks? This is NOT recommended. (y/n): "
                ).strip().lower() != 'y':
                    return False
                self.log(
                    "Proceeding with a push that fixer.py --check flagged as broken, "
                    "per your override.",
                    "WARNING",
                )
            else:
                self.log("fixer.py --check passed - project looks correct.", "SUCCESS")
        except Exception as e:
            self.log(f"Error running fixer.py --check: {e}", "ERROR")
            if input("Continue without verification? (y/n): ").strip().lower() != 'y':
                return False

        return True

    def push_to_github(self) -> bool:
        print("\n" + "=" * 60)
        print("Pushing to GitHub")
        print("=" * 60)
        os.chdir(self.root)

        if not self.run_fixer_and_verify():
            return False

        if not (self.root / ".git").exists():
            self.log("Initializing git repository...", "STEP")
            success, output = self.run_command("git init")
            if not success:
                self.log(f"Failed to init git: {output}", "ERROR")
                return False

        self.log("Setting git config...", "STEP")
        self.run_command('git config user.email "oryvex@demo.com"')
        self.run_command('git config user.name "OryvexVPN"')

        self.log("Adding all files...", "STEP")
        success, output = self.run_command("git add .")
        if not success:
            self.log(f"Failed to add files: {output}", "ERROR")
            return False

        if self._check_diff_for_token():
            self.log("Push blocked due to token in staging. Run fixer.py to scrub tokens.", "ERROR")
            return False

        # Show exactly what's about to be committed, so a silent no-op
        # (nothing staged despite believing a fix was applied) is
        # visible before pushing rather than discovered after CI fails
        # again.
        success, staged = self.run_command("git diff --cached --stat", ignore_error=True)
        if success:
            if staged:
                self.log("Changes staged for commit:", "INFO")
                print(staged)
            else:
                self.log(
                    "No changes are staged. If you expected fixer.py to change "
                    "files, this push will not contain that fix.",
                    "WARNING",
                )

        self.log("Committing...", "STEP")
        success, output = self.run_command(f'git commit -m "{COMMIT_MESSAGE}"')
        if not success and "nothing to commit" not in output:
            self.log(f"Commit warning: {output}", "WARNING")

        self.log("Setting up remote...", "STEP")
        self.run_command("git branch -M main")
        self.run_command("git remote remove origin", ignore_error=True)
        self.run_command(f"git remote add origin https://github.com/{self.username}/{self.repo_name}.git", ignore_error=True)

        self.log("Pushing to GitHub...", "STEP")
        print("\nPushing... this may take a moment...\n")

        push_complete = [False]
        push_result = [None]

        def do_push():
            try:
                push_url_with_auth = f"https://{self.username}:{self.token}@github.com/{self.username}/{self.repo_name}.git"
                result = subprocess.run(
                    ["git", "push", push_url_with_auth, "main", "--force"],
                    cwd=self.root, capture_output=True, text=True, timeout=180
                )
                push_result[0] = result
                push_complete[0] = True
            except subprocess.TimeoutExpired:
                push_complete[0] = True
                push_result[0] = None
            except Exception as e:
                push_complete[0] = True
                push_result[0] = e

        push_thread = threading.Thread(target=do_push)
        push_thread.daemon = True
        push_thread.start()

        dots = 0
        while not push_complete[0]:
            dots = (dots + 1) % 4
            print(f"\rPushing{' .' * dots}   ", end="", flush=True)
            time.sleep(0.5)
        print("\r" + " " * 30 + "\r", end="", flush=True)

        if push_result[0] is None:
            self.log("Push timed out after 3 minutes", "ERROR")
            return False
        if isinstance(push_result[0], Exception):
            self.log(f"Push error: {push_result[0]}", "ERROR")
            return False

        result = push_result[0]
        if result.returncode == 0:
            self.log("Push successful!", "SUCCESS")
            return True

        error = result.stderr.strip() or result.stdout.strip()
        if self.token in error:
            error = error.replace(self.token, "[TOKEN_HIDDEN]")
        self.log(f"Push failed: {error}", "ERROR")
        return False

    def show_build_status(self):
        actions_url = f"https://github.com/{self.username}/{self.repo_name}/actions"
        print("\n" + "=" * 60)
        print("GitHub Actions Status")
        print("=" * 60)
        print(f"\nRepository: https://github.com/{self.username}/{self.repo_name}")
        print(f"Actions: {actions_url}")
        print("\nBuilds will start automatically (takes 5-10 minutes)")
        print("\nDownload will be available as an artifact after build:")
        print("   1. Go to Actions tab")
        print("   2. Click on the latest workflow run")
        print("   3. Scroll down to Artifacts section")
        print("   4. Download 'OryvexVPN-Windows-Build.zip'")
        print("   5. Extract and run 'warp_vpn_app.exe' as Administrator")
        print("\n✅ What's Fixed:")
        print("   • Real VPN connection status (not fake)")
        print("   • Real statistics (speed, ping, IP)")
        print("   • No hanging on close")
        print("   • Full Persian language with RTL")
        print("   • Configuration management")
        print("   • Better stability and error handling")

        try:
            print("\nOpening GitHub Actions in browser...")
            webbrowser.open(actions_url)
        except Exception:
            pass

    def run(self):
        print("\n" + "=" * 60)
        print("OryvexVPN - Push & Build")
        print("=" * 60)
        print("\nThis will:")
        print("  1. Check for issues (if fixer.py exists)")
        print("  2. Stage all changes")
        print("  3. Commit with message")
        print("  4. Push to GitHub")
        print("  5. GitHub Actions will build automatically")

        if not self.check_git():
            sys.exit(1)

        if not self.root.exists():
            self.log(f"Directory not found: {self.root}", "ERROR")
            sys.exit(1)

        if not (self.root / "pubspec.yaml").exists():
            self.log("Not a Flutter project! No pubspec.yaml found.", "ERROR")
            sys.exit(1)

        if not self.get_credentials():
            sys.exit(1)

        if not self.create_repo_if_missing():
            self.log("Failed to ensure repository exists", "ERROR")
            sys.exit(1)

        if self.push_to_github():
            self.show_build_status()
        else:
            self.log("Push failed. Try manual push:", "ERROR")
            print(f"\n   cd {self.root}")
            print("   git push -u origin main --force")
            print("   (Enter your GitHub username and a Personal Access Token as the password)")
            sys.exit(1)

def main():
    try:
        pusher = GitHubPusher()
        pusher.run()
    except KeyboardInterrupt:
        print("\nCancelled by user")
        sys.exit(0)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()