let inputs = import "./nickel.lock.ncl" in
let organist = inputs.organist in

organist.OrganistExpression
& {
  Schema,
  config | Schema
    = {
      shells = organist.shells.Bash,

      shells.build = {
        packages = {
          elixir = organist.import_nix "nixpkgs#elixir_1_17",
        },
      },

      shells.dev = {
        packages.hello = organist.import_nix "nixpkgs#hello",
      },
    },
}
  | organist.modules.T
