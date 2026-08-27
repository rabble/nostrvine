// ABOUTME: Identifies profiles whose non-team checkmarks were retired.
// ABOUTME: Keeps regression coverage for the decisions in #7419 and #8235.

/// Non-team profiles that must not regain the Divine team checkmark.
const formerProfileCheckmarkPubkeys = <String>{
  'cd4ce30f980c960757b46179608a4946fc06cad47f6dc8960f638e41312c1643',
  'aa50001ef150418f30f62f827399d5c26a5ade52ab45ca4849f99b1726bb47b4',
  '5ab67f7d7fed4f781008c0ec0d26c8113f9fb46094a8346246c70c75e75db9fb',
};
