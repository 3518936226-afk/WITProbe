///|
fn package_identity(
  r : @wit.Resolve,
  pkg : Int32?,
  root : Int32?,
  with_version : Bool,
) -> String {
  match pkg {
    None => "<anonymous>"
    Some(i) => {
      let p = r.packages[i].name
      let base = p.ns + ":" + p.name
      if with_version && pkg != root {
        match p.version {
          Some(v) => base + "@" + v
          None => base
        }
      } else {
        base
      }
    }
  }
}

///|
fn iface_identity(r : @wit.Resolve, id : Int32, root : Int32?) -> String {
  let iface = r.interfaces[id]
  let base = package_identity(r, iface.pkg, root, false) +
    "/" +
    iface.name.unwrap_or("<inline>")
  if iface.pkg != root {
    match iface.pkg {
      Some(p) =>
        match r.packages[p].name.version {
          Some(v) => base + "@" + v
          None => base
        }
      None => base
    }
  } else {
    base
  }
}

///|
fn nominal(r : @wit.Resolve, id : Int32, root : Int32?) -> String {
  let t = r.types[id]
  let owner = match t.owner {
    Interface(i) => iface_identity(r, i, root)
    World(i) =>
      package_identity(r, r.worlds[i].pkg, root, true) +
      "/world/" +
      r.worlds[i].name
    None => "<anonymous-owner>"
  }
  owner + "/type/" + t.name.unwrap_or("<anonymous-type>")
}

///|
fn unsupported(shape : String, code : String) -> @contract.TypeDesc {
  { shape, unsupported: Some(code), }
}

///|
fn describe(
  r : @wit.Resolve,
  ty : @wit.RType,
  root : Int32?,
  depth : Int32,
) -> @contract.TypeDesc {
  if depth > 256 {
    return unsupported("<depth-limit>", "TYPE_DEPTH_LIMIT")
  }
  match ty {
    Id(i) => describe_id(r, i, root, depth)
    ErrorContext => unsupported("error-context", "UNSUPPORTED_ASYNC")
    _ => {
      let shape = match ty.to_json() {
        String(s) => s
        other => other.stringify()
      }
      { shape, unsupported: None, }
    }
  }
}

///|
fn function_ir(
  r : @wit.Resolve,
  f : @wit.RFunction,
  root : Int32?,
) -> @contract.Function {
  let kind = match f.kind {
    Freestanding => "freestanding"
    AsyncFreestanding | AsyncMethod(_) | AsyncStatic(_) => "async"
    Getter | MethodGetter(_) | StaticGetter(_) => "getter"
    Setter | MethodSetter(_) | StaticSetter(_) => "setter"
    Constructor(_) => "constructor"
    Method(_) => "method"
    Static(_) => "static"
  }
  {
    name: f.name,
    kind,
    params: f.params.map(fn(p) {
      @contract.Parameter::{ name: p.0, ty: describe(r, p.1, root, 0), }
    }),
    result: f.result.map(fn(t) { describe(r, t, root, 0) }),
    external_id: f.external_id,
    unsupported: if f.external_id is Some(_) {
      Some("UNSUPPORTED_EXTERNAL_ID")
    } else if kind == "async" {
      Some("UNSUPPORTED_ASYNC")
    } else if kind != "freestanding" {
      Some("UNSUPPORTED_RESOURCE_OR_ACCESSOR")
    } else {
      None
    },
  }
}

///|
fn edges(
  r : @wit.Resolve,
  items : Map[String, @wit.RWorldItem],
  root : Int32?,
) -> Array[@contract.Edge] {
  let out : Array[@contract.Edge] = []
  for key, item in items {
    match item {
      Interface(ref_) => {
        let iface = r.interfaces[ref_.id]
        let identity = iface_identity(r, ref_.id, root)
        let edge_key = if key == "interface-" + ref_.id.to_string() {
          "interface:" + identity
        } else {
          "label:" + key + "=" + identity
        }
        let funcs = iface.functions
          .values()
          .to_array()
          .map(fn(f) { function_ir(r, f, root) })
        funcs.sort_by_key(fn(f) { f.name })
        let types : Array[@contract.PublicType] = []
        // Every interface type is public, including types unused by functions.
        for name, id in iface.types {
          types.push({ name, ty: describe_id(r, id, root, 0), })
        }
        types.sort_by_key(fn(t) { t.name })
        out.push({
          key: edge_key,
          kind: "interface",
          functions: funcs,
          types,
          external_id: ref_.external_id,
          unsupported: if ref_.external_id is Some(_) {
            Some("UNSUPPORTED_EXTERNAL_ID")
          } else {
            None
          },
        })
      }
      Function(f) =>
        out.push({
          key: "function:" + key,
          kind: "function",
          functions: [function_ir(r, f, root)],
          types: [],
          external_id: f.external_id,
          unsupported: None,
        })
      Type(id) =>
        out.push({
          key: "type:" + key,
          kind: "type",
          functions: [],
          types: [{ name: key, ty: describe_id(r, id, root, 0), }],
          external_id: None,
          unsupported: None,
        })
    }
  }
  out.sort_by_key(fn(e) { e.key })
  out
}

///|
fn contract_ir(r : @wit.Resolve, world_id : Int32) -> @contract.Contract {
  let w = r.worlds[world_id]
  {
    schema_version: 1,
    root_identity: package_identity(r, w.pkg, w.pkg, false),
    source_version: match w.pkg {
      Some(i) => r.packages[i].name.version
      None => None
    },
    world: w.name,
    imports: edges(r, w.imports, w.pkg),
    exports: edges(r, w.exports, w.pkg),
  }
}

///|
#warnings("-78")
pub fn from_source(
  source : String,
  world : String,
) -> Result[@contract.Contract, String] {
  match @wit.resolve(source) {
    Err(e) => Err(e.to_string())
    Ok(r) => {
      let mut selected : Int32? = None
      for i = 0; i < r.worlds.length(); i = i + 1 {
        if r.worlds[i].name == world {
          if selected is Some(_) {
            return Err("Ambiguous world name: " + world)
          }
          selected = Some(i)
        }
      }
      match selected {
        Some(i) => Ok(contract_ir(r, i))
        None => Err("World not found: " + world)
      }
    }
  }
}

///|
pub fn error_json(code : String, message : String, direction : String) -> Json {
  Json::object({
    "schema_version": @json.ToJson::to_json(1),
    "rule_set_version": @json.ToJson::to_json("scalar-sync-v1"),
    "status": @json.ToJson::to_json("ERROR"),
    "exit_code": @json.ToJson::to_json(2),
    "direction": @json.ToJson::to_json(direction),
    "error": Json::object({
      "code": @json.ToJson::to_json(code),
      "message": @json.ToJson::to_json(message),
    }),
  })
}

///|
pub fn compare_paths(
  old : String,
  new : String,
  old_world : String,
  new_world : String,
  direction : String,
) -> Json {
  match @wit.resolve_path(old, world=old_world) {
    Err(e) => error_json("OLD_INPUT_ERROR", e.to_string(), direction)
    Ok(a) =>
      match @wit.resolve_path(new, world=new_world) {
        Err(e) => error_json("NEW_INPUT_ERROR", e.to_string(), direction)
        Ok(b) =>
          @contract.compare(from_resolve(a), from_resolve(b), direction).json()
      }
  }
}

///|
fn describe_id(
  r : @wit.Resolve,
  i : Int32,
  root : Int32?,
  depth : Int32,
) -> @contract.TypeDesc {
  if depth > 256 {
    return unsupported("<depth-limit>", "TYPE_DEPTH_LIMIT")
  }

  let t = r.types[i]
  let description = match t.kind {
    Alias(a) => describe(r, a, root, depth + 1)
    Resource =>
      unsupported("resource:" + nominal(r, i, root), "UNSUPPORTED_RESOURCE")
    Handle(kind) => {
      let shape = match kind {
        Own(id) => "own:" + nominal(r, id, root)
        Borrow(id) => "borrow:" + nominal(r, id, root)
      }
      unsupported(shape, "UNSUPPORTED_RESOURCE")
    }
    Record(fields) => {
      let shapes = fields.map(fn(f) {
        (f.name, describe(r, f.field_type, root, depth + 1).shape)
      })
      unsupported(
        "record:" + @json.ToJson::to_json(shapes).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    }
    Variant(cases) => {
      let shapes = cases.map(fn(c) {
        (
          c.name,
          c.case_type.map(fn(t) { describe(r, t, root, depth + 1).shape }),
        )
      })
      unsupported(
        "variant:" + @json.ToJson::to_json(shapes).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    }
    Flags(names) =>
      unsupported(
        "flags:" + @json.ToJson::to_json(names).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    Enum(names) =>
      unsupported(
        "enum:" + @json.ToJson::to_json(names).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    List(a) =>
      unsupported(
        "list:" + describe(r, a, root, depth + 1).shape,
        "UNSUPPORTED_COMPOSITE",
      )
    FixedLengthList(a, n) =>
      unsupported(
        "fixed-list:" +
        n.to_string() +
        ":" +
        describe(r, a, root, depth + 1).shape,
        "UNSUPPORTED_COMPOSITE",
      )
    Map(a, b) =>
      unsupported(
        "map:" +
        @json.ToJson::to_json(
          (
            describe(r, a, root, depth + 1).shape,
            describe(r, b, root, depth + 1).shape,
          ),
        ).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    Option(a) =>
      unsupported(
        "option:" + describe(r, a, root, depth + 1).shape,
        "UNSUPPORTED_COMPOSITE",
      )
    Tuple(items) =>
      unsupported(
        "tuple:" +
        @json.ToJson::to_json(
          items.map(fn(t) { describe(r, t, root, depth + 1).shape }),
        ).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    Result(ok~, err~) =>
      unsupported(
        "result:" +
        @json.ToJson::to_json(
          (
            ok.map(fn(t) { describe(r, t, root, depth + 1).shape }),
            err.map(fn(t) { describe(r, t, root, depth + 1).shape }),
          ),
        ).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    Future(a) =>
      unsupported(
        "future:" +
        @json.ToJson::to_json(
          a.map(fn(t) { describe(r, t, root, depth + 1).shape }),
        ).stringify(),
        "UNSUPPORTED_ASYNC",
      )
    Stream(a) =>
      unsupported(
        "stream:" +
        @json.ToJson::to_json(
          a.map(fn(t) { describe(r, t, root, depth + 1).shape }),
        ).stringify(),
        "UNSUPPORTED_ASYNC",
      )
  }
  match t.external_id {
    Some(id) =>
      unsupported(
        "external:" + id + ":" + description.shape,
        "UNSUPPORTED_EXTERNAL_ID",
      )
    None => description
  }
}

///|
pub fn from_resolve(input : @wit.ResolveInput) -> @contract.Contract {
  contract_ir(input.resolve, input.world_id)
}
