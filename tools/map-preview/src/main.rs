use mlua::{Lua, Result, Function};
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let lua = Lua::new();
    let g = lua.globals();
    g.set("readfile", lua.create_function(|_, p: String| Ok(std::fs::read_to_string(&p).map_err(|e| mlua::Error::RuntimeError(format!("{}: {}", p, e)))?))?)?;
    g.set("writefile", lua.create_function(|_, (p, s): (String, mlua::String)| { std::fs::write(&p, s.as_bytes()).map_err(|e| mlua::Error::RuntimeError(e.to_string()))?; Ok(()) })?)?;
    g.set("compile", lua.create_function(|lua, (src, name): (String, String)| { let f: Function = lua.load(&src).set_name(name).into_function()?; Ok(f) })?)?;
    let argv = lua.create_table()?;
    for (i, a) in args.iter().enumerate().skip(1) { argv.set(i, a.clone())?; }
    g.set("ARGS", argv)?;
    let boot = std::fs::read_to_string(&args[1]).expect("bootstrap");
    lua.load(&boot).set_name("bootstrap").exec()?;
    Ok(())
}
