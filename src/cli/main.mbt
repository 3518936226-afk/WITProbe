///|
extern "js" fn args() -> FixedArray[String] =
  #|() => process.argv.slice(2)

///|
fn main {
  let argv = args()
  let output = if argv.length() == 6 {
    @analyzer.compare_paths_mapped(
      argv[0],
      argv[1],
      argv[2],
      argv[3],
      argv[4],
      argv[5],
    )
  } else {
    @analyzer.error_json(
      "ARGUMENT_ERROR", "Internal analyzer expects old, new, old-world, new-world, direction, mapping JSON.",
      "",
    )
  }
  // The public Node launcher maps the machine-readable result to process exit codes.
  println(output.stringify())
}
