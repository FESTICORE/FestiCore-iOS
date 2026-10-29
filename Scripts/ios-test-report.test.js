const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const childProcess = require('node:child_process')
const report = require('./ios-test-report.js').__test__

test('커버리지는 FestiCore 앱과 자체 모듈만 집계한다', () => {
  const names = report.internalCoverageTargetNames()
  assert.equal(names.has('FestiCore'), true)
  assert.equal(names.has('FestiCoreNetwork'), true)
  assert.equal(names.has('Alamofire'), false)

  const coverage = report.mergeCoverage([[
    { name: 'FestiCoreNetwork.framework', coveredLines: 5, executableLines: 10 },
    { name: 'Alamofire.framework', coveredLines: 90, executableLines: 100 },
    { name: 'FestiCoreNetworkTests.xctest', coveredLines: 10, executableLines: 10 },
  ]], names)
  assert.equal(coverage.coveredLines, 5)
  assert.equal(coverage.executableLines, 10)
})

test('두 샤드의 테스트 건수와 부분 커버리지를 PR 리포트에 표시한다', () => {
  const body = report.renderReport({
    summary: { passed: 8, failed: 1, skipped: 0, expectedFailures: 0,
      failures: [{ targetName: 'FestiCoreStorageTests', testIdentifierString: 'StorageTests/testRead', failureText: 'value mismatch' }],
      startTime: 1, finishTime: 11, device: null },
    coverage: { targets: [{ name: 'FestiCoreStorage', coveredLines: 5, executableLines: 10 }], coveredLines: 5, executableLines: 10 },
    coverageStats: { expected: 2, contributed: 1 },
    buildErrors: [], bundleInsights: null, outcome: 'failure',
    runUrl: 'https://github.com/FESTICORE/FestiCore-iOS/actions/runs/1', sha: 'abcdef012345',
  })
  assert.match(body, /8 passed/)
  assert.match(body, /1 failed/)
  assert.match(body, /테스트 케이스 총 9개/)
  assert.match(body, /Ran test modules.*테스트 모듈 수/)
  assert.match(body, /StorageTests\/testRead/)
  assert.match(body, /샤드 2개 중 1개/)
  assert.match(body, /50\.0%/)
})

test('번들 크기와 기준선 대비 증감을 PR 리포트에 표시한다', () => {
  const lines = report.renderBundleInsights({
    name: 'FestiCore',
    installSize: 1_100_000,
    downloadSize: 900_000,
    installSizeDelta: 100_000,
    downloadSizeDelta: -100_000,
    baselineInstallSize: 1_000_000,
    baselineDownloadSize: 1_000_000,
  })

  const body = lines.join('\n')
  assert.match(body, /FestiCore/)
  assert.match(body, /1\.1 MB/)
  assert.match(body, /\+10\.00%/)
  assert.match(body, /-10\.00%/)
})

test('재업로드된 샤드는 최신 시도만 선택한다', () => {
  const bundles = [
    '/tmp/pr-test-shard-1-0-retry-2/TestResults-0.xcresult',
    '/tmp/pr-test-shard-1-0/TestResults-0.xcresult',
  ]
  const selected = report.selectTestBundles(bundles, ['0', '1'])
  assert.deepEqual(selected.selected, [bundles[0]])
  assert.deepEqual(selected.missing, ['1'])
  const issues = report.testResultIssues(selected, new Map([
    [bundles[0], { result: 'Passed', failedTests: 0, totalTestCount: 1 }],
    [bundles[1], { result: 'Failed', failedTests: 1, totalTestCount: 1 }],
  ]))
  assert.deepEqual(issues, ['테스트 샤드 1 결과 누락'])

  const newerPrimary = '/tmp/pr-test-shard-1-0-attempt-2/TestResults-0.xcresult'
  const olderRetry = '/tmp/pr-test-shard-1-0-retry-1/TestResults-0.xcresult'
  assert.deepEqual(report.selectTestBundles([olderRetry, newerPrimary], ['0']).selected, [newerPrimary])
})

for (const comment of ['true', 'false']) {
  for (const scenario of [
    { name: '실패', result: 'Failed', shards: '0', failureCount: 1 },
    { name: '성공', result: 'Passed', shards: '0', failureCount: 0 },
    { name: '샤드 누락', result: 'Passed', shards: '0,1', failureCount: 1 },
  ]) {
  test(`PR 보고서는 댓글=${comment}, ${scenario.name} 결과를 판정한다`, async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'festicore-pr-report-'))
    const bundle = path.join(root, 'pr-test-shard-1-0', 'TestResults-0.xcresult')
    fs.mkdirSync(bundle, { recursive: true })
    const originalExec = childProcess.execFileSync
    const previousEnv = {
      RESULT_BUNDLE_DIR: process.env.RESULT_BUNDLE_DIR,
      COVERAGE_SHARD_IDS: process.env.COVERAGE_SHARD_IDS,
      REPORT_COMMENT: process.env.REPORT_COMMENT,
      TEST_OUTCOME: process.env.TEST_OUTCOME,
    }
    childProcess.execFileSync = (_command, args) => {
      if (args.includes('test-results')) {
        return JSON.stringify({ result: scenario.result, failedTests: scenario.result === 'Passed' ? 0 : 1,
          passedTests: 2, totalTestCount: 3,
          testFailures: [], startTime: 1, finishTime: 2 })
      }
      if (args.includes('build-results')) return JSON.stringify({ errors: [] })
      if (args.includes('xccov')) return '[]'
      throw new Error(`예상하지 못한 명령: ${args.join(' ')}`)
    }
    delete require.cache[require.resolve('./ios-test-report.js')]
    const runReport = require('./ios-test-report.js')
    process.env.RESULT_BUNDLE_DIR = root
    process.env.COVERAGE_SHARD_IDS = scenario.shards
    process.env.REPORT_COMMENT = comment
    process.env.TEST_OUTCOME = 'success'
    const failures = []
    const comments = []
    const core = {
      summary: { addRaw() { return this }, async write() {} },
      setFailed(message) { failures.push(message) },
    }
    const github = {
      paginate: async () => [],
      rest: { issues: { listComments() {}, async createComment(value) { comments.push(value) } } },
    }
    const context = { serverUrl: 'https://github.com', repo: { owner: 'FESTICORE', repo: 'FestiCore-iOS' },
      runId: 1, payload: { pull_request: { number: 1, head: { sha: 'abc' } } } }
    try {
      await runReport({ github, context, core })
      assert.equal(failures.length, scenario.failureCount)
      if (scenario.failureCount > 0) {
        assert.match(failures[0], scenario.name === '샤드 누락' ? /샤드 1/ : /TestResults-0/)
      }
      assert.equal(comments.length, comment === 'true' ? 1 : 0)
    } finally {
      childProcess.execFileSync = originalExec
      delete require.cache[require.resolve('./ios-test-report.js')]
      for (const [key, value] of Object.entries(previousEnv)) {
        if (value === undefined) delete process.env[key]
        else process.env[key] = value
      }
      fs.rmSync(root, { recursive: true, force: true })
    }
  })
  }
}
