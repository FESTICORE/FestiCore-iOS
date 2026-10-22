const assert = require('node:assert/strict')
const test = require('node:test')
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
  assert.match(body, /StorageTests\/testRead/)
  assert.match(body, /샤드 2개 중 1개/)
  assert.match(body, /50\.0%/)
})
