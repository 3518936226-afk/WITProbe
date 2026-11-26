///|
test "parse a WIT source through upstream parser" {
  let ast = @wit.parse("package demo:basic; world app { export run: func(); }").unwrap()
  assert_eq(ast.worlds.length(), 1)
}

///|
test "original plan example rejects duplicate top-level name" {
  assert_true(
    @witprobe.load_world("fixtures/invalid-duplicate", "calculator") is Err(_),
  )
}

///|
test "resolve V1 with selected world and export" {
  let input = @witprobe.load_world("fixtures/v1", "calculator-world").unwrap()
  let world = input.resolve.worlds[input.world_id]
  assert_eq(world.name, "calculator-world")
  assert_eq(world.exports.length(), 1)
  assert_eq(input.resolve.interfaces.length(), 1)
}

///|
test "resolve V2 preserves changed string signature" {
  let old = @witprobe.load_world("fixtures/v1", "calculator-world").unwrap()
  let new = @witprobe.load_world("fixtures/v2", "calculator-world").unwrap()
  let before = old.resolve.interfaces[0].functions.get("add").unwrap()
  let after = new.resolve.interfaces[0].functions.get("add").unwrap()
  assert_true(before.params != after.params)
  assert_true(before.result != after.result)
}

///|
test "resolve dependency directory and transitive imports" {
  let input = @witprobe.load_world("fixtures/dependency", "calculator-world").unwrap()
  assert_eq(input.resolve.packages.length(), 2)
  assert_eq(input.resolve.interfaces.length(), 2)
  let world = input.resolve.worlds[input.world_id]
  assert_eq(world.exports.length(), 1)
  assert_eq(world.imports.length(), 1)
  assert_true(input.resolve.types.length() > 0)
}

///|
test "unknown world is an error" {
  assert_true(@witprobe.load_world("fixtures/v1", "missing") is Err(_))
}

///|
test "missing input is an error" {
  assert_true(
    @witprobe.load_world("fixtures/not-present", "calculator-world") is Err(_),
  )
}

///|
test "invalid syntax is an error" {
  assert_true(@wit.parse("package demo:bad; world app { export }") is Err(_))
}

///|
test "unresolved type dependency is an error" {
  assert_true(
    @wit.resolve(
      "package demo:bad; interface api { use other.{missing}; } world app { export api; }",
    )
    is Err(_),
  )
}

///|
test "duplicate function is an error" {
  assert_true(
    @wit.resolve(
      "package demo:bad; interface api { f: func(); f: func(); } world app { export api; }",
    )
    is Err(_),
  )
}

///|
test "complex async syntax survives resolver" {
  let r = @wit.resolve(
    "package demo:async-api; interface api { get: async func() -> future<u32>; } world app { export api; }",
  ).unwrap()
  assert_eq(r.interfaces[0].functions.length(), 1)
  // Acceptance by the parser does not establish compatibility or runtime support.
}

///|
test "resolved output supports JSON serialization" {
  let input = @witprobe.load_world("fixtures/dependency", "calculator-world").unwrap()
  assert_true(input.to_json().stringify().length() > 20)
}

///|
test "repeat resolution is deterministic within pinned toolchain" {
  let first = @witprobe.load_world("fixtures/dependency", "calculator-world").unwrap()
  let second = @witprobe.load_world("fixtures/dependency", "calculator-world").unwrap()
  assert_eq(first, second)
}
