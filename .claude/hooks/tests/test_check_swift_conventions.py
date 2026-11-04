import importlib.util
import pathlib
import unittest


CHECKER = pathlib.Path(__file__).resolve().parents[1] / "check-swift-conventions.py"
spec = importlib.util.spec_from_file_location("check_swift_conventions", CHECKER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SwiftConventionsTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
