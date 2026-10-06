# Rust is optional. Without this test, every shell without rustup prints an error.
if test -r "$HOME/.cargo/env.fish"
    . "$HOME/.cargo/env.fish"
end
