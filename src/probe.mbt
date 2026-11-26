///|
#warnings("-78")
pub fn load_world(
  path : String,
  world : String,
) -> Result[@wit.ResolveInput, @wit.ParseError] {
  @wit.resolve_path(path, world~)
}
