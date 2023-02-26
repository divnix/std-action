with import <nixpkgs> {};
with lib;
  flake: let
    settings = flake.nixConfig or {};
    render = generators.toKeyValue {
      mkKeyValue = generators.mkKeyValueDefault {
        mkValueString = v:
          if isList v
          then concatStringsSep " " v
          else if (isPath v || v ? __toString)
          then toString v
          else generators.mkValueStringDefault {} v;
      } " = ";
    };
  in
    render settings
