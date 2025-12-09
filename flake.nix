{
  description = "Infrastructure as Code environment for Vault on Proxmox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            terraform
            ansible
            sshpass
            vault
          ];

          shellHook = ''
            echo "🚀 IaC Environment Loaded"
            echo "Terraform: $(terraform --version)"
            echo "Ansible: $(ansible --version)"
          '';
        };
      }
    );
}
