// Checks ~/.gemini/policies with Gemini CLI's own PolicyEngine: the team-reviewer subagent only reads,
// the main session stays auto-approved. Run after editing a policy or reinstalling Gemini CLI:
//   node ~/.gemini/team-reviewer-probe.mjs      (exit 1 on any mismatch)
import { execSync } from 'node:child_process';
import { join } from 'node:path';
import { readdirSync, readFileSync } from 'node:fs';

const bundle = join(execSync('npm root -g').toString().trim(), '@google', 'gemini-cli', 'bundle');
const entry = readFileSync(join(bundle, 'gemini.js'), 'utf8');
const core = readdirSync(bundle).find((f) => /^chunk-.*\.js$/.test(f) && entry.includes(f)
  && readFileSync(join(bundle, f), 'utf8').includes('loadPoliciesFromToml'));
for (const k of ['debug', 'warn', 'error', 'log']) console[k] = () => {};
const m = await import(join(bundle, core));

const { rules, errors } = await m.loadPoliciesFromToml([process.env.HOME + '/.gemini/policies'], () => 4);
const R = 'team-reviewer', sh = (command) => ['run_shell_command', { command }];
const cases = [
  [R, 'allow', ...sh('git diff HEAD')],
  [R, 'allow', ...sh('git -C /x/y diff HEAD')],
  [R, 'allow', ...sh('git log --oneline | head -1')],
  [R, 'allow', 'run_shell_command', { command: 'git diff HEAD', description: 'diff -> stdout' }],
  [R, 'allow', ...sh('grep -n "foo(" a.ts')],
  [R, 'allow', 'read_file', { file_path: 'x' }],
  [R, 'allow', 'complete_task', { result: 'x' }],
  [R, 'deny', ...sh('touch x')],
  [R, 'deny', ...sh('git stash')],
  [R, 'deny', ...sh('git diff HEAD && touch x')],
  [R, 'deny', ...sh('ls\ntouch x')],
  [R, 'deny', ...sh('cat a | tee b')],
  [R, 'deny', ...sh('git diff HEAD > x')],
  [R, 'deny', ...sh('git diff $(touch x)')],
  [R, 'deny', ...sh('git log --output=x')],
  [R, 'deny', ...sh('git -C /x/y checkout -- a.ts')],
  [R, 'deny', ...sh('GIT_EXTERNAL_DIFF=sh git diff')],
  [R, 'deny', ...sh('cat /dev/null ) ; touch x ; ( :')],
  [R, 'deny', ...sh('npm test')],
  [R, 'deny', 'write_file', { file_path: 'x', content: 'y' }],
  [R, 'deny', 'replace', { file_path: 'x', old_string: 'a', new_string: 'b' }],
  [R, 'deny', 'save_memory', { fact: 'x' }],
  [undefined, 'allow', ...sh('touch x')],
  [undefined, 'allow', 'write_file', { file_path: 'x', content: 'y' }],
];
let bad = errors.length;
for (const e of errors) process.stdout.write(`POLICY ERROR ${e.fileName}: ${e.message} ${e.details ?? ''}\n`);
for (const mode of ['default', 'autoEdit', 'yolo']) {
  const pe = new m.PolicyEngine({ rules, approvalMode: mode, nonInteractive: false });
  for (const [who, want, name, args] of cases) {
    const got = (await pe.check({ name, args }, undefined, undefined, who)).decision;
    if (got !== want) {
      bad++;
      process.stdout.write(`FAIL ${mode} ${who ?? 'main'} ${name} ${JSON.stringify(args)}: ${got}, want ${want}\n`);
    }
  }
}
process.stdout.write(bad ? `${bad} problem(s)\n` : `ok: ${cases.length} cases x 3 modes\n`);
process.exit(bad ? 1 : 0);
