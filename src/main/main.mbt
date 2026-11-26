///|
fn main {
  // This experiment intentionally reports the upstream resolved model, not a WITProbe IR.
  let outputs : Map[String, Json] = Map([])
  for name in ["v1", "v2", "dependency"] {
    match @probe.load_world("fixtures/" + name, "calculator-world") {
      Ok(input) => outputs.set(name, input.to_json())
      Err(error) => abort(error.to_string())
    }
  }
  println(Json::object(outputs).stringify())
}
