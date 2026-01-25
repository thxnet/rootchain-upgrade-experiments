{ name
, version
, lib
, rustPlatform
, llvmPackages_14
, protobuf
}:

rustPlatform.buildRustPackage {
  pname = name;
  inherit version;

  src = lib.cleanSource ./..;

  cargoLock = {
    lockFile = ../Cargo.lock;
    outputHashes = {
      "binary-merkle-tree-4.0.0-dev" = "sha256-YxCAFrLWTmGjTFzNkyjE+DNs2cl4IjAlB7qz0KPN1vE=";
      "sub-tokens-0.1.0" = "sha256-GvhgZhOIX39zF+TbQWtTCgahDec4lQjH+NqamLFLUxM=";
    };
  };

  nativeBuildInputs = [
    llvmPackages_14.clang
    llvmPackages_14.libclang

    protobuf
  ];

  doCheck = false;

  PROTOC = "${protobuf}/bin/protoc";
  PROTOC_INCLUDE = "${protobuf}/include";

  LIBCLANG_PATH = "${llvmPackages_14.libclang.lib}/lib";

  SUBSTRATE_CLI_GIT_COMMIT_HASH = "";
}
