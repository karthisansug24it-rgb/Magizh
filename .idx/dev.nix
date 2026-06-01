{ pkgs, ... }: {
  # Use the unstable channel to get the latest versions of Flutter and Dart
  channel = "unstable"; 

  packages = [
    pkgs.flutter
  ];

  idx = {
    workspace = {
      onCreate = {
        build-flutter = "flutter pub get";
      };
    };
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "flutter";
        };
        android = {
          manager = "flutter";
        };
      };
    };
  };
}
