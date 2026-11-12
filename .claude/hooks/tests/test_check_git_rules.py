import importlib.machinery
import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


HOOKS = pathlib.Path(__file__).resolve().parents[1]
REPO = HOOKS.parents[1]
SCRIPTS = REPO / ".claude" / "scripts"


def load_script(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def run(*args, cwd, check=True):
    return subprocess.run(list(args), cwd=cwd, capture_output=True, text=True, check=check, stdin=subprocess.DEVNULL)


class GitRulesHookTests(unittest.TestCase):
    """실제 git 저장소(임시)에 훅을 복사해 PreToolUse 입력 그대로 실행한다."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="harness-test-")
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(os.path.join(self.repo, "Config"))
        shutil.copytree(HOOKS, os.path.join(self.repo, ".claude", "hooks"),
                        ignore=shutil.ignore_patterns("tests", "__pycache__"))
        run("git", "init", "-q", "-b", "develop", cwd=self.repo)
        run("git", "config", "user.name", "tester", cwd=self.repo)
        run("git", "config", "user.email", "tester@example.com", cwd=self.repo)
        with open(os.path.join(self.repo, "Config", "Stage.xcconfig"), "w") as f:
            f.write("A = 1\n")
        shutil.copyfile(REPO / ".gitignore", os.path.join(self.repo, ".gitignore"))
        # 실제 저장소처럼 훅을 추적한다(개인 전역 gitignore가 .claude/를 무시해도).
        run("git", "-c", "core.excludesFile=/dev/null", "add", "-A", cwd=self.repo)
        run("git", "commit", "-q", "-m", "init", cwd=self.repo)
        run("git", "checkout", "-q", "-b", "feature/agent-harness", cwd=self.repo)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def hook(self, command, cwd=None):
        payload = json.dumps({"tool_input": {"command": command}, "cwd": cwd or self.repo})
        return subprocess.run(["bash", os.path.join(self.repo, ".claude", "hooks", "check-git-rules.sh")],
                              input=payload, capture_output=True, text=True)

    def direct(self, *args):
        return subprocess.run(["bash", os.path.join(self.repo, ".claude", "hooks", "check-git-rules.sh"), *args],
                              capture_output=True, text=True)

    def assertBlocked(self, result, text):
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertIn(text, result.stderr)

    def test_non_git_command_passes(self):
        self.assertEqual(0, self.hook("ls -la").returncode)
        self.assertEqual(0, self.hook('echo "git commit -m x"').returncode)

    def test_valid_commit_passes(self):
        self.assertEqual(0, self.hook('git commit -m "하네스를 맞춘다 #396"').returncode)

    def test_protected_branch_commit_and_push_blocked(self):
        run("git", "checkout", "-q", "develop", cwd=self.repo)
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396"'), "보호 브랜치")
        self.assertBlocked(self.hook("git push origin develop"), "보호 브랜치")
        run("git", "checkout", "-q", "-b", "main", cwd=self.repo)
        self.assertBlocked(self.hook("git push"), "보호 브랜치")

    def test_push_to_protected_from_feature_blocked(self):
        self.assertBlocked(self.hook("git push origin HEAD:develop"), "직접 푸시")
        self.assertEqual(0, self.hook("git push -u origin feature/agent-harness").returncode)

    def test_branch_name(self):
        run("git", "checkout", "-q", "-b", "fix/harness", cwd=self.repo)
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396"'), "브랜치 이름")
        self.assertBlocked(self.direct("--check-branch", "feature/Agent_Harness"), "브랜치 이름")
        self.assertEqual(0, self.direct("--check-branch", "feature/more-settings-home").returncode)

    def test_english_subject_blocked(self):
        self.assertBlocked(self.hook('git commit -m "Add agent harness #396"'), "한국어")

    def test_missing_issue_number_blocked(self):
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다"'), "이슈 번호")
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #"'), "이슈 번호")
        self.assertBlocked(self.direct("--check-message", "#396 하네스를 맞춘다"), "이슈 번호")

    def test_cirqle_type_prefix_is_not_required(self):
        self.assertEqual(0, self.direct("--check-message", "하네스를 맞춘다 #396").returncode)
        self.assertEqual(0, self.direct("--check-message", "S10 화면을 맞춘다 #396 (#510)").returncode)

    def test_heredoc_message_checked(self):
        command = "git commit -F - <<'EOF'\nAdd harness #396\n\n본문\nEOF"
        self.assertBlocked(self.hook(command), "한국어")
        command = "git commit -F - <<'EOF'\n하네스를 맞춘다 #396\n\n본문\nEOF"
        self.assertEqual(0, self.hook(command).returncode)
        command = 'git commit -m "$(cat <<\'EOF\'\nAdd harness #396\n\n본문\nEOF\n)"'
        self.assertBlocked(self.hook(command), "한국어")

    def test_co_authored_by_blocked(self):
        command = ('git commit -m "$(cat <<\'EOF\'\n하네스를 맞춘다 #396\n\n'
                   'Co-Authored-By: Claude <noreply@anthropic.com>\nEOF\n)"')
        self.assertBlocked(self.hook(command), "Co-Authored-By")
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396" -m "co-authored-by: x <x@y>"'),
                           "Co-Authored-By")
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396" --trailer "Co-authored-by: x <x@y>"'),
                           "Co-Authored-By")

    def test_ds_store_blocked(self):
        open(os.path.join(self.repo, ".DS_Store"), "w").close()
        run("git", "add", "-f", ".DS_Store", cwd=self.repo)
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396"'), ".DS_Store")

    def test_unverified_code_blocked_until_verify_record_matches(self):
        sys.path.insert(0, os.path.join(self.repo, ".claude", "hooks"))
        import harness_state as hs
        config = os.path.join(self.repo, "Config", "Stage.xcconfig")
        with open(config, "a") as f:
            f.write("B = 2\n")
        run("git", "add", "-A", "Config", cwd=self.repo)
        self.assertBlocked(self.hook('git commit -m "설정을 바꾼다 #396"'), "검증하지 않은")
        hs.save(self.repo, {"passed": True, "fingerprint": hs.fingerprint(self.repo)})
        self.assertEqual(0, self.hook('git commit -m "설정을 바꾼다 #396"').returncode)
        with open(config, "a") as f:
            f.write("C = 3\n")
        self.assertBlocked(self.hook('git commit -m "설정을 바꾼다 #396"'), "검증하지 않은")

    def test_docs_only_change_needs_no_verify(self):
        os.makedirs(os.path.join(self.repo, "DesignExports"))
        for path in ("README.md", "DesignExports/screen.png"):
            with open(os.path.join(self.repo, path), "w") as f:
                f.write("x")
        run("git", "add", "-A", cwd=self.repo)
        self.assertEqual(0, self.hook('git commit -m "문서를 고친다 #396"').returncode)

    def test_worktree_reads_gitdir_head(self):
        worktree = os.path.join(self.tmp, "wt")
        run("git", "worktree", "add", "-q", worktree, "develop", cwd=self.repo)
        shutil.copytree(os.path.join(self.repo, ".claude", "hooks"), os.path.join(worktree, ".claude", "hooks"),
                        dirs_exist_ok=True)
        self.assertTrue(os.path.isfile(os.path.join(worktree, ".git")))
        sys.path.insert(0, str(HOOKS))
        import check_git_rules
        head = check_git_rules.head_file(os.path.join(worktree, "Config"))
        self.assertIn(os.path.join(".git", "worktrees"), head)
        self.assertEqual("develop", check_git_rules.current_branch(worktree))
        self.assertEqual("feature/agent-harness", check_git_rules.current_branch(self.repo))
        # 메인 checkout은 feature 브랜치지만 worktree는 develop이므로 막혀야 한다
        self.assertBlocked(self.hook('git commit -m "하네스를 맞춘다 #396"', cwd=worktree), "보호 브랜치")
        self.assertBlocked(self.hook(f'cd {worktree} && git commit -m "하네스를 맞춘다 #396"'), "보호 브랜치")

    def test_stop_guard_blocks_once(self):
        with open(os.path.join(self.repo, "Config", "Stage.xcconfig"), "a") as f:
            f.write("B = 2\n")
        guard = os.path.join(self.repo, ".claude", "hooks", "stop_guard.py")
        result = subprocess.run(["python3", "-I", "-S", guard], input=json.dumps({"cwd": self.repo}),
                                capture_output=True, text=True)
        self.assertEqual("block", json.loads(result.stdout)["decision"])
        result = subprocess.run(["python3", "-I", "-S", guard],
                                input=json.dumps({"cwd": self.repo, "stop_hook_active": True}),
                                capture_output=True, text=True)
        self.assertEqual("", result.stdout)


class VerifyAndBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.cwd = os.getcwd()
        os.chdir(REPO)
        self.verify = load_script("verify", SCRIPTS / "verify")
        self.boundaries = load_script("check_boundaries", SCRIPTS / "check-boundaries")

    def tearDown(self):
        os.chdir(self.cwd)

    def test_targets_follow_changed_modules(self):
        targets = self.verify.test_targets
        self.assertEqual(["FestivalTests"], targets(["Projects/Feature/Festival/Sources/A.swift"]))
        self.assertEqual(["FestiCoreTests"], targets(["Projects/App/Sources/A.swift"]))
        self.assertEqual(["FestiCoreTests"], targets(["Projects/Feature/FeatureAssembly/Sources/A.swift"]))
        self.assertEqual(["APIEndpointTests", "FestivalDomainTests"],
                         targets(["Projects/Domain/FestivalDomain/Interface/A.swift",
                                  "Projects/Service/APIEndpoint/Sources/B.swift"]))
        self.assertIsNone(targets(["Plugins/DependencyPlugin/X.swift"]))
        self.assertIsNone(targets(["Projects/App/Tests/FestiCore.xctestplan"]))

    def test_steps_for_paths(self):
        # install은 Tuist/.build/checkouts가 없을 때만 붙으므로 환경에 따라 달라져 비교에서 뺀다
        names = lambda files, run_all=False: [n for n, _ in self.verify.steps_for(files, run_all, "BASE")
                                              if n != "install"]
        self.assertEqual([], names([]))
        self.assertEqual(["harness-syntax", "harness-tests"], names([".claude/hooks/check_git_rules.py"]))
        self.assertEqual(["boundaries", "swift-conventions", "generate", "test"],
                         names(["Projects/App/Sources/A.swift"]))
        steps = dict(self.verify.steps_for(["Projects/App/Sources/A.swift"], False, "BASE"))
        self.assertEqual(["./make", "test", "-only-testing:FestiCoreTests"], steps["test"])
        self.assertEqual(["./make", "test"], dict(self.verify.steps_for([], True, "BASE"))["test"])

    def test_docs_and_design_exports_are_not_code(self):
        sys.path.insert(0, str(HOOKS))
        import harness_state as hs
        self.assertFalse(hs.is_code("Projects/App/README.md"))
        self.assertFalse(hs.is_code("DesignExports/S10/screen.png"))
        self.assertFalse(hs.is_code("docs/agent/harness.md"))
        self.assertTrue(hs.is_code("Projects/App/Sources/A.swift"))
        self.assertTrue(hs.is_code(".claude/hooks/check_git_rules.py"))

    def test_boundary_glob_stays_in_one_folder(self):
        matches = self.boundaries.matches
        self.assertTrue(matches("Projects/Feature/Festival/Sources/A/B.swift", "Projects/Feature/*/Sources/**/*.swift"))
        self.assertTrue(matches("Projects/Feature/Festival/Sources/B.swift", "Projects/Feature/*/Sources/**/*.swift"))
        self.assertFalse(matches("Projects/Feature/Festival/Tests/Sources/B.swift",
                                 "Projects/Feature/*/Sources/**/*.swift"))
        self.assertTrue(matches("Projects/Feature/FeatureAssembly/Sources/A.swift", "Projects/Feature/FeatureAssembly/**"))

    def test_boundary_rules_catch_violations(self):
        rules = {name: (pattern, allowed) for name, _, allowed, pattern, _ in self.boundaries.rules(str(REPO))}
        import re
        feature_domain = re.compile(rules["Feature는 Domain 구현을 import하지 않는다"][0], re.M)
        self.assertTrue(feature_domain.search("import FestivalDomain\n"))
        self.assertFalse(feature_domain.search("import FestivalDomainInterface\n"))
        self.assertFalse(feature_domain.search("// import FestivalDomain\n"))
        endpoint = re.compile(rules["APIEndpoint는 Domain · Auth Service에 의존하지 않는다"][0], re.M)
        self.assertTrue(endpoint.search("import AuthDomainInterface\n"))
        self.assertTrue(endpoint.search("import FestiCoreAuthInterface\n"))
        self.assertFalse(endpoint.search("import FestiCoreNetworkInterface\n"))
        app = re.compile(rules["App은 개별 Feature 구현을 import하지 않는다"][0], re.M)
        self.assertTrue(app.search("import Festival\n"))
        self.assertFalse(app.search("import FestivalInterface\n"))
        self.assertFalse(app.search("import FeatureAssembly\n"))


if __name__ == "__main__":
    unittest.main()
