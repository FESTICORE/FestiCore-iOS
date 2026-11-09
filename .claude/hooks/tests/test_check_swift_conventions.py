import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest


CHECKER = pathlib.Path(__file__).resolve().parents[1] / "check-swift-conventions.py"
spec = importlib.util.spec_from_file_location("check_swift_conventions", CHECKER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SwiftConventionsTests(unittest.TestCase):
    def test_positional_string_arguments_are_counted(self):
        issues = module.check('download("festival", generation: 0)', "Sample.swift")
        self.assertTrue(any("인자가 2개" in issue for issue in issues))
        issues = module.check('render("first", "second")', "Sample.swift")
        self.assertTrue(any("인자가 2개" in issue for issue in issues))
        self.assertEqual([], module.check('render(\n  "first",\n  "second"\n)', "Sample.swift"))

    def test_pure_router_container_matches_attendance(self):
        source = r"""
        struct ExampleCoordinatorView: View {
          @Bindable var store: StoreOf<ExampleCoordinator>
          var body: some View {
            TCAFlowRouter(store.scope(
              state: \.routes,
              action: \.router
            )) { screen in Text("Page") }
          }
        }
        """
        self.assertEqual([], module.check(source, "ExampleCoordinatorView.swift"))
        with_action = source.replace('Text("Page")', 'Button("Go") { store.send(.go) }')
        issues = module.check(with_action, "ExampleCoordinatorView.swift")
        self.assertTrue(any("@ViewAction" in issue for issue in issues))

    def test_stdin_mode_reports_violation_without_crashing(self):
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--stdin-filename", "Sample.swift"],
            input="func number() -> Int { 1 }", capture_output=True, text=True,
        )
        self.assertEqual(1, result.returncode)
        self.assertIn("return", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_base_mode_rejects_missing_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(["git", "init", "-q", directory], check=True)
            result = subprocess.run(
                [sys.executable, str(CHECKER), "--base", "missing"],
                cwd=directory, capture_output=True, text=True,
            )
            self.assertEqual(2, result.returncode)

    def test_base_mode_checks_new_lines_and_untracked_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = root / "Sample.swift"
            source.write_text("func legacy() -> Int { 1 }\n")
            for command in [
                ["git", "init", "-q"],
                ["git", "add", "Sample.swift"],
                ["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture"],
            ]:
                subprocess.run(command, cwd=root, check=True, capture_output=True)
            command = [sys.executable, str(CHECKER), "--base", "HEAD"]
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            source.write_text(source.read_text() + "func changed() -> Int { 2 }\n")
            (root / "New.swift").write_text("func added() -> Int { 3 }\n")
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertIn("Sample.swift:2", result.stderr)
            self.assertIn("New.swift:1", result.stderr)
            self.assertNotIn("Sample.swift:1", result.stderr)

    def test_explicit_return_in_function_and_computed_property(self):
        source = """
        func makeURL() -> URL { URL(string: base)! }
        var count: Int { items.count }
        """
        issues = module.check(source, "Sample.swift")
        self.assertEqual(2, len(issues))
        self.assertIn("func makeURL", issues[0])
        self.assertIn("var count", issues[1])

    def test_return_and_builder_are_accepted(self):
        source = """
        func makeURL() -> URL { return URL(string: base)! }
        var count: Int { return items.count }
        @ViewBuilder private func section() -> some View {
          VStack { Text("A"); Text("B") }
        }
        """
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_stored_property_and_body_builder_are_not_flagged(self):
        source = """
        struct ExampleView: View {
          let store: StoreOf<ExampleFeature>
          var body: some View { VStack { Text("A") } }
        }
        """
        issues = module.check(source, "Sample.swift")
        self.assertEqual(1, len(issues))
        self.assertIn("@ViewAction", issues[0])

    def test_reducer_handler_check(self):
        source = """
        @Reducer struct ExampleFeature {
          enum Action { case view(View) }
          var body: some ReducerOf<Self> { Reduce { state, action in .none } }
        }
        """
        issues = module.check(source, "Sample.swift")
        self.assertEqual(1, len(issues))
        self.assertIn("handleViewAction", issues[0])

    def test_comment_and_string_do_not_create_fake_declarations(self):
        source = '''
        // var count: Int { 1 }
        let text = "func f() -> Int { 1 }"
        var count: Int { return 1 }
        '''
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_stack_section_uses_viewbuilder_function(self):
        source = """
        private extension ExampleView {
          var section: some View { VStack { Text("A"); Text("B") } }
          private func anotherSection() -> some View { VStack { Text("A") } }
          @ViewBuilder private func correctSection() -> some View { VStack { Text("A") } }
        }
        """
        issues = module.check(source, "ExampleView.swift")
        self.assertEqual(2, len(issues))
        self.assertIn("var section", issues[0])
        self.assertIn("func anotherSection", issues[1])

    def test_multiple_root_views_require_builder(self):
        source = """
        private extension ExampleView {
          private func section() -> some View {
            Text("A")
            Image(systemName: "star")
          }
        }
        """
        issues = module.check(source, "ExampleView.swift")
        self.assertEqual(1, len(issues))
        self.assertIn("@ViewBuilder", issues[0])

    def test_state_initializer_closure_is_not_computed_property(self):
        source = """
        @State private var store = Store(initialState: State()) {
          Feature()
        }
        """
        self.assertEqual([], module.check(source, "FeatureView.swift"))

    def test_only_changed_declarations_are_checked(self):
        source = "var old: Int { value }\nvar new: Int { other }\n"
        issues = module.check(source, "Sample.swift", changed_lines={2})
        self.assertEqual(1, len(issues))
        self.assertIn("var new", issues[0])

    def test_two_parameters_each_start_on_new_line(self):
        source = """
        func load(id: String, version: Int) -> Void {}
        init(
          id: String, version: Int
        ) {}
        """
        issues = module.check(source, "Sample.swift")
        self.assertEqual(2, len(issues))
        self.assertTrue(all("파라미터가 2개 이상" in issue for issue in issues))

    def test_single_parameter_and_multiline_declarations_are_accepted(self):
        source = """
        func load(id: String) -> Void {}
        func make<T: Hashable, U>(
          ids: [T: U],
          callback: (T, U) -> Void
        ) -> Void {}
        required init(
          id: String,
          values: [String: (Int, Int)] = [:]
        ) {}
        """
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_nested_commas_and_strings_do_not_count_as_parameters(self):
        source = '''
        func one(value: Result<(Int, Int), Error>) -> Void {}
        let text = "func fake(a: Int, b: Int) {}"
        // init(a: Int, b: Int) {}
        func two(
          value: Result<(Int, Int), Error>,
          fallback: [String: (Int, Int)]
        ) -> Void {}
        '''
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_changed_parameter_line_is_checked(self):
        source = "func load(\n  id: String, version: Int\n) -> Void {}\n"
        issues = module.check(source, "Sample.swift", changed_lines={2})
        self.assertEqual(1, len(issues))
        self.assertEqual([], module.check(source, "Sample.swift", changed_lines={4}))

    def test_default_closure_is_not_treated_as_function_body(self):
        source = """
        func make(
          first: () -> Int = { 1 },
          second: () -> Int = { 2 }
        ) -> Int {
          return first() + second()
        }
        """
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_two_call_arguments_each_start_on_new_line(self):
        source = "let result = make(id: 1, name: \"A\")\n"
        issues = module.check(source, "Sample.swift", changed_lines={1})
        self.assertEqual(1, len(issues))
        self.assertIn("인자가 2개 이상", issues[0])

    def test_switch_case_pattern_may_stay_on_one_line(self):
        source = "    case let .router(.routeAction(id: _, action: .joined(crewID, festivalID))):\n"
        self.assertEqual([], module.check(source, "Sample.swift", changed_lines={1}))
        source = "    case .home(.a), .home(.b(x, y)):\n"
        self.assertEqual([], module.check(source, "Sample.swift", changed_lines={1}))

    def test_call_in_case_body_is_still_checked(self):
        source = "    case .home:\n      return make(id: 1, name: \"A\")\n"
        issues = module.check(source, "Sample.swift", changed_lines={1, 2})
        self.assertEqual(1, len(issues))

    def test_multiline_call_and_nested_commas_are_accepted(self):
        source = """
        let result = make(
          value: Result<(Int, Int), Error>.success((1, 2)),
          name: "A"
        )
        """
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_only_changed_calls_are_checked(self):
        source = "let old = make(a: 1, b: 2)\nlet new = make(a: 3, b: 4)\n"
        issues = module.check(source, "Sample.swift", changed_lines={2})
        self.assertEqual(1, len(issues))
        self.assertIn(":2:", issues[0])

    def test_multi_statement_returning_function_needs_return(self):
        source = "func count() -> Int {\n  let value = items.count\n  value\n}\n"
        issues = module.check(source, "Sample.swift", changed_lines={1})
        self.assertEqual(1, len(issues))
        self.assertIn("명시적 return", issues[0])

    def test_void_function_and_viewbuilder_need_no_return(self):
        source = """
        func notify() -> Void { print("ok") }
        @ViewBuilder func content() -> some View { Text("A") }
        """
        self.assertEqual([], module.check(source, "Sample.swift"))

    def test_view_helpers_and_direct_store_send_are_blocked(self):
        source = """
        @ViewAction(for: Feature.self)
        struct ExampleView: View {
          let store: StoreOf<Feature>
          var body: some View { Text("A") }
          var title: some View { Text("A") }
          func tap() { store.send(.view(.tap)) }
        }
        """
        issues = module.check(source, "Projects/Feature/X/View/ExampleView.swift")
        self.assertTrue(any("private extension" in issue for issue in issues))
        self.assertTrue(any("store.send" in issue or "send(.viewAction)" in issue for issue in issues))

    def test_domain_contract_requires_doc_comment(self):
        path = "Projects/Domain/X/Interface/Sources/X/XUseCaseInterface.swift"
        self.assertTrue(any("///" in issue for issue in module.check(
            "public protocol XUseCaseInterface: Sendable {}", path
        )))
        self.assertEqual([], module.check(
            "/// Reads X values.\npublic protocol XUseCaseInterface: Sendable {}", path
        ))


if __name__ == "__main__":
    unittest.main()
