-- 010_seed.sql
-- Reference data: species + badges. (No user credentials are seeded here;
-- create the first admin with `npm run create-admin` in the api package.)

INSERT INTO species (common_name, scientific_name, family, native_range, description) VALUES
  ('English Oak', 'Quercus robur', 'Fagaceae', 'Europe, W. Asia',
   'Long-lived deciduous oak supporting more wildlife than almost any other native tree.'),
  ('Sugar Maple', 'Acer saccharum', 'Sapindaceae', 'Eastern North America',
   'Famed for autumn colour and maple syrup.'),
  ('Eastern White Pine', 'Pinus strobus', 'Pinaceae', 'Eastern North America',
   'Tall conifer with soft needles in bundles of five.'),
  ('Silver Birch', 'Betula pendula', 'Betulaceae', 'Europe, Asia',
   'Graceful birch with peeling white bark.'),
  ('Jacaranda', 'Jacaranda mimosifolia', 'Bignoniaceae', 'South America',
   'Ornamental tree with vivid purple spring blooms.'),
  ('Japanese Cherry', 'Prunus serrulata', 'Rosaceae', 'Japan, China, Korea',
   'Ornamental cherry celebrated for spring blossom.'),
  ('Weeping Willow', 'Salix babylonica', 'Salicaceae', 'China',
   'Fast-growing willow with trailing branches, often by water.')
ON CONFLICT (scientific_name) DO NOTHING;

INSERT INTO badges (code, name, description, icon, criteria) VALUES
  ('first_sprout', 'First Sprout', 'Logged your first tree.', 'eco',
   '{"metric":"tree_count","gte":1}'),
  ('explorer_25', 'Explorer 25', 'Logged 25 trees.', 'explore',
   '{"metric":"tree_count","gte":25}'),
  ('oak_keeper', 'Oak Keeper', 'Logged 10 oaks.', 'star',
   '{"metric":"genus_count","genus":"Quercus","gte":10}'),
  ('verifier', 'Verifier', 'Verified 10 community IDs.', 'verified',
   '{"metric":"verifications","gte":10}'),
  ('rare_finder', 'Rare Finder', 'Logged a rare or notable species.', 'lock',
   '{"metric":"rare_count","gte":1}'),
  ('century_club', '100 Club', 'Logged 100 trees.', 'lock',
   '{"metric":"tree_count","gte":100}')
ON CONFLICT (code) DO NOTHING;
