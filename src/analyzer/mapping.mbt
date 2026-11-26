///|
fn package_ids(r : @wit.Resolve) -> Array[String] {
  r.packages.map(fn(p) {
    p.name.ns +
    ":" +
    p.name.name +
    (match p.name.version {
      Some(v) => "@" + v
      None => ""
    })
  })
}

///|
fn parse_mapping(
  text : String,
  old : @wit.ResolveInput,
  new : @wit.ResolveInput,
) -> Result[Array[@contract.DependencyMapping], String] {
  let json = @json.parse(text, reject_duplicate_keys=true) catch {
    _ =>
      return Err(
        "Dependency mapping must be valid JSON without duplicate keys.",
      )
  }
  let entries = match json {
    Object(fields) => {
      if fields.length() != 2 ||
        fields.get("schema_version") != Some(@json.ToJson::to_json(1)) {
        return Err("Mapping requires schema_version=1 and packages only.")
      }
      match fields.get("packages") {
        Some(Array(entries)) => entries
        _ => return Err("packages must be an array.")
      }
    }
    _ => return Err("Mapping must be an object.")
  }
  if entries.length() > 128 {
    return Err("Mapping limit is 128 package pairs.")
  }
  let old_ids = package_ids(old.resolve)
  let new_ids = package_ids(new.resolve)
  let old_root = old.resolve.worlds[old.world_id].pkg
  let new_root = new.resolve.worlds[new.world_id].pkg
  let result : Array[@contract.DependencyMapping] = []
  for entry in entries {
    let (old_package, new_package) = match entry {
      Object(fields) => {
        if fields.length() != 2 {
          return Err("Each pair requires old_package and new_package only.")
        }
        match (fields.get("old_package"), fields.get("new_package")) {
          (Some(String(a)), Some(String(b))) => (a, b)
          _ => return Err("Both package identities must be strings.")
        }
      }
      _ => return Err("Each package pair must be an object.")
    }
    let a = old_package.split("@").to_array()
    let b = new_package.split("@").to_array()
    if a.length() != 2 ||
      b.length() != 2 ||
      a[0] != b[0] ||
      old_package == new_package {
      return Err(
        "Only explicit, distinct versions of the same namespace/package may be mapped.",
      )
    }
    if !old_ids.contains(old_package) || !new_ids.contains(new_package) {
      return Err(
        "Mapped package version is absent from its respective input: " +
        old_package +
        " -> " +
        new_package,
      )
    }
    if (old_root is Some(i) && old_ids[i] == old_package) ||
      (new_root is Some(i) && new_ids[i] == new_package) {
      return Err(
        "Root package versions are already handled separately; dependency mappings cannot include roots.",
      )
    }
    if result.any(fn(p) {
        p.old_package == old_package || p.new_package == new_package
      }) {
      return Err(
        "Dependency mappings must be one-to-one, without duplicate endpoints.",
      )
    }
    if new_ids.contains(old_package) {
      return Err(
        "Mapping would merge distinct coexisting dependency versions in the new input.",
      )
    }
    result.push({ old_package, new_package, })
  }
  result.sort_by_key(fn(p) { p.old_package })
  Ok(result)
}

///|
fn compare_inputs(
  old : @wit.ResolveInput,
  new : @wit.ResolveInput,
  direction : String,
  text : String,
) -> Json {
  match parse_mapping(text, old, new) {
    Err(message) => error_json("DEPENDENCY_MAPPING_ERROR", message, direction)
    Ok(pairs) => {
      let mapping : Map[String, String] = Map([])
      for pair in pairs {
        mapping.set(pair.new_package, pair.old_package)
      }
      let old_contract = from_resolve(old)
      let new_contract = from_resolve(new)
      let normalized = contract_ir(new.resolve, new.world_id, mapping)
      let report = @contract.compare(old_contract, normalized, direction)
      let result = {
        ..report,
        new_contract,
        dependency_mappings: pairs,
        comparison_new_contract: if pairs.is_empty() {
          None
        } else {
          Some(normalized)
        },
      }
      result.json()
    }
  }
}

///|
pub fn compare_paths_mapped(
  old : String,
  new : String,
  old_world : String,
  new_world : String,
  direction : String,
  mapping : String,
) -> Json {
  match @wit.resolve_path(old, world=old_world) {
    Err(e) => error_json("OLD_INPUT_ERROR", e.to_string(), direction)
    Ok(a) =>
      match @wit.resolve_path(new, world=new_world) {
        Err(e) => error_json("NEW_INPUT_ERROR", e.to_string(), direction)
        Ok(b) => compare_inputs(a, b, direction, mapping)
      }
  }
}
