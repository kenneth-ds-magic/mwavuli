import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  getApp, registerUser, auth, createOakTree, promoteToAdmin, login,
} from '../helpers';

test('report → staff resolve (hide) removes the tree from the feed', async () => {
  const app = await getApp();
  const owner = await registerUser(app);
  const { tree } = (await createOakTree(app, owner.accessToken)).json();

  const reporter = await registerUser(app);
  const rep = await app.inject({
    method: 'POST', url: '/v1/reports', headers: auth(reporter.accessToken),
    payload: { targetType: 'tree', targetId: tree.id, reason: 'wrong_location' },
  });
  assert.equal(rep.statusCode, 200);
  const reportId = rep.json().id;

  // Non-staff cannot touch admin endpoints.
  const denied = await app.inject({
    method: 'GET', url: '/v1/admin/reports', headers: auth(reporter.accessToken),
  });
  assert.equal(denied.statusCode, 403);

  // Promote a user to admin, then re-login to mint an admin-role token.
  const admin = await registerUser(app);
  await promoteToAdmin(admin.username);
  const adminToken = (await login(app, admin.username)).json().accessToken;

  const list = await app.inject({
    method: 'GET', url: '/v1/admin/reports?status=open', headers: auth(adminToken),
  });
  assert.equal(list.statusCode, 200);
  assert.ok(list.json().items.some((r: { id: string }) => r.id === reportId));

  const resolve = await app.inject({
    method: 'POST', url: `/v1/admin/reports/${reportId}/resolve`,
    headers: auth(adminToken), payload: { action: 'hide' },
  });
  assert.equal(resolve.statusCode, 200);
  assert.equal(resolve.json().status, 'actioned');

  const feed = await app.inject({ method: 'GET', url: '/v1/feed?limit=50' });
  const found = feed.json().items.find((t: { id: string }) => t.id === tree.id);
  assert.equal(found, undefined, 'hidden tree no longer in the public feed');
});
