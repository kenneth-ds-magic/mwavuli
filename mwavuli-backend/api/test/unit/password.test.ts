import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword } from '../../src/auth/password';

test('password hash verifies and is salted', () => {
  const h1 = hashPassword('correct horse battery');
  const h2 = hashPassword('correct horse battery');
  assert.notEqual(h1, h2, 'unique salt per hash');
  assert.ok(verifyPassword('correct horse battery', h1));
  assert.ok(!verifyPassword('wrong', h1));
  assert.match(h1, /^scrypt\$[0-9a-f]+\$[0-9a-f]+$/);
});

test('verify rejects malformed stored value', () => {
  assert.ok(!verifyPassword('x', 'not-a-hash'));
  assert.ok(!verifyPassword('x', ''));
});
