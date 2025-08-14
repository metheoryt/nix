{
  description = "flake-based NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Optional: stable pin for cherry-picking rock-solid packages if unstable regresses
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }@inputs : {

    # Code formatter: `nix fmt` in the repo root
    formatter.x86_64-linux = (import nixpkgs { system = "x86_64-linux"; }).nixfmt-classic;
    # Lightweight dev shell for day-to-day tools; expand as you wish
    devShells.x86_64-linux.default = (import nixpkgs { system = "x86_64-linux"; }).mkShell {
      packages = with (import nixpkgs { system = "x86_64-linux"; }); [ git uv just ];
    };

    nixosConfigurations.g16 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/g16/configuration.nix
          home-manager.nixosModules.default
        ];
    };
  };
}
