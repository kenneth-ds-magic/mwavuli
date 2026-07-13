import { test } from 'node:test';
import assert from 'node:assert/strict';
import { treesToCsv } from '../../src/services/export';

test('treesToCsv escapes and joins arrays', () => {
  const csv = treesToCsv([
    { id: '1', common_name: 'Oak, Grand', scientific_name: 'Quercus robur',
      health: 'healthy', features: ['Heritage', 'Fruiting'], is_fuzzy: true },
  ]);
  const [header, row] = csv.split('\n');
  assert.ok(header.startsWith('id,common_name'));
  assert.ok(row.includes('"Oak, Grand"'), 'commas quoted');
  assert.ok(row.includes('Heritage|Fruiting'), 'array pipe-joined');
});
