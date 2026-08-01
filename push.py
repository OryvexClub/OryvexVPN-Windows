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

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

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
            "description": "OryvexVPN - Windows WireGuard dashboard with automatic endpoint scanning",
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

    def push_to_github(self) -> bool:
        print("\n" + "=" * 60)
        print("Pushing to GitHub")
        print("=" * 60)
        os.chdir(self.root)

        fixer_path = self.root / "fixer.py"
        if fixer_path.exists():
            self.log("Running fixer.py...", "STEP")
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "utf-8"
            try:
                result = subprocess.run(
                    [sys.executable, "fixer.py"],
                    cwd=self.root, capture_output=True, text=True,
                    timeout=120, env=env, encoding='utf-8', errors='replace'
                )
                if result.returncode != 0:
                    self.log(f"fixer.py failed. Output:\n{result.stdout}\n{result.stderr}", "ERROR")
                    if input("Continue? (y/n): ").strip().lower() != 'y':
                        return False
            except Exception as e:
                self.log(f"Error running fixer.py: {e}", "ERROR")
                if input("Continue? (y/n): ").strip().lower() != 'y':
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

        self.log("Committing...", "STEP")
        success, output = self.run_command('git commit -m "OryvexVPN: RTL UI updates + Bundled WireGuard MSI extraction"')
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
        print("\nBuilds will start automatically (takes 3-5 minutes)")
        print("\nDownload will be available as an artifact after build:")
        print("   1. Go to Actions tab")
        print("   2. Click on the latest workflow run")
        print("   3. Scroll down to Artifacts section")
        print("   4. Download the Windows EXE")
        try:
            print("\nOpening GitHub Actions in browser...")
            webbrowser.open(actions_url)
        except Exception:
            pass

    def run(self):
        print("\n" + "=" * 60)
        print("OryvexVPN - Push & Build")
        print("=" * 60)
        print("\nWill build: Windows EXE (real WireGuard connection with automatic config generation)")

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